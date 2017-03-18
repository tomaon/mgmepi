-module(mgmepi_log).

-include("internal.hrl").

-import(mgmepi_client, [call/4, call/5]).
-import(mgmepi_util, [boolean_to_binary/1, get_result/1, get_value/2]).

%% -- public --
-export([get_filter/1, get_filter/2]).
-export([set_filter/3, set_filter/4]).
-export([get_loglevel/1, get_loglevel/2]).
-export([set_loglevel/4, set_loglevel/5]).

%% -- internal --
-define(NDB_MGM_MIN_EVENT_CATEGORY, ?NDB_MGM_EVENT_CATEGORY_STARTUP).
-define(NDB_MGM_MAX_EVENT_CATEGORY, ?NDB_MGM_EVENT_CATEGORY_SCHEMA).

-define(IS_EVENT_CATEGORY(T), (is_integer(T)
                               andalso (T >= ?NDB_MGM_MIN_EVENT_CATEGORY)
                               andalso (T =< ?NDB_MGM_MAX_EVENT_CATEGORY))).

-define(NDB_MGM_MIN_EVENT_SEVERITY, ?NDB_MGM_EVENT_SEVERITY_ON).
-define(NDB_MGM_MAX_EVENT_SEVERITY, ?NDB_MGM_EVENT_SEVERITY_ALL).

-define(IS_EVENT_SEVERITY(T), (is_integer(T)
                               andalso (T >= ?NDB_MGM_MIN_EVENT_SEVERITY)
                               andalso (T =< ?NDB_MGM_MAX_EVENT_SEVERITY))).

-type(event_category() :: ?NDB_MGM_MIN_EVENT_CATEGORY .. ?NDB_MGM_MAX_EVENT_CATEGORY).

-type(event_severity() :: ?NDB_MGM_MIN_EVENT_SEVERITY .. ?NDB_MGM_MAX_EVENT_SEVERITY).

%% == public ==

