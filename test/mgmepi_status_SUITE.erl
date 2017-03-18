-module(mgmepi_status_SUITE).

-include_lib("common_test/include/ct.hrl").

-include("../include/mgmepi.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([get_status_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         get_status_test
                                        ]}
            ].

init_per_suite(Config) ->
    mgmepi_SUITE:init_per_suite(Config).

end_per_suite(Config) ->
    mgmepi_SUITE:end_per_suite(Config).

init_per_group(GroupName, Config) ->
    mgmepi_SUITE:init_per_group(GroupName, Config).

end_per_group(GroupName, Config) ->
    mgmepi_SUITE:end_per_group(GroupName, Config).


get_status_test(Config) ->
    L = [
         [?NDB_MGM_NODE_TYPE_NDB, ?NDB_MGM_NODE_TYPE_MGM, ?NDB_MGM_NODE_TYPE_API ]
        ],
    {ok, _} = test(Config, get_status, L),
    {ok, _} = test(Config, get_status, []).

%% == internal ==

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_status, Function, Args).
