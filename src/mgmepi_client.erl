-module(mgmepi_client).

-include("internal.hrl").

-import(mgmepi_util, [parse/2]).

%% -- private --
-export([start_link/2]).
-export([call/4, call/5, call/6]).
-export([recv/2]).

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

-spec start_link([term()], [term()]) -> {ok, pid()}|{error, _}.
start_link(Args, Options) ->
    gen_server:start_link(?MODULE, Args, Options).


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
    try gen_server:call(Pid, {send, to_packet(Cmd, Args), Pattern}, Timeout) of
        Binary ->
            parse(Binary, Params)
    catch
        exit:Reason ->
            {error, Reason}
    end.


-spec recv(pid(), pos_integer()) -> {ok, binary()}|{error, _}.
recv(Pid, Size) ->
    try gen_server:call(Pid, {recv, Size}) of
        Binary ->
            {ok, Binary}
    catch
        exit:Reason ->
            {error, Reason}
    end.

%% == behaviour: gen_server ==

init(Args) ->
    setup(Args).

terminate(_Reason, State) ->
    cleanup(State).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

handle_call({send, Packet, undefined}, From, #state{socket=S, event=false}=X) ->
    case ok =:= inet:setopts(S, [{active, once}])
        andalso gen_tcp:send(S, Packet) of
        ok ->
            {noreply, X#state{from = From}};
        {error, Reason} ->
            {stop, Reason, X}
    end;
handle_call({send, Packet, Pattern}, From, #state{socket=S}=X)
  when Pattern =/= undefined ->
    case ok =:= inet:setopts(S, [{active, true}]) % "listen event", "end session"
        andalso gen_tcp:send(S, Packet) of
        ok ->
            {noreply, X#state{event = true, pattern = Pattern, from = From}};
        {error, Reason} ->
            {stop, Reason, X}
    end;
handle_call({recv, Size}, _From, #state{socket=S, rest=R}=X) ->
    case gen_tcp:recv(S, Size - size(R)) of
        {ok, Packet} ->
            {reply, <<R/binary, Packet/binary>>, X#state{rest = <<>>}};
        {error, Reason} ->
            {stop, Reason, X}
    end.

handle_cast(_Request, State) ->
    {stop, enosys, State}.

handle_info({tcp, S, Data}, #state{socket=S, from=F, pattern=P, rest=R}=X) ->
    {Replies, Rest} = baseline_binary:split(<<R/binary, Data/binary>>, P),
    _ = [ gen_server:reply(F, E) || E <- Replies ],
    {noreply, X#state{rest = Rest}};
handle_info({Reason, S}, #state{socket=S}=X) ->
    {stop, Reason, X#state{socket = undefined}};
handle_info({'EXIT', S, Reason}, #state{socket=S}=X) ->
    {stop, Reason, X#state{socket = undefined}};
handle_info({'EXIT', _Pid, Reason}, State) ->
    {stop, Reason, State}.

%% == internal ==

cleanup(#state{socket=S}=X)
  when S =/= undefined ->
    ok = gen_tcp:close(S),
    cleanup(X#state{socket = undefined});
cleanup(_) ->
    baseline:flush().

setup(Args) ->
    case apply(gen_tcp, connect, Args) of
        {ok, Socket} ->
            false = process_flag(trap_exit, true),
            {ok, #state{socket = Socket, event = false,
                        pattern = binary:compile_pattern(<<?LS, ?LS>>), rest = <<>>}};
        {error, Reason} ->
            {stop, Reason}
    end.


to_packet(Cmd, []) ->
    <<Cmd/binary, ?LS, ?LS>>;
to_packet(Cmd, Args) ->
    B = << <<K/binary, ?FS, V/binary, ?LS>> || {K, V} <- Args >>,
    <<Cmd/binary, ?LS, B/binary, ?LS>>.
