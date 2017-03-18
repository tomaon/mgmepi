-module(mgmepi_nodegroup).

-include("internal.hrl").

-import(mgmepi_client, [call/5]).
-import(mgmepi_util, [get_result/1, get_result/2, implode/3]).

%% -- public --
-export([create_nodegroup/2, create_nodegroup/3]).
-export([drop_nodegroup/2, drop_nodegroup/3]).

%% -- internal --
-define(IS_NODE_GROUP(T), (is_integer(T) andalso (0 =< T)  andalso (65536 >= T))).

-type(node_group() :: 0 .. 65536).

%% == public ==

-spec create_nodegroup(mgmepi(), [node_id()]) -> {ok, node_group()}|{error, _}.
create_nodegroup(#mgmepi{timeout=T}=M, NodeIds) ->
    create_nodegroup(M, NodeIds, T).

-spec create_nodegroup(mgmepi(), [node_id()], timeout()) -> {ok, node_group()}|{error, _}.
create_nodegroup(#mgmepi{worker=W}, NodeIds, Timeout)
  when is_list(NodeIds), length(NodeIds) > 0, ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_create_nodegroup/4
    %%
    case call(W,
              <<"create nodegroup">>,
              [
               {<<"nodes">>, implode(fun integer_to_binary/1, NodeIds, <<" ">>)}
              ],
              [
               {<<"create nodegroup reply">>, null, mandatory},
               {<<"ng">>, integer, mandatory},
               {<<"error_code">>, integer, optional},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, <<"ng">>);
        {error, Reason} ->
            {error, Reason}
    end.


-spec drop_nodegroup(mgmepi(), node_group()) -> ok|{error, _}.
drop_nodegroup(#mgmepi{timeout=T}=M, NodeGroup) ->
    drop_nodegroup(M, NodeGroup, T).

-spec drop_nodegroup(mgmepi(), node_group(), timeout()) -> ok|{error, _}.
drop_nodegroup(#mgmepi{worker=W}, NodeGroup, Timeout)
  when ?IS_NODE_GROUP(NodeGroup), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_drop_nodegroup/3
    %%
    %% ERROR -> <<"drop nodegroup reply\nresult: error: -1">>, NO LS!
    %%                                                      ^
    case call(W,
              <<"drop nodegroup">>,
              [
               {<<"ng">>, integer_to_binary(NodeGroup)}
              ],
              [
               {<<"drop nodegroup reply">>, null, mandatory},
               {<<"error_code">>, integer, optional},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.
