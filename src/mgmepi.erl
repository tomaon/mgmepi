-module(mgmepi).

-include("internal.hrl").

-import(mgmepi_client, [call/4, call/5, call/6]).
-import(mgmepi_util, [boolean_to_binary/1, get_result/1, get_result/2, get_value/2]).

%% -- public --
-export([start/0, stop/0]).
-export([checkout/0, checkin/1]).
-export([set_timeout/2]).
-export([check_connection/1, check_connection/2]).
-export([get_version/1, get_version/2]).
-export([alloc_node_id/2, alloc_node_id/3, alloc_node_id/4]).
-export([free_node_id/1, free_node_id/2]).

%% -- private --
-export([worker/1]).

%% -- internal --
-define(IS_NAME(T), (is_binary(T) andalso size(T) > 0)).

-type(name() :: binary()).
-type(reason() :: baseline:reason()).

%% == public ==

-spec start() -> ok|{error, reason()}.
start() ->
    baseline:start(?MODULE).

-spec stop() -> ok|{error, reason()}.
stop() ->
    baseline:stop(?MODULE).


-spec checkout() -> {ok, mgmepi()}|{error, not_found}.
checkout() ->
    checkout(baseline_app:children(mgmepi_sup)).

-spec checkin(mgmepi()) -> ok.
checkin(#mgmepi{}=M) ->
    cleanup(M).


-spec set_timeout(mgmepi(), timeout()) -> mgmepi().
set_timeout(#mgmepi{}=M, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    M#mgmepi{timeout = Timeout}.


-spec check_connection(mgmepi()) -> ok|{error, _}.
check_connection(#mgmepi{timeout=T}=M) ->
    check_connection(M, T).

-spec check_connection(mgmepi(), timeout()) -> ok|{error, _}.
check_connection(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_check_connection/1
    %%
    case call(W,
              <<"check connection">>,
              [
               {<<"check connection reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.


-spec get_version(mgmepi()) -> {ok, integer()}|{error, _}.
get_version(#mgmepi{timeout=T}=M) ->
    get_version(M, T).

-spec get_version(mgmepi(), timeout()) -> {ok, integer()}|{error, _}.
get_version(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_version/6
    %%
    case call(W,
              <<"get version">>,
              [
               {<<"version">>, null, mandatory},
               {<<"id">>, integer, mandatory},
               {<<"major">>, integer, mandatory},
               {<<"minor">>, integer, mandatory},
               {<<"build">>, integer, optional},
               {<<"string">>, string, mandatory},
               {<<"mysql_major">>, integer, optional},
               {<<"mysql_minor">>, integer, optional},
               {<<"mysql_build">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            {ok, get_value(<<"id">>, List)};
        {error, Reason} ->
            {error, Reason}
    end.


-spec alloc_node_id(mgmepi(), name())
                   -> {ok, node_id()}|{error, _}.
alloc_node_id(Mgmepi, Name) ->
    alloc_node_id(Mgmepi, Name, 0).

-spec alloc_node_id(mgmepi(), name(), 0|node_id())
                   -> {ok, node_id()}|{error, _}.
alloc_node_id(#mgmepi{timeout=T}=M, Name, NodeId) ->
    alloc_node_id(M, Name, NodeId, T).

-spec alloc_node_id(mgmepi(), name(), 0|node_id(), timeout())
                   -> {ok, node_id()}|{error, _}.
alloc_node_id(#mgmepi{worker=W}, Name, NodeId, Timeout)
  when (NodeId =:= 0 orelse ?IS_NODE_ID(NodeId)),
       ?IS_NAME(Name), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_alloc_nodeid/4
    %%
    case call(W,
              <<"get nodeid">>,
              [
               {<<"version">>, integer_to_binary(?NDB_VERSION_ID)},
               {<<"nodetype">>, integer_to_binary(?NDB_MGM_NODE_TYPE_API)},
               {<<"nodeid">>, integer_to_binary(NodeId)},
               {<<"user">>, <<"mysqld">>},
               {<<"password">>, <<"mysqld">>},
               {<<"public key">>, <<"a public key">>},
               {<<"endian">>, atom_to_binary(baseline_app:endianness(W), latin1)},
               {<<"name">>, Name},
               {<<"log_event">>, boolean_to_binary(true)}
              ],
              [
               {<<"get nodeid reply">>, null, mandatory},
               {<<"nodeid">>, integer, optional},
               {<<"result">>, string, mandatory},
               {<<"error_code">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, <<"nodeid">>);
        {error, Reason} ->
            {error, Reason}
    end.


-spec free_node_id(mgmepi()) -> ok|{error, _}.
free_node_id(#mgmepi{timeout=T}=M) ->
    free_node_id(M, T).

-spec free_node_id(mgmepi(), timeout()) -> ok|{error, _}.
free_node_id(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_end_session/1
    %% ~/src/mgmsrv/Services.cpp: MgmApiSession::endSession/2, NOTEXIST:end_of_protocol
    %%
    case call(W,
              <<"end session">>,
              [],
              [
               {<<"end session reply">>, null, mandatory}
              ],
              binary:compile_pattern(<<?LS>>),
              Timeout) of
        {ok, [], []} ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

%% == private ==

-spec worker(mgmepi()) -> pid().
worker(#mgmepi{worker=W})
  when is_pid(W) ->
    W.

%% == internal ==

cleanup(#mgmepi{worker=W, link=true}=M) ->
    true = unlink(W),
    cleanup(M#mgmepi{link = false});
cleanup(#mgmepi{sup=S, worker=W}=M)
  when S =/= undefined, W =/= undefined ->
    ok = supervisor:terminate_child(S, W),
    cleanup(M#mgmepi{sup = undefined, worker = undefined});
cleanup(_) ->
    ok.

setup(Sup, Worker) ->
    #mgmepi{sup = Sup, worker = Worker,
            link = link(Worker), timeout = timer:minutes(1)}.


checkout([]) ->
    {error, not_found};
checkout([H|T]) ->
    case supervisor:start_child(H, []) of
        {ok, Child} ->
            {ok, setup(H, Child)};
        {ok, Child, _Info} ->
            {ok, setup(H, Child)};
        {error, _Reason} ->
            checkout(T)
    end.
