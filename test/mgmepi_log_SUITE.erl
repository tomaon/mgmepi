-module(mgmepi_log_SUITE).

-include_lib("common_test/include/ct.hrl").

-include("../include/mgmepi.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([get_filter_test/1, set_filter_test/1,
         get_loglevel_test/1, set_loglevel_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         set_filter_test, get_filter_test,
                                         set_loglevel_test, get_loglevel_test
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


get_filter_test(Config) ->
    {
      ok,
      [
       {?NDB_MGM_EVENT_SEVERITY_ON,       true},
       {?NDB_MGM_EVENT_SEVERITY_DEBUG,    false},
       {?NDB_MGM_EVENT_SEVERITY_INFO,     true},
       {?NDB_MGM_EVENT_SEVERITY_WARNING,  false}, % <-> true
       {?NDB_MGM_EVENT_SEVERITY_ERROR,    true},
       {?NDB_MGM_EVENT_SEVERITY_CRITICAL, true},
       {?NDB_MGM_EVENT_SEVERITY_ALERT,    true}
      ]
    } = test(Config, get_filter, []).

set_filter_test(Config) ->
    L = [
         ?NDB_MGM_EVENT_SEVERITY_WARNING,
         false
        ],
    false = test(Config, set_filter, L).

get_loglevel_test(Config) ->
    {
      ok,
      [
       {?NDB_MGM_EVENT_CATEGORY_STARTUP,       7},
       {?NDB_MGM_EVENT_CATEGORY_SHUTDOWN,      7},
       {?NDB_MGM_EVENT_CATEGORY_STATISTIC,     7},
       {?NDB_MGM_EVENT_CATEGORY_CHECKPOINT,    7},
       {?NDB_MGM_EVENT_CATEGORY_NODE_RESTART,  7},
       {?NDB_MGM_EVENT_CATEGORY_CONNECTION,    8},
       {?NDB_MGM_EVENT_CATEGORY_INFO,          7},
       {?NDB_MGM_EVENT_CATEGORY_WARNING,      15}, % <-> 7
       {?NDB_MGM_EVENT_CATEGORY_ERROR,        15},
       {?NDB_MGM_EVENT_CATEGORY_CONGESTION,    7},
       {?NDB_MGM_EVENT_CATEGORY_DEBUG,         7},
       {?NDB_MGM_EVENT_CATEGORY_BACKUP,       15},
       {?NDB_MGM_EVENT_CATEGORY_SCHEMA,        7}
      ]
    } = test(Config, get_loglevel, []).

set_loglevel_test(Config) ->
    L = [
         1,
         ?NDB_MGM_EVENT_CATEGORY_WARNING,
         15
        ],
    ok = test(Config, set_loglevel, L).

%% == internal ==

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_log, Function, Args).
