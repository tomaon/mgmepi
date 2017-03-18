-module(mgmepi_node_SUITE).

-include_lib("common_test/include/ct.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([dump_state_test/1]).

-export([enter_single_user_test/1, exit_single_user_test/1]).
-export([start_test/1, start_all_test/1]).
-export([stop_test/1, stop_all_test/1]).
-export([restart_test/1, restart_all_test/1]).

%% == public ==

all() -> [
          {group, group_public},
          {group, group_skip}
         ].

groups() -> [
             {group_public, [sequence], [
                                         dump_state_test
                                        ]},

             {group_skip, [sequence], [
                                       start_test, start_all_test,
                                       stop_test, stop_all_test,
                                       restart_test, restart_all_test
                                      ]}
            ].

init_per_suite(Config) ->
    mgmepi_SUITE:init_per_suite(Config).

end_per_suite(Config) ->
    mgmepi_SUITE:end_per_suite(Config).

init_per_group(group_skip, _Config) ->
    {skip, reason};
init_per_group(GroupName, Config) ->
    mgmepi_SUITE:init_per_group(GroupName, Config).

end_per_group(GroupName, Config) ->
    mgmepi_SUITE:end_per_group(GroupName, Config).


dump_state_test(Config) ->
    %%
    %% ~/include/kernel/signaldata/DumpStateOrd.hpp: enum DumpStateType
    %%
    L = [
         1,
         [1000] % DumpPageMemory
        ],
    ok = test(Config, dump_state, L).


enter_single_user_test(Config) -> % << mgmepi_event_SUITE
    ok = test(Config, enter_single_user, [?config(node_id, Config)]).

exit_single_user_test(Config) -> % << mgmepi_event_SUITE
    ok = test(Config, exit_single_user, []).


start_test(_Config) -> ok.
start_all_test(_Config) -> ok.


stop_test(_Config) -> ok.
stop_all_test(_Config) -> ok.


restart_test(_Config) -> ok.
restart_all_test(_Config) -> ok.

%% == internal ==

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_node, Function, Args).
