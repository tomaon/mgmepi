-module(mgmepi_event_SUITE).

-include_lib("common_test/include/ct.hrl").

-include("../include/mgmepi.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2,
         init_per_testcase/2, end_per_testcase/2]).

-export([listen_event_test/1]).

-export([enter_single_user_test/1, exit_single_user_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [parallel], [
                                         {group, group_event},
                                         {group, group_single_user}
                                        ]},

             {group_event, [sequence], [
                                        listen_event_test
                                       ]},

             {group_single_user, [sequence], [
                                              enter_single_user_test,
                                              exit_single_user_test
                                             ]}
            ].

init_per_suite(Config) ->
    mgmepi_SUITE:init_per_suite(Config).

end_per_suite(Config) ->
    mgmepi_SUITE:end_per_suite(Config).

init_per_group(group_public, Config) ->
    Config;
init_per_group(_GroupName, Config) ->
    mgmepi_SUITE:init_per_group(group_public, Config).

end_per_group(group_public, _Config) ->
    ok;
end_per_group(_GroupName, Config) ->
    mgmepi_SUITE:end_per_group(group_public, Config).

init_per_testcase(enter_single_user_test, Config) ->
    mgmepi_SUITE:alloc_node_id_test(Config);
init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(exit_single_user_test, Config) ->
    mgmepi_SUITE:free_node_id_test(Config);
end_per_testcase(_TestCase, _Config) ->
    ok.


listen_event_test(Config) ->
    L = [
         [

          %% NDB_LE_GlobalCheckpointStarted(9:Info), TODO
          {?NDB_MGM_EVENT_CATEGORY_CHECKPOINT, 10},

          {?NDB_MGM_EVENT_CATEGORY_INFO, 8} % NDB_LE_SingleUser(7:INFO)
         ]
        ],
    ok = test(Config, listen_event, L),
    get_event_test(Config, 1).


enter_single_user_test(Config) ->
    mgmepi_node_SUITE:enter_single_user_test(Config).

exit_single_user_test(Config) ->
    mgmepi_node_SUITE:exit_single_user_test(Config).

%% == internal ==

get_event_test(_Config, 0) ->
    ok;
get_event_test(Config, N) ->
    receive
        {_, Binary} ->
            _ = test(get_event, [Binary]),
            get_event_test(Config, N - 1)
    after
        5000 ->
            ct:fail(timeout)
    end.


test(Function, Args) ->
    baseline_ct:test(mgmepi_event, Function, Args).

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_event, Function, Args).
