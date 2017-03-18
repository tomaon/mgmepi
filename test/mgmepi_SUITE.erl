-module(mgmepi_SUITE).

-include_lib("common_test/include/ct.hrl").

-include("../include/mgmepi.hrl").

%% -- public --
-export([all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/2, end_per_group/2]).

-export([set_timeout_test/1]).
-export([check_connection_test/1]).
-export([get_version_test/1]).

-export([alloc_node_id_test/1, free_node_id_test/1]).

%% -- private --
-export([test/4]).

%% == public ==

all() -> [
          {group, group_public}
         ].

groups() -> [
             {group_public, [sequence], [
                                         set_timeout_test,
                                         check_connection_test,
                                         get_version_test
                                        ]}
            ].

init_per_suite(Config) ->
    case ok =:= setup(env) andalso test(start, []) of
        ok ->
            Config;
        {error, Reason} ->
            ok = ct:fail(Reason)
    end.

end_per_suite(_Config) ->
    case test(stop, []) of
        ok ->
            ok;
        {error, Reason} ->
            ok = ct:fail(Reason)
    end.

init_per_group(_GroupName, Config) ->
    case test(checkout, []) of
        {ok, Handle} ->
            true = unlink(test(worker, [Handle])), % private
            save(Config, Handle);
        {error, Reason} ->
            ok = ct:fail(Reason)
    end.

end_per_group(_GroupName, Config) ->
    case test(Config, checkin, []) of
        ok ->
            ok;
        {error, Reason} ->
            ok = ct:fail(Reason)
    end.


set_timeout_test(Config) ->
    _ = test(Config, set_timeout, [timer:seconds(30)]).


check_connection_test(Config) ->
    ok = test(Config, check_connection, []).


get_version_test(Config) ->
    {ok, _} = test(Config, get_version, []).


alloc_node_id_test(Config) -> % << mgmepi_event_SUITE
    {ok, NodeId}= test(Config, alloc_node_id, []),
    [{node_id, NodeId}|Config].

free_node_id_test(Config) -> % << mgmepi_event_SUITE
    ok = test(Config, free_node_id, []).

%% == private ==

test(Config, Module, Function, Args) ->
    baseline_ct:test(Module, Function, [?config(handle, Config)|Args]).

%% == internal ==

save(Config, Pid) ->
    [{handle, Pid}|Config].

setup(Key) ->
    baseline_ct:setup(Key).

test(Function, Args) ->
    baseline_ct:test(mgmepi, Function, Args).

test(Config, Function, Args) ->
    test(Config, mgmepi, Function, Args).
