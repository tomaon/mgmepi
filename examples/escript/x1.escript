#!/usr/bin/env escript
%% -*- erlang -*-
%%! -s mgmepi

-include_lib("mgmepi/include/mgmepi.hrl").

get_events(0) ->
    ok;
get_events(N) ->
    receive
        {_, Binary} ->
            E = mgmepi_event:get_event(Binary),
            io:format("[~p] type: ~p~n", [N, proplists:get_value(<<"type">>, E)])
    after
        3000 ->
            io:format("timeout~n")
    end,
    get_events(N - 1).

listen_event(M) ->
    L = [
         {?NDB_MGM_EVENT_CATEGORY_STARTUP,      15},
         {?NDB_MGM_EVENT_CATEGORY_SHUTDOWN,     15},
         {?NDB_MGM_EVENT_CATEGORY_STATISTIC,    15},
         {?NDB_MGM_EVENT_CATEGORY_CHECKPOINT,   15},
         {?NDB_MGM_EVENT_CATEGORY_NODE_RESTART, 15},
         {?NDB_MGM_EVENT_CATEGORY_CONNECTION,   15},
         {?NDB_MGM_EVENT_CATEGORY_BACKUP,       15},
         {?NDB_MGM_EVENT_CATEGORY_CONGESTION,   15},
         {?NDB_MGM_EVENT_CATEGORY_DEBUG,        15},
         {?NDB_MGM_EVENT_CATEGORY_INFO,         15},
         {?NDB_MGM_EVENT_CATEGORY_WARNING,      15},
         {?NDB_MGM_EVENT_CATEGORY_ERROR,        15},
         {?NDB_MGM_EVENT_CATEGORY_SCHEMA,       15}
        ],
    mgmepi_event:listen_event(M, L).


main(_) ->
    case mgmepi:checkout() of
        {ok, M} ->
            mgmepi_config:get_config(M),
            case listen_event(M) of
                ok ->
                    get_events(1000)
            end,
            ok = mgmepi:checkin(M)
    end.
