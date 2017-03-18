-module(mgmepi_node).

-include("internal.hrl").

-import(mgmepi_client, [call/4, call/5]).
-import(mgmepi_util, [boolean_to_binary/1, get_result/1, get_result/2, implode/3]).

%% -- public --
-export([dump_state/3, dump_state/4]).
-export([enter_single_user/2, enter_single_user/3]).
-export([exit_single_user/1, exit_single_user/2]).
-export([start/2, start/3, start_all/1, start_all/2]).
-export([stop/4, stop/5, stop_all/3, stop_all/4]).
-export([restart/6, restart/7, restart_all/4, restart_all/5]).

%% == public ==

-spec dump_state(mgmepi(), node_id(), [integer()]) -> ok|{error, _}.
dump_state(#mgmepi{timeout=T}=M, NodeId, Args) ->
    dump_state(M, NodeId, Args, T).

-spec dump_state(mgmepi(), node_id(), [integer()], timeout()) -> ok|{error, _}.
dump_state(#mgmepi{worker=W}, NodeId, Args, Timeout)
  when ?IS_NODE_ID(NodeId), is_list(Args), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_dump_state/5
    %%
    case call(W,
              <<"dump state">>, % size(Packet) < 256-20 ?
              [
               {<<"node">>, integer_to_binary(NodeId)},
               {<<"args">>, implode(fun integer_to_binary/1, Args, <<" ">>)}
              ],
              [
               {<<"dump state reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.


-spec enter_single_user(mgmepi(), node_id()) -> ok|{error, _}.
enter_single_user(#mgmepi{timeout=T}=M, NodeId) ->
    enter_single_user(M, NodeId, T).

-spec enter_single_user(mgmepi(), node_id(), timeout()) -> ok|{error, _}.
enter_single_user(#mgmepi{worker=W}, NodeId, Timeout)
  when ?IS_NODE_ID(NodeId), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_enter_single_user/3
    %%
    case call(W,
              <<"enter single user">>,
              [
               {<<"nodeId">>, integer_to_binary(NodeId)} % ignore?
              ],
              [
               {<<"enter single user reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.

-spec exit_single_user(mgmepi()) -> ok|{error, _}.
exit_single_user(#mgmepi{timeout=T}=M) ->
    exit_single_user(M, T).

-spec exit_single_user(mgmepi(), timeout()) -> ok|{error, _}.
exit_single_user(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: exit_single_user/2
    %%
    case call(W,
              <<"exit single user">>,
              [
               {<<"exit single user reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.


-spec start(mgmepi(), [node_id()]) -> {ok, integer()}|{error, _}.
start(#mgmepi{timeout=T}=M, NodeIds) ->
    start(M, NodeIds, T, 0).

-spec start(mgmepi(), [node_id()], timeout()) -> {ok, integer()}|{error, _}.
start(#mgmepi{worker=W}, NodeIds, Timeout)
  when is_list(NodeIds), ?IS_TIMEOUT(Timeout) ->
    start(W, NodeIds, Timeout, 0).

start(_Pid, [], _Timeout, Started) ->
    {ok, Started};
start(Pid, [H|T], Timeout, Started) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_start/3
    %%
    case call(Pid,
              <<"start">>,
              [
               {<<"node">>, integer_to_binary(H)} % = NDB (--nostart,-n)
              ],
              [
               {<<"start reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            case get_result(List) of
                ok ->
                    start(Pid, T, Timeout, Started+1);
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec start_all(mgmepi()) -> {ok, integer()}|{error, _}.
start_all(#mgmepi{timeout=T}=M) ->
    start_all(M, T).

-spec start_all(mgmepi(), timeout()) -> {ok, integer()}|{error, _}.
start_all(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_start/3
    %%
    case call(W,
              <<"start all">>,
              [
               {<<"start reply">>, null, mandatory},
               {<<"result">>, string, mandatory},
               {<<"started">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, <<"started">>);
        {error, Reason} ->
            {error, Reason}
    end.


-spec stop(mgmepi(), [node_id()], boolean(), boolean()) ->
                  {ok, integer()}|{error, _}.
stop(#mgmepi{timeout=T}=M, NodeIds, Abort, Force) ->
    stop(M, NodeIds, Abort, Force, T).

-spec stop(mgmepi(), [node_id()], boolean(), boolean(), timeout()) ->
                  {ok, integer()}|{error, _}.
stop(#mgmepi{worker=W}, NodeIds, Abort, Force, Timeout)
  when is_list(NodeIds), is_boolean(Abort), is_boolean(Force), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_stop4/6
    %%
    case call(W,
              <<"stop v2">>,
              [
               {<<"node">>, implode(fun integer_to_binary/1, NodeIds, <<" ">>)},
               {<<"abort">>, boolean_to_binary(Abort)},
               {<<"force">>, boolean_to_binary(Force)}
              ],
              [
               {<<"stop reply">>, null, mandatory},
               {<<"stopped">>, integer, optional},
               {<<"result">>, string, mandatory},
               {<<"disconnect">>, integer, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, [<<"stopped">>, <<"disconnect">>]);
        {error, Reason} ->
            {error, Reason}
    end.

-spec stop_all(mgmepi(), [integer()], boolean()) -> {ok, integer()}|{error, _}.
stop_all(#mgmepi{timeout=T}=M, Types, Abort) ->
    stop_all(M, Types, Abort, T).

-spec stop_all(mgmepi(), [integer()], boolean(), timeout()) -> {ok, integer()}|{error, _}.
stop_all(#mgmepi{worker=W}, Types, Abort, Timeout)
  when is_list(Types), is_boolean(Abort), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_stop4/6
    %%
    F = fun (?NDB_MGM_NODE_TYPE_NDB) -> <<"db">>; % != ndb
            (?NDB_MGM_NODE_TYPE_MGM) -> <<"mgm">>
        end,
    case call(W,
              <<"stop all">>, % v2
              [
               {<<"abort">>, boolean_to_binary(Abort)},
               {<<"stop">>, implode(F, Types, <<",">>)}
              ],
              [
               {<<"stop reply">>, null, mandatory},
               {<<"stopped">>, integer, optional},
               {<<"result">>, string, mandatory},
               {<<"disconnect">>, integer, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, [<<"stopped">>, <<"disconnect">>]);
        {error, Reason} ->
            {error, Reason}
    end.


-spec restart(mgmepi(), boolean(), boolean(), boolean(),
              boolean(), [node_id()]) -> {ok, integer()}|{error, _}.
restart(#mgmepi{timeout=T}=M, Abort, Initial, NoStart, Force, Nodes) ->
    restart(M, Abort, Initial, NoStart, Force, Nodes, T).

-spec restart(mgmepi(), boolean(), boolean(), boolean(),
              boolean(), [node_id()], timeout()) -> {ok, integer()}|{error, _}.
restart(#mgmepi{worker=W}, Abort, Initial, NoStart, Force, Nodes, Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_restart4/8
    %%
    case call(W,
              <<"restart node v2">>,
              [
               {<<"node">>, implode(fun integer_to_binary/1, Nodes, <<" ">>)},
               {<<"abort">>, boolean_to_binary(Abort)},
               {<<"initialstart">>, boolean_to_binary(Initial)},
               {<<"nostart">>, boolean_to_binary(NoStart)},
               {<<"force">>, boolean_to_binary(Force)}
              ],
              [
               {<<"restart reply">>, null, mandatory},
               {<<"result">>, string, mandatory},
               {<<"restarted">>, integer, optional},
               {<<"disconnect">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, [<<"restarted">>, <<"disconnect">>]);
        {error, Reason} ->
            {error, Reason}
    end.

-spec restart_all(mgmepi(), boolean(), boolean(), boolean()) ->
                         {ok, integer()}|{error, _}.
restart_all(#mgmepi{timeout=T}=M, Abort, Initial, NoStart) ->
    restart_all(M, Abort, Initial, NoStart, T).

-spec restart_all(mgmepi(), boolean(), boolean(), boolean(), timeout()) ->
                         {ok, integer()}|{error, _}.
restart_all(#mgmepi{worker=W}, Abort, Initial, NoStart, Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_restart4/8
    %%
    case call(W,
              <<"restart all">>,
              [
               {<<"abort">>, boolean_to_binary(Abort)},
               {<<"initialstart">>, boolean_to_binary(Initial)},
               {<<"nostart">>, boolean_to_binary(NoStart)}
              ],
              [
               {<<"restart reply">>, null, mandatory},
               {<<"result">>, string, mandatory},
               {<<"restarted">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, <<"restarted">>);
        {error, Reason} ->
            {error, Reason}
    end.
