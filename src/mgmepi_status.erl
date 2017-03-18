-module(mgmepi_status).

-include("internal.hrl").

-import(mgmepi_client, [call/5]).
-import(mgmepi_util, [get_value/2, implode/3]).

%% -- public --
-export([get_status/1, get_status/2, get_status/3]).

%% -- internal --
-type(status() :: [{pos_integer(), [{binary(), binary()|integer()}]}]).

%% == public ==

-spec get_status(mgmepi()) -> {ok, status()}|{error, _}.
get_status(#mgmepi{timeout=T}=M) ->
    get_status(M, [], T).

-spec get_status(mgmepi(), [integer()]) -> {ok, status()}|{error, _}.
get_status(#mgmepi{timeout=T}=M, Types) ->
    get_status(M, Types, T).

-spec get_status(mgmepi(), [integer()], timeout()) -> {ok, status()}|{error, _}.
get_status(#mgmepi{worker=W}, Types, Timeout)
  when is_list(Types), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_status/1
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_status2/2
    %%
    Args = case length(Types) of
               0 ->
                   [];
               _ ->
                   [{<<"types">>, implode(fun get_node_type/1, Types, <<" ">>)}]
           end,
    case call(W,
              <<"get status">>,
              Args,
              [
               {<<"node status">>, null, mandatory},
               {<<"nodes">>, integer, mandatory}
              ],
              Timeout) of
        {ok, _, List} ->
            {ok, unpack(List)};
        {error, Reason} ->
            {error, Reason}
    end.

%% == internal ==

get_node_type(NodeType) ->
    get_value(NodeType, node_type()).

unpack(List) ->
    unpack(List, <<"0">>, [], []).

unpack([], B, L1, L2) ->
    tl(lists:reverse(L2, [{binary_to_integer(B), L1}]));
unpack([[K, V]|T], B, L1, L2) ->
    case binary:split(K, <<".">>, [global]) of
        [<<"node">>, B, F] ->
            unpack(T, B, [{F, value(F, V)}|L1], L2);

        [<<"node">>, N, F] ->
            unpack(T, N, [{F, value(F, V)}], [{binary_to_integer(B), L1}|L2])
    end.

value(<<"type">>, V) ->
    V;
value(<<"status">>, V) ->
    V;
value(<<"startphase">>, V) ->
    binary_to_integer(V);
value(<<"dynamic_id">>, V) ->
    binary_to_integer(V);
value(<<"node_group">>, V) ->
    binary_to_integer(V);
value(<<"version">>, V) ->
    binary_to_integer(V);
value(<<"mysql_version">>, V) ->
    binary_to_integer(V);
value(<<"connect_count">>, V) ->
    binary_to_integer(V);
value(<<"address">>, V) ->
    V.


node_type() ->
    [
     {?NDB_MGM_NODE_TYPE_API, <<"API">>},
     {?NDB_MGM_NODE_TYPE_NDB, <<"NDB">>},
     {?NDB_MGM_NODE_TYPE_MGM, <<"MGM">>}
    ].
