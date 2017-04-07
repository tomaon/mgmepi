-module(mgmepi_config_SUITE).

-include_lib("common_test/include/ct.hrl").

-include("../include/mgmepi.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([get_connection_config_test/1, debug_connection_config_test/1,
         get_node_config_test/1, debug_node_config_test/1,
         get_nodes_config_test/1, debug_nodes_config_test/1,
         get_system_config_test/1, debug_system_config_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         {group, group_get_config}
                                        ]},

             {group_get_config, [], [
                                     get_connection_config_test, debug_connection_config_test,
                                     get_node_config_test, debug_node_config_test,
                                     get_nodes_config_test, debug_nodes_config_test,
                                     get_system_config_test, debug_system_config_test
                                    ]}
            ].

init_per_suite(Config) ->
    mgmepi_SUITE:init_per_suite(Config).

end_per_suite(Config) ->
    mgmepi_SUITE:end_per_suite(Config).

init_per_group(group_get_config, Config) ->
    case test(Config, get_config) of
        {ok, L} ->
            save(Config, L);
        {error, Reason} ->
            ok = ct:fail(Reason)
    end;
init_per_group(GroupName, Config) ->
    mgmepi_SUITE:init_per_group(GroupName, Config).

end_per_group(GroupName, Config) ->
    mgmepi_SUITE:end_per_group(GroupName, Config).


get_connection_config_test(Config) ->
    7 = length(test(Config, get_connection_config,   [1])),
    4 = length(test(Config, get_connection_config,  [91])),
    4 = length(test(Config, get_connection_config, [201])).

debug_connection_config_test(Config) ->
    7 = length(test(Config, debug_connection_config,   [1])),
    4 = length(test(Config, debug_connection_config,  [91])),
    4 = length(test(Config, debug_connection_config, [201])).

get_node_config_test(Config) ->
    1 = length(test(Config, get_node_config,   [1])),
    1 = length(test(Config, get_node_config,  [91])),
    1 = length(test(Config, get_node_config, [201])).

debug_node_config_test(Config) ->
    1 = length(test(Config, debug_node_config,   [1])),
    1 = length(test(Config, debug_node_config,  [91])),
    1 = length(test(Config, debug_node_config, [201])).

get_nodes_config_test(Config) ->
    4 = length(test(Config, get_nodes_config, [?NDB_MGM_NODE_TYPE_NDB])),
    1 = length(test(Config, get_nodes_config, [?NDB_MGM_NODE_TYPE_MGM])),
    3 = length(test(Config, get_nodes_config, [?NDB_MGM_NODE_TYPE_API])).

debug_nodes_config_test(Config) ->
    4 = length(test(Config, debug_nodes_config, [?NDB_MGM_NODE_TYPE_NDB])),
    1 = length(test(Config, debug_nodes_config, [?NDB_MGM_NODE_TYPE_MGM])),
    3 = length(test(Config, debug_nodes_config, [?NDB_MGM_NODE_TYPE_API])).

get_system_config_test(Config) ->
    1 = length(test(Config, get_system_config, [])).

debug_system_config_test(Config) ->
    1 = length(test(Config, debug_system_config, [])).

%% == internal ==

save(Config, List) ->
    [{config, List}|Config].

test(Config, Function) ->
    mgmepi_SUITE:test(Config, mgmepi_config, Function, []).

test(Config, Function, Args) ->
    baseline_ct:test(mgmepi_config, Function, [?config(config, Config)|Args]).
