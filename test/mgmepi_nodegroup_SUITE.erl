-module(mgmepi_nodegroup_SUITE).

-include_lib("common_test/include/ct.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([create_nodegroup_test/1, drop_nodegroup_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         create_nodegroup_test, drop_nodegroup_test
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


create_nodegroup_test(Config) ->
    {ok, NodeGroup} = test(Config, create_nodegroup, [[2, 5]]),
    {save_config, [{node_group, NodeGroup}|Config]}.

drop_nodegroup_test(Config) ->
    {create_nodegroup_test, Saved} = ?config(saved_config, Config),
    ok = test(Config, drop_nodegroup, [?config(node_group, Saved)]).

%% == internal ==

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_nodegroup, Function, Args).
