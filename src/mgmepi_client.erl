-module(mgmepi_client).

-include("internal.hrl").

-import(mgmepi_util, [parse/2]).

%% -- private --
-export([start_link/1]).
-export([call/4, call/5, call/6]).
-export([recv/2, send/4]).

%% -- behaviour: gen_server --
-behaviour(gen_server).
-export([init/1, terminate/2, code_change/3,
         handle_call/3, handle_cast/2, handle_info/2]).

%% -- internal --
-type(socket()  :: undefined|gen_tcp:socket()).
-type(from()    :: undefined|{pid(), reference()}).
-type(pattern() :: undefined|binary:cp()).

-record(state, {
          socket  :: socket(),
          event   :: boolean(),
          from    :: from(),
          pattern :: pattern(),
          rest    :: binary()
         }).

%% == private ==

-spec start_link([term()]) -> {ok, pid()}|{error, _}.
start_link(Args) ->
    case gen_server:start_link(?MODULE, [], []) of
        {ok, Pid} ->
            case gen_server:call(Pid, {setup, Args}, infinity) of
                ok ->
                    {ok, Pid};
                {error, Reason} ->
                    ok = gen_server:stop(Pid),
                    {error, Reason}
            end
    end.


-spec call(pid(), binary(), [param()], timeout()) ->
                  {ok, [matched()], [parsed()]}|{error, _}.
call(Pid, Cmd, Params, Timeout) ->
    call(Pid, Cmd, [], Params, undefined, Timeout).

-spec call(pid(), binary(), [arg()], [param()], timeout()) ->
                  {ok, [matched()], [parsed()]}|{error, _}.
call(Pid, Cmd, Args, Params, Timeout) ->
    call(Pid, Cmd, Args, Params, undefined, Timeout).

-spec call(pid(), binary(), [arg()], [param()], pattern(), timeout()) ->
                  {ok, [matched()], [parsed()]}|{error, _}.
call(Pid, Cmd, Args, Params, Pattern, Timeout) ->
    Ref = send(Pid, Cmd, Args, Pattern),
    receive
        {Ref, Binary} ->
            true = demonitor(Ref, [flush]),
            parse(Binary, Params);
        {'DOWN', Ref, _, _, Reason} ->
            {error, Reason}
    after
        Timeout ->
            true = demonitor(Ref, [flush]),
            {error, timeout}
    end.


-spec recv(pid(), pos_integer()) -> {ok, binary()}|{error, _}.
recv(Pid, Size) ->
    gen_server:call(Pid, {recv, Size}).

-spec send(pid(), binary(), [arg()], pattern()) -> reference().
send(Pid, Cmd, Args, Pattern) ->
    Ref = monitor(process, Pid),
    ok = gen_server:cast(Pid, {send, to_packet(Cmd, Args), Pattern, {self(), Ref}}),
    Ref.

%% == behaviour: gen_server ==

init(Args) ->
    setup(Args).

terminate(_Reason, State) ->
    cleanup(State).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

handle_call({recv, Size}, _From, #state{socket=S, rest=R}=X) ->
    case gen_tcp:recv(S, Size - size(R)) of
        {ok, Packet} ->
            {reply, {ok, <<R/binary, Packet/binary>>}, X#state{rest = <<>>}};
        {error, Reason} ->
            {stop, {error, Reason}, X}
    end;
handle_call({setup, Args}, _From, #state{socket=undefined}=X) ->
    setup(Args, X).

handle_cast({send, Packet, undefined, From}, #state{socket=S, event=false}=X) ->
    case ok =:= inet:setopts(S, [{active, once}])
        andalso gen_tcp:send(S, Packet) of
        ok ->
            {noreply, X#state{from = From}};
        {error, Reason} ->
            {stop, {error, Reason}, X}
    end;
handle_cast({send, Packet, Pattern, From}, #state{socket=S}=X) ->
    case ok =:= inet:setopts(S, [{active, true}])
        andalso gen_tcp:send(S, Packet) of
        ok ->
            {noreply, X#state{event = true, pattern = Pattern, from = From}};
        {error, Reason} ->
            {stop, {error, Reason}, X}
    end.

handle_info({tcp, S, Data}, #state{socket=S, from=F, pattern=P, rest=R}=X) ->
    {Replies, Rest} = split(<<R/binary, Data/binary>>, P),
    _ = [ gen_server:reply(F, E) || E <- Replies ],
    {noreply, X#state{rest = Rest}};
handle_info({tcp_closed, S}, #state{socket=S}=X) ->
    {stop, tcp_closed, X#state{socket = undefined}};
handle_info({tcp_error, S}, #state{socket=S}=X) ->
    {stop, tcp_error, X#state{socket = undefined}};
handle_info({'EXIT', S, normal}, #state{socket=S}=X) ->
    {stop, port_closed, X#state{socket = undefined}};
handle_info({'EXIT', _Pid, Reason}, State) ->
    {stop, Reason, State}.

%% == internal ==

cleanup(#state{socket=S}=X)
  when S =/= undefined ->
    ok = gen_tcp:close(S),
    cleanup(X#state{socket = undefined});
cleanup(#state{}) ->
    baseline:flush().

setup([]) ->
    false = process_flag(trap_exit, true),
    {ok, #state{event = false,
                pattern = binary:compile_pattern(<<?LS, ?LS>>), rest = <<>>}}.

setup(Args, #state{socket=undefined}=X) ->
    case apply(gen_tcp, connect, Args) of
        {ok, Socket} ->
            {reply, ok, X#state{socket = Socket}};
        {error, Reason} ->
            {reply, {error, Reason}, X}
    end.


split(Binary, Pattern) ->
    split(Binary, 0, [], binary:matches(Binary, Pattern)).

split(Binary, Start, List, []) ->
    {lists:reverse(List), binary_part(Binary, Start, size(Binary) - Start)};
split(Binary, Start, List, [{S, L}|T]) ->
    case binary_part(Binary, Start, S - Start) of
        <<>> ->
            split(Binary, S + L, List, T);
        Part ->
            split(Binary, S + L, [Part|List], T)
    end.

to_packet(Cmd, []) ->
    <<Cmd/binary, ?LS, ?LS>>;
to_packet(Cmd, Args) ->
    B = << <<K/binary, ?FS, V/binary, ?LS>> || {K, V} <- Args >>,
    <<Cmd/binary, ?LS, B/binary, ?LS>>.
