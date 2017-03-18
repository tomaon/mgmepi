-module(mgmepi_event).

-include("internal.hrl").

-import(mgmepi_client, [call/6]).
-import(mgmepi_util, [get_value/2, match/3, implode/3, parse/3]).

%% -- public --
-export([listen_event/2, listen_event/3]).
-export([get_event/1]).

%% -- internal --

%%
%% https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster-log-events.html
%%

%% -- ~/include/mgmapi/ndb_logevent.h --

%% enum Ndb_logevent_type
%% - NDB_MGM_EVENT_CATEGORY_CONNECTION -
-define(NDB_LE_Connected,                  0). %  8 INFO
-define(NDB_LE_Disconnected,               1). %  8 ALERT
-define(NDB_LE_CommunicationClosed,        2). %  8 INFO
-define(NDB_LE_CommunicationOpened,        3). %  8 INFO
-define(NDB_LE_ConnectedApiVersion,       51). %  8 INFO
%% - NDB_MGM_EVENT_CATEGORY_CHECKPOINT -
-define(NDB_LE_GlobalCheckpointStarted,    4). %  9 INFO
-define(NDB_LE_GlobalCheckpointCompleted,  5). % 10 INFO
-define(NDB_LE_LocalCheckpointStarted,     6). %  7 INFO
-define(NDB_LE_LocalCheckpointCompleted,   7). %  7 INFO
-define(NDB_LE_LCPStoppedInCalcKeepGci,    8). %  0 ALERT
-define(NDB_LE_LCPFragmentCompleted,       9). % 11 INFO
-define(NDB_LE_UndoLogBlocked,            38). %  7 INFO
-define(NDB_LE_RedoStatus,                73). %  7 INFO
%% - NDB_MGM_EVENT_CATEGORY_STARTUP -
-define(NDB_LE_NDBStartStarted,           10). %  1 INFO
-define(NDB_LE_NDBStartCompleted,         11). %  1 INFO
-define(NDB_LE_STTORRYRecieved,           12). % 15 INFO
-define(NDB_LE_StartPhaseCompleted,       13). %  4 INFO
-define(NDB_LE_CM_REGCONF,                14). %  3 INFO
-define(NDB_LE_CM_REGREF,                 15). %  8 INFO
-define(NDB_LE_FIND_NEIGHBOURS,           16). %  8 INFO
-define(NDB_LE_NDBStopStarted,            17). %  1 INFO
-define(NDB_LE_NDBStopCompleted,          53). %  1 INFO
-define(NDB_LE_NDBStopForced,             59). %  1 ALERT
-define(NDB_LE_NDBStopAborted,            18). %  1 INFO
-define(NDB_LE_StartREDOLog,              19). %  4 INFO
-define(NDB_LE_StartLog,                  20). % 10 INFO
-define(NDB_LE_UNDORecordsExecuted,       21). % 15 INFO
-define(NDB_LE_StartReport,               60). %  4 INFO
-define(NDB_LE_LogFileInitStatus,         71). %  7 INFO
-define(NDB_LE_LogFileInitCompStatus,     72). %  7 INFO
-define(NDB_LE_StartReadLCP,              77). % 10 INFO
-define(NDB_LE_ReadLCPComplete,           78). % 10 INFO
-define(NDB_LE_RunRedo,                   79). %  8 INFO
-define(NDB_LE_RebuildIndex,              80). % 10 INFO
%% - NDB_MGM_EVENT_CATEGORY_NODE_RESTART -
-define(NDB_LE_NR_CopyDict,               22). %  7 INFO
-define(NDB_LE_NR_CopyDistr,              23). %  7 INFO
-define(NDB_LE_NR_CopyFragsStarted,       24). %  7 INFO
-define(NDB_LE_NR_CopyFragDone,           25). % 10 INFO
-define(NDB_LE_NR_CopyFragsCompleted,     26). %  7 INFO
-define(NDB_LE_NodeFailCompleted,         27). %  8 ALERT
-define(NDB_LE_NODE_FAILREP,              28). %  8 ALERT
-define(NDB_LE_ArbitState,                29). %  6 INFO
-define(NDB_LE_ArbitResult,               30). %  2 ALERT
-define(NDB_LE_GCP_TakeoverStarted,       31). %  7 INFO
-define(NDB_LE_GCP_TakeoverCompleted,     32). %  7 INFO
-define(NDB_LE_LCP_TakeoverStarted,       33). %  7 INFO
-define(NDB_LE_LCP_TakeoverCompleted,     34). %  7 INFO
-define(NDB_LE_ConnectCheckStarted,       82). %  6 INFO
-define(NDB_LE_ConnectCheckCompleted,     83). %  6 INFO
-define(NDB_LE_NodeFailRejected,          84). %  6 ALERT
%% - NDB_MGM_EVENT_CATEGORY_STATISTIC -
-define(NDB_LE_TransReportCounters,       35). %  8 INFO
-define(NDB_LE_OperationReportCounters,   36). %  8 INFO
-define(NDB_LE_TableCreated,              37). %  7 INFO
-define(NDB_LE_JobStatistic,              39). %  9 INFO
-define(NDB_LE_ThreadConfigLoop,          68). %  9 INFO
-define(NDB_LE_SendBytesStatistic,        40). %  9 INFO
-define(NDB_LE_ReceiveBytesStatistic,     41). %  9 INFO
-define(NDB_LE_MemoryUsage,               50). %  5 INFO
-define(NDB_LE_MTSignalStatistics,        70). %  9 INFO
%% - NDB_MGM_EVENT_CATEGORY_SCHEMA -
-define(NDB_LE_CreateSchemaObject,        74). %  8 INFO
-define(NDB_LE_AlterSchemaObject,         75). %  8 INFO
-define(NDB_LE_DropSchemaObject,          76). %  8 INFO
%% - NDB_MGM_EVENT_CATEGORY_ERROR -
-define(NDB_LE_TransporterError,          42). %  2 ERROR
-define(NDB_LE_TransporterWarning,        43). %  8 WARNING
-define(NDB_LE_MissedHeartbeat,           44). %  8 WARNING
-define(NDB_LE_DeadDueToHeartbeat,        45). %  8 ALERT
-define(NDB_LE_WarningEvent,              46). %  2 WARNING
-define(NDB_LE_SubscriptionStatus,        69). %  2 WARNING
%% - NDB_MGM_EVENT_CATEGORY_INFO -
-define(NDB_LE_SentHeartbeat,             47). % 12 INFO
-define(NDB_LE_CreateLogBytes,            48). % 11 INFO
-define(NDB_LE_InfoEvent,                 49). %  2 INFO
-define(NDB_LE_EventBufferStatus,         58). %  7 INFO
-define(NDB_LE_EventBufferStatus2,        85). %  7 INFO
%% - (SINGLEUSER Events ?) -
-define(NDB_LE_SingleUser,                52). %  7 INFO
%% - NDB_MGM_EVENT_CATEGORY_BACKUP -
-define(NDB_LE_BackupStarted,             54). %  7 INFO
-define(NDB_LE_BackupStatus,              62). %  7 INFO
-define(NDB_LE_BackupCompleted,           56). %  7 INFO
-define(NDB_LE_BackupFailedToStart,       55). %  7 ALERT
-define(NDB_LE_BackupAborted,             57). %  7 ALERT
-define(NDB_LE_RestoreStarted,            66). %  7 INFO
-define(NDB_LE_RestoreMetaData,           63). %  7 INFO
-define(NDB_LE_RestoreData,               64). %  7 INFO
-define(NDB_LE_RestoreLog,                65). %  7 INFO
-define(NDB_LE_RestoreCompleted,          67). %  7 INFO
-define(NDB_LE_SavedEvent,                81). %  7 INFO
%% - (undocumented) -
-define(NDB_LE_LCPRestored,               86). % ?
%% - (unused) -
%%                                        61

