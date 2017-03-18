-module(mgmepi_backup_SUITE).

-include_lib("common_test/include/ct.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([start_backup_test/1, abort_backup_test/1]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         start_backup_test, abort_backup_test
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


start_backup_test(Config) ->
    {error, _} = test(Config, start_backup, [2, 0, 0]), % Diskless=1
    {save_config, [{backup_id, 0}|Config]}.

abort_backup_test(Config) ->
    {start_backup_test, Saved} = ?config(saved_config, Config),
    ok = test(Config, abort_backup, [?config(backup_id, Saved)]). % ok?!

%% == internal ==

test(Config, Function, Args) ->
    mgmepi_SUITE:test(Config, mgmepi_backup, Function, Args).