-spec get_filter(mgmepi()) -> {ok, [{integer(), boolean()}]}|{error, _}.
get_filter(#mgmepi{timeout=T}=M) ->
    get_filter(M, T).

-spec get_filter(mgmepi(), timeout()) -> {ok, [{integer(), boolean()}]}|{error, _}.
get_filter(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_clusterlog_severity_filter/3
    %%
    case call(W,
              <<"get info clusterlog">>,
              [
               {<<"clusterlog">>, null, mandatory},
               {<<"enabled">>, boolean, mandatory},
               {<<"debug">>, boolean, mandatory},
               {<<"info">>, boolean, mandatory},
               {<<"warning">>, boolean, mandatory},
               {<<"error">>, boolean, mandatory},
               {<<"critical">>, boolean, mandatory},
               {<<"alert">>, boolean, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            {ok, lists:keymap(fun match_event_severity/1, 1, List)};
        {error, Reason} ->
            {error, Reason}
    end.


-spec set_filter(mgmepi(), event_severity(), boolean()) -> boolean()|{error, _}.
set_filter(#mgmepi{timeout=T}=M, Severity, Enable) ->
    set_filter(M, Severity, Enable, T).

-spec set_filter(mgmepi(), event_severity(), boolean(), timeout()) -> boolean()|{error, _}.
set_filter(#mgmepi{worker=W}, Severity, Enable, Timeout)
  when ?IS_EVENT_SEVERITY(Severity), is_boolean(Enable), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_set_clusterlog_severity_filter/4
    %%
    case call(W,
              <<"set logfilter">>,
              [
               {<<"level">>, integer_to_binary(Severity)},
               {<<"enable">>, boolean_to_binary(Enable)}
              ],
              [
               {<<"set logfilter reply">>, null, mandatory},
               {<<"result">>, boolean, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_value(<<"result">>, List);
        {error, Reason} ->
            {error, Reason}
    end.


-spec get_loglevel(mgmepi()) -> {ok, [{integer(), integer()}]}|{error, _}.
get_loglevel(#mgmepi{timeout=T}=M) ->
    get_loglevel(M, T).

-spec get_loglevel(mgmepi(), timeout()) -> {ok, [{integer(), integer()}]}|{error, _}.
get_loglevel(#mgmepi{worker=W}, Timeout)
  when ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_clusterlog_loglevel/3
    %%
    case call(W,
              <<"get cluster loglevel">>,
              [
               {<<"get cluster loglevel">>, null, mandatory},
               {<<"startup">>, integer, mandatory},
               {<<"shutdown">>, integer, mandatory},
               {<<"statistics">>, integer, mandatory},
               {<<"checkpoint">>, integer, mandatory},
               {<<"noderestart">>, integer, mandatory},
               {<<"connection">>, integer, mandatory},
               {<<"info">>, integer, mandatory},
               {<<"warning">>, integer, mandatory},
               {<<"error">>, integer, mandatory},
               {<<"congestion">>, integer, mandatory},
               {<<"debug">>, integer, mandatory},
               {<<"backup">>, integer, mandatory},
               {<<"schema">>, integer, optional}        % !, mandatory?
              ],
              Timeout) of
        {ok, List, []} ->
            {ok, lists:keymap(fun match_event_category/1, 1, List)};
        {error, Reason} ->
            {error, Reason}
    end.


-spec set_loglevel(mgmepi(), node_id(), event_category(), loglevel()) -> ok|{error, _}.
set_loglevel(#mgmepi{timeout=T}=M, NodeId, Category, Level) ->
    set_loglevel(M, NodeId, Category, Level, T).

-spec set_loglevel(mgmepi(), node_id(), event_category(), loglevel(), timeout()) -> ok|{error, _}.
set_loglevel(#mgmepi{worker=W}, NodeId, Category, Level, Timeout)
  when ?IS_NODE_ID(NodeId), ?IS_EVENT_CATEGORY(Category),
       ?IS_LOGLEVEL(Level), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_set_clusterlog_loglevel/5
    %%
    case call(W,
              <<"set cluster loglevel">>,
              [
               {<<"node">>, integer_to_binary(NodeId)}, % ?
               {<<"category">>, integer_to_binary(Category)},
               {<<"level">>, integer_to_binary(Level)}
              ],
              [
               {<<"set cluster loglevel reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.

%% -- internal --

match_event_category(Category) ->
    get_value(Category, event_category()).

match_event_severity(Severity) ->
    get_value(Severity, event_severity()).


event_category() ->
    [
     {<<"startup">>,     ?NDB_MGM_EVENT_CATEGORY_STARTUP},
     {<<"shutdown">>,    ?NDB_MGM_EVENT_CATEGORY_SHUTDOWN},
     {<<"statistics">>,  ?NDB_MGM_EVENT_CATEGORY_STATISTIC},
     {<<"checkpoint">>,  ?NDB_MGM_EVENT_CATEGORY_CHECKPOINT},
     {<<"noderestart">>, ?NDB_MGM_EVENT_CATEGORY_NODE_RESTART},
     {<<"connection">>,  ?NDB_MGM_EVENT_CATEGORY_CONNECTION},
     {<<"backup">>,      ?NDB_MGM_EVENT_CATEGORY_BACKUP},
     {<<"congestion">>,  ?NDB_MGM_EVENT_CATEGORY_CONGESTION},
     {<<"debug">>,       ?NDB_MGM_EVENT_CATEGORY_DEBUG},
     {<<"info">>,        ?NDB_MGM_EVENT_CATEGORY_INFO},
     {<<"warning">>,     ?NDB_MGM_EVENT_CATEGORY_WARNING},
     {<<"error">>,       ?NDB_MGM_EVENT_CATEGORY_ERROR},
     {<<"schema">>,      ?NDB_MGM_EVENT_CATEGORY_SCHEMA}
    ].

event_severity() ->
    [
     {<<"enabled">>,  ?NDB_MGM_EVENT_SEVERITY_ON},
     {<<"debug">>,    ?NDB_MGM_EVENT_SEVERITY_DEBUG},
     {<<"info">>,     ?NDB_MGM_EVENT_SEVERITY_INFO},
     {<<"warning">>,  ?NDB_MGM_EVENT_SEVERITY_WARNING},
     {<<"error">>,    ?NDB_MGM_EVENT_SEVERITY_ERROR},
     {<<"critical">>, ?NDB_MGM_EVENT_SEVERITY_CRITICAL},
     {<<"alert">>,    ?NDB_MGM_EVENT_SEVERITY_ALERT},
     {<<"all">>,      ?NDB_MGM_EVENT_SEVERITY_ALL}
    ].