%% == public ==

-spec listen_event(mgmepi(), [{integer(), integer()}]) -> ok|{error, _}.
listen_event(#mgmepi{timeout=T}=H, Filter) ->
    listen_event(H, Filter, T).

-spec listen_event(mgmepi(), [{integer(), integer()}], timeout()) -> ok|{error, _}.
listen_event(#mgmepi{worker=W}, Filter, Timeout)
  when is_list(Filter), ?IS_TIMEOUT(Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp : ndb_mgm_listen_event/2
    %%
    case call(W,
              <<"listen event">>,
              [
               {<<"parsable">>, <<"1">>},
               {<<"filter">>, implode(fun tuple_to_binary/1, Filter, <<" ">>)}
              ],
              [
               {<<"listen event">>, null, mandatory},
               {<<"result">>, integer, mandatory},
               {<<"msg">>, string, optional}
              ],
              binary:compile_pattern([<<"<PING>", ?LS>>, <<?LS, ?LS>>]),
              Timeout) of
        {ok, List, []} ->
            case get_value(<<"result">>, List) of
                0 ->
                    ok;
                -1 ->
                    {error, get_value(<<"msg">>, List)}
            end;
        {error, Reason} ->
            {error, Reason}
    end.


-spec get_event(binary()) -> [matched()].
get_event(Binary)
  when is_binary(Binary) ->
    %%
    %% ~/src/mgmapi/ndb_logevent.cpp: ndb_logevent_get_next2/3
    %%
    {ok, H, R} = parse(Binary,
                       [
                        {<<"log event reply">>, null, mandatory},
                        {<<"type">>, integer, mandatory},
                        {<<"time">>, integer, mandatory},
                        {<<"source_nodeid">>, integer, mandatory}
                       ],
                       <<"=">>),
    case match(params(get_value(<<"type">>, H)), R, H) of
        {ok, L, []} ->
            L
    end.

%% == internal ==

tuple_to_binary({C, L}) ->
    implode(fun integer_to_list/1, [C, L], <<"=">>).

%%
%% ~/include/mgmapi/ndb_logevent.h : struct ndb_logevent_*
%%

%%
%% NDB_MGM_EVENT_CATEGORY_CONNECTION
%%
params(?NDB_LE_Connected) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_Disconnected) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_CommunicationClosed) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_CommunicationOpened) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_ConnectedApiVersion) ->
    [
     {<<"node">>, integer, mandatory},
     {<<"version">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_CHECKPOINT
%%
params(?NDB_LE_GlobalCheckpointStarted) ->
    [
     {<<"gci">>, integer, mandatory}
    ];
params(?NDB_LE_GlobalCheckpointCompleted) ->
    [
     {<<"gci">>, integer, mandatory}
    ];
params(?NDB_LE_LocalCheckpointStarted) ->
    [
     {<<"lci">>, integer, mandatory},
     {<<"keep_gci">>, integer, mandatory},
     {<<"restore_gci">>, integer, mandatory}
    ];
params(?NDB_LE_LocalCheckpointCompleted) ->
    [
     {<<"lci">>, integer, mandatory}
    ];
params(?NDB_LE_LCPStoppedInCalcKeepGci) ->
    [
     {<<"data">>, integer, mandatory}
    ];
params(?NDB_LE_LCPFragmentCompleted) ->
    [
     {<<"node">>, integer, mandatory},
     {<<"table_id">>, integer, mandatory},
     {<<"fragment_id">>, integer, mandatory}
    ];
params(?NDB_LE_UndoLogBlocked) ->
    [
     {<<"acc_count">>, integer, mandatory},
     {<<"tup_count">>, integer, mandatory}
    ];
params(?NDB_LE_RedoStatus) ->
    [
     {<<"log_part">>, integer, mandatory},
     {<<"head_file_no">>, integer, mandatory},
     {<<"head_mbyte">>, integer, mandatory},
     {<<"tail_file_no">>, integer, mandatory},
     {<<"tail_mbyte">>, integer, mandatory},
     {<<"total_hi">>, integer, mandatory},
     {<<"total_lo">>, integer, mandatory},
     {<<"free_hi">>, integer, mandatory},
     {<<"free_lo">>, integer, mandatory},
     {<<"no_logfiles">>, integer, mandatory},
     {<<"logfilesize">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_STARTUP
%%
params(?NDB_LE_NDBStartStarted) ->
    [
     {<<"version">>, integer, mandatory}
    ];
params(?NDB_LE_NDBStartCompleted) ->
    [
     {<<"version">>, integer, mandatory}
    ];
params(?NDB_LE_STTORRYRecieved) ->
    [
     {<<"unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_StartPhaseCompleted) ->
    [
     {<<"phase">>, integer, mandatory},
     {<<"starttype">>, integer, mandatory}
    ];
params(?NDB_LE_CM_REGCONF) ->
    [
     {<<"own_id">>, integer, mandatory},
     {<<"president_id">>, integer, mandatory},
     {<<"dynamic_id">>, integer, mandatory}
    ];
params(?NDB_LE_CM_REGREF) ->
    [
     {<<"own_id">>, integer, mandatory},
     {<<"other_id">>, integer, mandatory},
     {<<"cause">>, integer, mandatory}
    ];
params(?NDB_LE_FIND_NEIGHBOURS) ->
    [
     {<<"own_id">>, integer, mandatory},
     {<<"left_id">>, integer, mandatory},
     {<<"right_id">>, integer, mandatory},
     {<<"dynamic_id">>, integer, mandatory}
    ];
params(?NDB_LE_NDBStopStarted) ->
    [
     {<<"stoptype">>, integer, mandatory}
    ];
params(?NDB_LE_NDBStopCompleted) ->
    [
     {<<"action">>, integer, mandatory},
     {<<"signum">>, integer, mandatory}
    ];
params(?NDB_LE_NDBStopForced) ->
    [
     {<<"action">>, integer, mandatory},
     {<<"signum">>, integer, mandatory},
     {<<"error">>, integer, mandatory},
     {<<"sphase">>, integer, mandatory},
     {<<"extra">>, integer, mandatory}
    ];
params(?NDB_LE_NDBStopAborted) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_StartREDOLog) ->
    [
     {<<"node">>, integer, mandatory},
     {<<"keep_gci">>, integer, mandatory},
     {<<"completed_gci">>, integer, mandatory},
     {<<"restorable_gci">>, integer, mandatory}
    ];
params(?NDB_LE_StartLog) ->
    [
     {<<"log_part">>, integer, mandatory},
     {<<"start_mb">>, integer, mandatory},
     {<<"stop_mb">>, integer, mandatory},
     {<<"gci">>, integer, mandatory}
    ];
params(?NDB_LE_UNDORecordsExecuted) ->
    [
     {<<"block">>, integer, mandatory},
     {<<"data1">>, integer, mandatory},
     {<<"data2">>, integer, mandatory},
     {<<"data3">>, integer, mandatory},
     {<<"data4">>, integer, mandatory},
     {<<"data5">>, integer, mandatory},
     {<<"data6">>, integer, mandatory},
     {<<"data7">>, integer, mandatory},
     {<<"data8">>, integer, mandatory},
     {<<"data9">>, integer, mandatory},
     {<<"data10">>, integer, mandatory}
    ];
params(?NDB_LE_StartReport) ->
    [
     {<<"report_type">>, integer, mandatory},
     {<<"remaining_time">>, integer, mandatory},
     {<<"bitmask_size">>, integer, mandatory},
     {<<"bitmask_data">>, string, mandatory}
    ];
params(?NDB_LE_LogFileInitStatus) ->
    [
     {<<"node_id">>, integer, mandatory},
     {<<"total_files">>, integer, mandatory},
     {<<"file_done">>, integer, mandatory},
     {<<"total_mbytes">>, integer, mandatory},
     {<<"mbytes_done">>, integer, mandatory}
    ];
params(?NDB_LE_LogFileInitCompStatus) -> % TODO: not_found
    [
     {<<"reference">>, integer, mandatory},
     {<<"total_log_files">>, integer, mandatory},
     {<<"log_file_init_done">>, integer, mandatory},
     {<<"total_log_mbytes">>, integer, mandatory},
     {<<"log_mbytes_init_done">>, integer, mandatory}
    ];
params(?NDB_LE_StartReadLCP) ->
    [
     {<<"tableid">>, integer, mandatory},
     {<<"fragmentid">>, integer, mandatory}
    ];
params(?NDB_LE_ReadLCPComplete) ->
    [
     {<<"tableid">>, integer, mandatory},
     {<<"fragmentid">>, integer, mandatory},
     {<<"rows_hi">>, integer, mandatory},
     {<<"rows_lo">>, integer, mandatory}
    ];
params(?NDB_LE_RunRedo) ->
    [
     {<<"logpart">>, integer, mandatory},
     {<<"phase">>, integer, mandatory},
     {<<"startgci">>, integer, mandatory},
     {<<"currgci">>, integer, mandatory},
     {<<"stopgci">>, integer, mandatory},
     {<<"startfile">>, integer, mandatory},
     {<<"startmb">>, integer, mandatory},
     {<<"currfile">>, integer, mandatory},
     {<<"currmb">>, integer, mandatory},
     {<<"stopfile">>, integer, mandatory},
     {<<"stopmb">>, integer, mandatory}
    ];
params(?NDB_LE_RebuildIndex) ->
    [
     {<<"instance">>, integer, mandatory},
     {<<"indexid">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_NODE_RESTART
%%
params(?NDB_LE_NR_CopyDict) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_NR_CopyDistr) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_NR_CopyFragsStarted) ->
    [
     {<<"dest_node">>, integer, mandatory}
    ];
params(?NDB_LE_NR_CopyFragDone) ->
    [
     {<<"dest_node">>, integer, mandatory},
     {<<"table_id">>, integer, mandatory},
     {<<"fragment_id">>, integer, mandatory}
    ];
params(?NDB_LE_NR_CopyFragsCompleted) ->
    [
     {<<"dest_node">>, integer, mandatory}
    ];
params(?NDB_LE_NodeFailCompleted) ->
    [
     {<<"block">>, integer, mandatory},
     {<<"failed_node">>, integer, mandatory},
     {<<"completing_node">>, integer, mandatory}
    ];
params(?NDB_LE_NODE_FAILREP) ->
    [
     {<<"failed_node">>, integer, mandatory},
     {<<"failure_state">>, integer, mandatory}
    ];
params(?NDB_LE_ArbitState) ->
    [
     {<<"code">>, integer, mandatory},
     {<<"arbit_node">>, integer, mandatory},
     {<<"ticket_0">>, integer, mandatory},
     {<<"ticket_1">>, integer, mandatory}
    ];
params(?NDB_LE_ArbitResult) ->
    [
     {<<"code">>, integer, mandatory},
     {<<"arbit_node">>, integer, mandatory},
     {<<"ticket_0">>, integer, mandatory},
     {<<"ticket_1">>, integer, mandatory}
    ];
params(?NDB_LE_GCP_TakeoverStarted) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_GCP_TakeoverCompleted) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_LCP_TakeoverStarted) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_LCP_TakeoverCompleted) ->
    [
     {<<"state">>, integer, mandatory}
    ];
params(?NDB_LE_ConnectCheckStarted) ->
    [
     {<<"other_node_count">>, integer, mandatory},
     {<<"reason">>, integer, mandatory},
     {<<"causing_node">>, integer, mandatory}
    ];
params(?NDB_LE_ConnectCheckCompleted) ->
    [
     {<<"nodes_checked">>, integer, mandatory},
     {<<"nodes_suspect">>, integer, mandatory},
     {<<"nodes_failed">>, integer, mandatory}
    ];
params(?NDB_LE_NodeFailRejected) ->
    [
     {<<"reason">>, integer, mandatory},
     {<<"failed_node">>, integer, mandatory},
     {<<"source_node">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_STATISTIC
%%
params(?NDB_LE_TransReportCounters) ->
    [
     {<<"trans_count">>, integer, mandatory},
     {<<"commit_count">>, integer, mandatory},
     {<<"read_count">>, integer, mandatory},
     {<<"simple_read_count">>, integer, mandatory},
     {<<"write_count">>, integer, mandatory},
     {<<"attrinfo_count">>, integer, mandatory},
     {<<"conc_op_count">>, integer, mandatory},
     {<<"abort_count">>, integer, mandatory},
     {<<"scan_count">>, integer, mandatory},
     {<<"range_scan_count">>, integer, mandatory}
    ];
params(?NDB_LE_OperationReportCounters) ->
    [
     {<<"ops">>, integer, mandatory}
    ];
params(?NDB_LE_TableCreated) ->
    [
     {<<"table_id">>, integer, mandatory}
    ];
params(?NDB_LE_JobStatistic) ->
    [
     {<<"mean_loop_count">>, integer, mandatory}
    ];
params(?NDB_LE_ThreadConfigLoop) -> % TODO: not_found
    [
     {<<"data">>, string, mandatory}
    ];
params(?NDB_LE_SendBytesStatistic) ->
    [
     {<<"to_node">>, integer, mandatory},
     {<<"mean_sent_bytes">>, integer, mandatory}
    ];
params(?NDB_LE_ReceiveBytesStatistic) ->
    [
     {<<"from_node">>, integer, mandatory},
     {<<"mean_received_bytes">>, integer, mandatory}
    ];
params(?NDB_LE_MemoryUsage) ->
    [
     {<<"gth">>, integer, mandatory},
     {<<"page_size_kb">>, integer, optional},
     {<<"page_size_bytes">>, integer, optional},
     {<<"page_used">>, integer, mandatory},
     {<<"page_total">>, integer, mandatory},
     {<<"block">>, integer, mandatory}
    ];
params(?NDB_LE_MTSignalStatistics) ->
    [
     {<<"thr_no">>, integer, mandatory},
     {<<"prioa_count">>, integer, mandatory},
     {<<"prioa_size">>, integer, mandatory},
     {<<"priob_count">>, integer, mandatory},
     {<<"priob_size">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_SCHEMA
%%
params(?NDB_LE_CreateSchemaObject) ->
    [
     {<<"objectid">>, integer, mandatory},
     {<<"version">>, integer, mandatory},
     {<<"type">>, integer, mandatory},
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_AlterSchemaObject) ->
    [
     {<<"objectid">>, integer, mandatory},
     {<<"version">>, integer, mandatory},
     {<<"type">>, integer, mandatory},
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_DropSchemaObject) ->
    [
     {<<"objectid">>, integer, mandatory},
     {<<"version">>, integer, mandatory},
     {<<"type">>, integer, mandatory},
     {<<"node">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_ERROR
%%
params(?NDB_LE_TransporterError) ->
    [
     {<<"to_node">>, integer, mandatory},
     {<<"code">>, integer, mandatory}
    ];
params(?NDB_LE_TransporterWarning) ->
    [
     {<<"to_node">>, integer, mandatory},
     {<<"code">>, integer, mandatory}
    ];
params(?NDB_LE_MissedHeartbeat) ->
    [
     {<<"node">>, integer, mandatory},
     {<<"count">>, integer, mandatory}
    ];
params(?NDB_LE_DeadDueToHeartbeat) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_WarningEvent) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_SubscriptionStatus) ->
    [
     {<<"report_type">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_INFO
%%
params(?NDB_LE_SentHeartbeat) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_CreateLogBytes) ->
    [
     {<<"node">>, integer, mandatory}
    ];
params(?NDB_LE_InfoEvent) ->
    [
     {<<"_unused">>, integer, optional},
     {<<"data">>, string, optional}
    ];
params(?NDB_LE_EventBufferStatus) ->
    [
     {<<"usage">>, integer, mandatory},
     {<<"alloc">>, integer, mandatory},
     {<<"max">>, integer, mandatory},
     {<<"apply_gci_l">>, integer, mandatory},
     {<<"apply_gci_h">>, integer, mandatory},
     {<<"latest_gci_l">>, integer, mandatory},
     {<<"latest_gci_h">>, integer, mandatory}
    ];
params(?NDB_LE_EventBufferStatus2) ->
    [
     {<<"usage">>, integer, mandatory},
     {<<"alloc">>, integer, mandatory},
     {<<"max">>, integer, mandatory},
     {<<"latest_consumed_epoch_l">>, integer, mandatory},
     {<<"latest_consumed_epoch_h">>, integer, mandatory},
     {<<"latest_buffered_epoch_l">>, integer, mandatory},
     {<<"latest_buffered_epoch_h">>, integer, mandatory},
     {<<"ndb_reference">>, integer, mandatory},
     {<<"report_reason">>, integer, mandatory}
    ];
%%
%% ?
%%
params(?NDB_LE_SingleUser) ->
    [
     {<<"type">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory}
    ];
%%
%% NDB_MGM_EVENT_CATEGORY_BACKUP
%%
params(?NDB_LE_BackupStarted) ->
    [
     {<<"starting_node">>, integer, mandatory},
     {<<"backup_id">>, integer, mandatory}
    ];
params(?NDB_LE_BackupStatus) ->
    [
     {<<"starting_node">>, integer, mandatory},
     {<<"backup_id">>, integer, mandatory},
     {<<"n_records_lo">>, integer, mandatory},
     {<<"n_records_hi">>, integer, mandatory},
     {<<"n_log_records_lo">>, integer, mandatory},
     {<<"n_log_records_hi">>, integer, mandatory},
     {<<"n_bytes_lo">>, integer, mandatory},
     {<<"n_bytes_hi">>, integer, mandatory},
     {<<"n_log_bytes_lo">>, integer, mandatory},
     {<<"n_log_bytes_hi">>, integer, mandatory}
    ];
params(?NDB_LE_BackupCompleted) ->
    [
     {<<"starting_node">>, integer, mandatory},
     {<<"backup_id">>, integer, mandatory},
     {<<"start_gci">>, integer, mandatory},
     {<<"stop_gci">>, integer, mandatory},
     {<<"n_records">>, integer, mandatory},
     {<<"n_log_records">>, integer, mandatory},
     {<<"n_bytes">>, integer, mandatory},
     {<<"n_log_bytes">>, integer, mandatory},
     {<<"n_records_hi">>, integer, mandatory},
     {<<"n_log_records_hi">>, integer, mandatory},
     {<<"n_bytes_hi">>, integer, mandatory},
     {<<"n_log_bytes_hi">>, integer, mandatory}
    ];
params(?NDB_LE_BackupFailedToStart) ->
    [
     {<<"starting_node">>, integer, mandatory},
     {<<"error">>, integer, mandatory}
    ];
params(?NDB_LE_BackupAborted) ->
    [
     {<<"starting_node">>, integer, mandatory},
     {<<"backup_id">>, integer, mandatory},
     {<<"error">>, integer, mandatory}
    ];
params(?NDB_LE_RestoreStarted) ->
    [
     {<<"backup_id">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory}
    ];
params(?NDB_LE_RestoreMetaData) ->
    [
     {<<"backup_id">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory},
     {<<"n_tables">>, integer, mandatory},
     {<<"n_tablespaces">>, integer, mandatory},
     {<<"n_logfilegroups">>, integer, mandatory},
     {<<"n_datafiles">>, integer, mandatory},
     {<<"n_undofiles">>, integer, mandatory}
    ];
params(?NDB_LE_RestoreData) ->
    [
     {<<"backup_id">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory},
     {<<"n_records_lo">>, integer, mandatory},
     {<<"n_records_hi">>, integer, mandatory},
     {<<"n_bytes_lo">>, integer, mandatory},
     {<<"n_bytes_hi">>, integer, mandatory}
    ];
params(?NDB_LE_RestoreLog) ->
    [
     {<<"backup_id">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory},
     {<<"n_records_lo">>, integer, mandatory},
     {<<"n_records_hi">>, integer, mandatory},
     {<<"n_bytes_lo">>, integer, mandatory},
     {<<"n_bytes_hi">>, integer, mandatory}
    ];
params(?NDB_LE_RestoreCompleted) ->
    [
     {<<"backup_id">>, integer, mandatory},
     {<<"node_id">>, integer, mandatory}
    ];
params(?NDB_LE_SavedEvent) ->
    [
     {<<"len">>, integer, mandatory},
     {<<"seq">>, integer, mandatory},
     {<<"time">>, integer, mandatory},
     {<<"data">>, string, mandatory}
    ];
%%
%% (undocumented)
%%
params(?NDB_LE_LCPRestored) ->
    [
     {<<"restored_lcp_id">>, integer, mandatory}
    ].
%%
%% NDB_MGM_EVENT_CATEGORY_CONGESTION
%% NDB_MGM_EVENT_CATEGORY_DEBUG
%% NDB_MGM_EVENT_CATEGORY_WARNING
%% NDB_MGM_EVENT_CATEGORY_SHUTDOWN
%%
