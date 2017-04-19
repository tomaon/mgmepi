-module(mgmepi_config).

-include("internal.hrl").

-import(mgmepi_client, [call/5, recv/2]).
-import(mgmepi_util, [get_result/2]).

%% -- public --

-export([get_config/1, get_config/2]).
-export([get_connection_config/2, debug_connection_config/2]).
-export([get_node_config/2, debug_node_config/2]).
-export([get_nodes_config/2, debug_nodes_config/2]).
-export([get_system_config/1, debug_system_config/1]).

%% -- internal --

%% -- ~/include/util/ConfigValues.hpp --

%% enum: ConfigValues::ValueType
-define(VALUETYPE_INT,     1).
-define(VALUETYPE_STRING,  2).
-define(VALUETYPE_SECTION, 3).
-define(VALUETYPE_INT64,   4).

%% -- ~/src/common/util/ConfigValues.cpp --

-define(CFG_TYPE_OF_SECTION,     999).
-define(CFG_SECTION_SYSTEM,     1000).
-define(CFG_SECTION_NODE,       2000).
-define(CFG_SECTION_CONNECTION, 3000).

-define(NODE_TYPE_DB,  ?NDB_MGM_NODE_TYPE_NDB).
-define(NODE_TYPE_API, ?NDB_MGM_NODE_TYPE_API).
-define(NODE_TYPE_MGM, ?NDB_MGM_NODE_TYPE_MGM).

-define(CONNECTION_TYPE_TCP, 0).

-define(KEYVAL(I),  (I band 16#00003FFF)).          % KP_KEYVAL_(MASK|SHIFT)
-define(SECTION(I), (I band (16#00003FFF bsl 14))). % KP_SECTION_(MASK|SHIFT)
-define(TYPE(I),    ((I bsr 28) band 16#0000000F)). % KP_TYPE_(MASK|SHIFT)

-define(CFV_KEY_PARENT, 16#3ffe). % KP_KEYVAL_MASK - 1

%% == public ==

-spec get_config(mgmepi()) -> {ok, config()}|{error, _}.
get_config(#mgmepi{timeout=T}=H) ->
    get_config(H, T).

-spec get_config(mgmepi(), timeout()) -> {ok, config()}|{error, _}.
get_config(#mgmepi{worker=W}, Timeout) ->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_get_configuration/2
    %%                          ndb_mgm_get_configuration2/4
    %%
    case call(W,
              <<"get config">>,
              [
               {<<"version">>, integer_to_binary(?NDB_VERSION_ID)},
               {<<"nodetype">>, integer_to_binary(?NDB_MGM_NODE_TYPE_UNKNOWN)}
              ],
              [
               {<<"get config reply">>, null, mandatory},
               {<<"result">>, string, mandatory},
               {<<"Content-Length">>, integer, optional},
               {<<"Content-Type">>, <<"ndbconfig/octet-stream">>, optional},
               {<<"Content-Transfer-Encoding">>, <<"base64">>, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            {ok, Size} = get_result(List, <<"Content-Length">>),
            case get_content(W, Size + 1) of % + end_of_protocol
                {ok, Binary} ->
                    {ok, unpack(base64:decode(Binary))}; % ignore LS
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.


-spec get_connection_config(config(), integer()) -> [config()]. % config()
get_connection_config(Config, NodeId)
  when ?IS_CONFIG(Config), ?IS_NODE_ID(NodeId) ->
    F = fun (L) ->
                get_connection_config(L,
                                      lists:member({?CFG_CONNECTION_NODE_1, NodeId}, L),
                                      lists:member({?CFG_CONNECTION_NODE_2, NodeId}, L))
        end,
    lists:filtermap(F, find(Config, [0, ?CFG_SECTION_CONNECTION])).

-spec debug_connection_config(config(), node_id()) -> [config()]. % config()
debug_connection_config(Config, NodeId) ->
    [ combine(E, ?CFG_SECTION_CONNECTION) || E <- get_connection_config(Config, NodeId) ].


-spec get_node_config(config(), integer()) -> [config()]. % config()
get_node_config(Config, NodeId)
  when ?IS_CONFIG(Config), ?IS_NODE_ID(NodeId) ->
    F = fun (L) ->
                lists:member({?CFG_NODE_ID, NodeId}, L)
        end,
    lists:filter(F, find(Config, [0, ?CFG_SECTION_NODE])).

-spec debug_node_config(config(), node_id()) -> [config()]. % config()
debug_node_config(Config, NodeId) ->
    [ combine(E, ?CFG_SECTION_NODE) || E <- get_node_config(Config, NodeId) ].


-spec get_nodes_config(config(), node_type()) -> [config()]. % config()
get_nodes_config(Config, Type)
  when ?IS_CONFIG(Config), ?IS_NODE_TYPE(Type) ->
    F = fun (L) ->
                lists:member({?CFG_TYPE_OF_SECTION, Type}, L)
        end,
    lists:filter(F, find(Config, [0, ?CFG_SECTION_NODE])).

-spec debug_nodes_config(config(), node_type()) -> [config()]. % config()
debug_nodes_config(Config, Type) ->
    [ combine(E, ?CFG_SECTION_NODE) || E <- get_nodes_config(Config, Type) ].


-spec get_system_config(config()) -> [config()]. % config()
get_system_config(Config)
  when ?IS_CONFIG(Config) ->
    find(Config, [0, ?CFG_SECTION_SYSTEM]).

-spec debug_system_config(config()) -> [config()]. % config()
debug_system_config(Config) ->
    [ combine(E, ?CFG_SECTION_SYSTEM) || E <- get_system_config(Config) ].

%% == internal ==

combine(List, Section) ->
    case lists:keyfind(?CFG_TYPE_OF_SECTION, 1, List) of
        {_, Type} ->
            baseline_lists:combine(List, names(Section, Type),
                                   [?CFG_TYPE_OF_SECTION, ?CFV_KEY_PARENT])
    end.

find(Config, List) ->
    find(Config, Config, List).

find(Config, Key, []) ->
    case lists:keyfind(Key, 1, Config) of
        {Key, List} ->
            [ baseline_lists:get_value(N, Config) || {_, N} <- List ]
    end;
find(Config, List, [H|T]) ->
    case lists:keyfind(H, 1, List) of
        {H, L} ->
            find(Config, L, T)
    end.

get_connection_config(_Config, false, false) ->
    false;
get_connection_config(_Config, true, false) ->
    true;
get_connection_config(Config, false, true) ->
    {true, lists:map(fun ({?CFG_CONNECTION_NODE_1,     V}) -> {?CFG_CONNECTION_NODE_2,     V};
                         ({?CFG_CONNECTION_NODE_2,     V}) -> {?CFG_CONNECTION_NODE_1,     V};
                         ({?CFG_CONNECTION_HOSTNAME_1, V}) -> {?CFG_CONNECTION_HOSTNAME_2, V};
                         ({?CFG_CONNECTION_HOSTNAME_2, V}) -> {?CFG_CONNECTION_HOSTNAME_1, V};
                         (Other)                           -> Other
                     end, Config)}.

get_content(Pid, Length) ->
    receive
        {_, Binary} when size(Binary) + 2 =:= Length -> % socket.buffer >= Length
            {ok, Binary};
        _ ->
            {error, eio}
    after
        0 ->
            recv(Pid, Length)
    end.

unpack(Binary) ->
    %%
    %% ~/src/common/util/ConfigValues.cpp: ConfigValuesFactory::unpack/2
    %%
    unpack(Binary, byte_size(Binary)).

unpack(Binary, Size) -> % 12 =< Size, 0 == Size rem 4
    C = baseline_binary:decode_unsigned(Binary, Size - 4, 4, native),
    case {binary_part(Binary, 0, 8), mgmepi_util:checksum(Binary, 0, Size - 4, 4, native)} of
        {<<"NDBCONFV">>, C}->
            unpack(Binary, 8, Size - 12, 0, [], [])
    end.

unpack(Binary, Start, Length) ->
    {I, IS} = unpack_integer(Binary, Start),
    {V, VS} = unpack_value(?TYPE(I), Binary, IS),
    {
      VS,
      Length - (VS - Start),
      {?SECTION(I), ?KEYVAL(I), V}
    }.

unpack(_Binary, _Start, 0, Section, L1, L2) ->
    [{Section, L2}|L1];
unpack(Binary, Start, Length, Section, L1, L2) ->
    {S, L, T} = unpack(Binary, Start, Length),
    unpack(Binary, S, L, Section, T, L1, L2).

unpack(Binary, Start, Length, S, {S, K, V}, L1, L2) ->
    unpack(Binary, Start, Length, S, L1, [{K, V}|L2]);
unpack(Binary, Start, Length, P, {N, K, V}, L1, L2) ->
    unpack(Binary, Start, Length, N, [{P, L2}|L1], [{K, V}]).

unpack_binary(Binary, Start) ->
    {L, S} = unpack_integer(Binary, Start),
    N = 4 * ((L + 3) div 4),                % right-aligned
    {binary_part(Binary, S, L - 1), S + N}. % ignore '\0'

unpack_integer(Binary, Start) ->
    <<I:4/integer-signed-big-unit:8>> = binary_part(Binary, Start, 4),
    {I, Start + 4}.

unpack_long(Binary, Start) ->
    {H, HS} = unpack_integer(Binary, Start),
    {L, LS} = unpack_integer(Binary, HS),
    {(H bsl 32) bor L, LS}.

unpack_value(?VALUETYPE_INT, Binary, Start) ->
    unpack_integer(Binary, Start);
unpack_value(?VALUETYPE_STRING, Binary, Start) ->
    unpack_binary(Binary, Start);
unpack_value(?VALUETYPE_INT64, Binary, Start) ->
    unpack_long(Binary, Start);
unpack_value(?VALUETYPE_SECTION, Binary, Start) ->
    unpack_integer(Binary, Start).

%%
%% ~/src/mgmsrv/ConfigInfo.cpp
%%
names(?CFG_SECTION_SYSTEM, ?CFG_SECTION_SYSTEM) ->
    [
     {?CFG_SYS_NAME, <<"Name">>},
     {?CFG_SYS_PRIMARY_MGM_NODE, <<"PrimaryMGMNode">>},
     {?CFG_SYS_CONFIG_GENERATION, <<"ConfigGenerationNumber">>}
    ];
names(?CFG_SECTION_NODE, ?NODE_TYPE_MGM) ->
    %%
    %% https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster-mgm-definition.html
    %%
    [
     {?CFG_NODE_ID, <<"NodeId">>},
     %%{-1, <<"ExecuteOnComputer">>},
     {?CFG_MGM_PORT, <<"PortNumber">>},
     {?CFG_NODE_HOST, <<"HostName">>},
     {?CFG_LOG_DESTINATION, <<"LogDestination">>},
     {?CFG_NODE_ARBIT_RANK, <<"ArbitrationRank">>},
     {?CFG_NODE_ARBIT_DELAY, <<"ArbitrationDelay">>},
     {?CFG_NODE_DATADIR, <<"DataDir">>},
     %%{-1, <<"PortNumberStats">>},
     %%{-1, <<"Wan">>},
     {?CFG_HB_THREAD_PRIO, <<"HeartbeatThreadPriority">>},
     {?CFG_TOTAL_SEND_BUFFER_MEMORY, <<"TotalSendBufferMemory">>},
     {?CFG_MGMD_MGMD_HEARTBEAT_INTERVAL, <<"HeartbeatIntervalMgmdMgmd">>},
     %% -- ? --
     %%{-1, <<"MaxNoOfSavedEvents">>},
     {?CFG_EXTRA_SEND_BUFFER_MEMORY, <<"ExtraSendBufferMemory">>},
     {?CFG_MIXOLOGY_LEVEL, <<"__debug_mixology_level">>},
     {?CFG_DB_DISK_PAGE_BUFFER_ENTRIES,  <<"DiskPageBufferEntries">>}
    ];
names(?CFG_SECTION_NODE, ?NODE_TYPE_DB) ->
    %%
    %% https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster-ndbd-definition.html
    %%
    [
     %% -- "Identifying data nodes" --
     {?CFG_NODE_ID, <<"NodeId">>},
     {?CFG_NODE_HOST, <<"HostName">>},
     {?CFG_DB_SERVER_PORT, <<"ServerPort">>},
     {?CFG_DB_TCPBIND_INADDR_ANY, <<"TcpBind_INADDR_ANY">>},
     {?CFG_DB_NODEGROUP, <<"NodeGroup">>},
     {?CFG_DB_NO_REPLICAS, <<"NoOfReplicas">>},
     {?CFG_NODE_DATADIR, <<"DataDir">>},
     {?CFG_DB_FILESYSTEM_PATH, <<"FileSystemPath">>},
     {?CFG_DB_BACKUP_DATADIR, <<"BackupDataDir">>},
     %% -- "Data Memory, Index Memory, and String Memory" --
     {?CFG_DB_DATA_MEM, <<"DataMemory">>},
     {?CFG_DB_INDEX_MEM, <<"IndexMemory">>},
     {?CFG_DB_STRING_MEMORY, <<"StringMemory">>},
     {?CFG_DB_FREE_PCT, <<"MinFreePct">>},
     %% -- "Transaction parameters" --
     {?CFG_DB_NO_TRANSACTIONS, <<"MaxNoOfConcurrentTransactions">>},
     {?CFG_DB_NO_OPS, <<"MaxNoOfConcurrentOperations">>},
     {?CFG_DB_NO_LOCAL_OPS, <<"MaxNoOfLocalOperations">>},
     {?CFG_DB_MAX_DML_OPERATIONS_PER_TRANSACTION, <<"MaxDMLOperationsPerTransaction">>},
     %% -- "Transaction temporary storage" --
     {?CFG_DB_NO_INDEX_OPS, <<"MaxNoOfConcurrentIndexOperations">>},
     {?CFG_DB_NO_TRIGGER_OPS, <<"MaxNoOfFiredTriggers">>},
     {?CFG_DB_TRANS_BUFFER_MEM, <<"TransactionBufferMemory">>},
     %% -- "Scans and buffering" --
     {?CFG_DB_NO_SCANS, <<"MaxNoOfConcurrentScans">>},
     {?CFG_DB_NO_LOCAL_SCANS, <<"MaxNoOfLocalScans">>},
     {?CFG_DB_BATCH_SIZE, <<"BatchSizePerLocalScan">>},
     {?CFG_DB_LONG_SIGNAL_BUFFER, <<"LongMessageBuffer">>},
     {?CFG_DB_PARALLEL_COPY_THREADS, <<"MaxParallelCopyInstances">>},
     {?CFG_DB_PARALLEL_SCANS_PER_FRAG, <<"MaxParallelScansPerFragment">>},
     %% -- "Memory Allocation" --
     {?CFG_DB_MAX_ALLOCATE, <<"MaxAllocate">>},
     %% -- "Hash Map Size" --
     {?CFG_DEFAULT_HASHMAP_SIZE, <<"DefaultHashMapSize">>},
     %% -- "Logging and checkpointing" --
     {?CFG_DB_NO_REDOLOG_FILES, <<"NoOfFragmentLogFiles">>},
     {?CFG_DB_REDOLOG_FILE_SIZE, <<"FragmentLogFileSize">>},
     {?CFG_DB_INIT_REDO, <<"InitFragmentLogFiles">>},
     {?CFG_DB_MAX_OPEN_FILES, <<"MaxNoOfOpenFiles">>},
     {?CFG_DB_INITIAL_OPEN_FILES, <<"InitialNoOfOpenFiles">>},
     {?CFG_DB_NO_SAVE_MSGS, <<"MaxNoOfSavedMessages">>},
     {?CFG_DB_LCP_TRY_LOCK_TIMEOUT, <<"MaxLCPStartDelay">>},
     {?CFG_DB_LCP_SCAN_WATCHDOG_LIMIT, <<"LcpScanProgressTimeout">>},
     %% -- "Metadata objects" --
     {?CFG_DB_NO_ATTRIBUTES, <<"MaxNoOfAttributes">>},
     {?CFG_DB_NO_TABLES, <<"MaxNoOfTables">>},
     {?CFG_DB_NO_ORDERED_INDEXES, <<"MaxNoOfOrderedIndexes">>},
     {?CFG_DB_NO_UNIQUE_HASH_INDEXES, <<"MaxNoOfUniqueHashIndexes">>},
     {?CFG_DB_NO_TRIGGERS, <<"MaxNoOfTriggers">>},
     {?CFG_DB_NO_INDEXES, <<"MaxNoOfIndexes">>}, % deprecated
     {?CFG_DB_SUBSCRIPTIONS, <<"MaxNoOfSubscriptions">>},
     {?CFG_DB_SUBSCRIBERS, <<"MaxNoOfSubscribers">>},
     {?CFG_DB_SUB_OPERATIONS, <<"MaxNoOfConcurrentSubOperations">>},
     %% -- "Boolean parameters" --
     {?CFG_DB_LATE_ALLOC, <<"LateAlloc">>},
     {?CFG_DB_MEMLOCK, <<"LockPagesInMainMemory">>},
     {?CFG_DB_STOP_ON_ERROR, <<"StopOnError">>},
     {?CFG_DB_CRASH_ON_CORRUPTED_TUPLE, <<"CrashOnCorruptedTuple">>},
     {?CFG_DB_DISCLESS, <<"Diskless">>},
     {?CFG_DB_O_DIRECT, <<"ODirect">>},
     {?CFG_DB_STOP_ON_ERROR_INSERT, <<"RestartOnErrorInsert">>},
     {?CFG_DB_COMPRESSED_BACKUP, <<"CompressedBackup">>},
     {?CFG_DB_COMPRESSED_LCP, <<"CompressedLCP">>},
     %% -- "Controlling Timeouts, Intervals, and Disk Paging" --
     {?CFG_DB_WATCHDOG_INTERVAL, <<"TimeBetweenWatchDogCheck">>},
     {?CFG_DB_WATCHDOG_INTERVAL_INITIAL, <<"TimeBetweenWatchDogCheckInitial">>},
     {?CFG_DB_START_PARTIAL_TIMEOUT, <<"StartPartialTimeout">>},
     {?CFG_DB_START_PARTITION_TIMEOUT, <<"StartPartitionedTimeout">>},
     {?CFG_DB_START_FAILURE_TIMEOUT, <<"StartFailureTimeout">>},
     {?CFG_DB_START_NO_NODEGROUP_TIMEOUT, <<"StartNoNodeGroupTimeout">>},
     {?CFG_DB_HEARTBEAT_INTERVAL, <<"HeartbeatIntervalDbDb">>},
     {?CFG_DB_API_HEARTBEAT_INTERVAL, <<"HeartbeatIntervalDbApi">>},
     {?CFG_DB_HB_ORDER, <<"HeartbeatOrder">>},
     {?CFG_DB_CONNECT_CHECK_DELAY, <<"ConnectCheckIntervalDelay">>},
     {?CFG_DB_LCP_INTERVAL, <<"TimeBetweenLocalCheckpoints">>},
     {?CFG_DB_GCP_INTERVAL, <<"TimeBetweenGlobalCheckpoints">>},
     {?CFG_DB_GCP_TIMEOUT, <<"TimeBetweenGlobalCheckpointsTimeout">>},
     {?CFG_DB_MICRO_GCP_INTERVAL, <<"TimeBetweenEpochs">>},
     {?CFG_DB_MICRO_GCP_TIMEOUT, <<"TimeBetweenEpochsTimeout">>},
     {?CFG_DB_MAX_BUFFERED_EPOCHS, <<"MaxBufferedEpochs">>},
     {?CFG_DB_MAX_BUFFERED_EPOCH_BYTES, <<"MaxBufferedEpochBytes">>},
     {?CFG_DB_TRANSACTION_CHECK_INTERVAL, <<"TimeBetweenInactiveTransactionAbortCheck">>},
     {?CFG_DB_TRANSACTION_INACTIVE_TIMEOUT, <<"TransactionInactiveTimeout">>},
     {?CFG_DB_TRANSACTION_DEADLOCK_TIMEOUT, <<"TransactionDeadlockDetectionTimeout">>},
     {?CFG_DB_DISK_SYNCH_SIZE, <<"DiskSyncSize">>},
     {?CFG_DB_CHECKPOINT_SPEED, <<"DiskCheckpointSpeed">>}, % deprecated
     {?CFG_DB_CHECKPOINT_SPEED_RESTART, <<"DiskCheckpointSpeedInRestart">>}, % deprecated
     {?CFG_DB_LCP_DISC_PAGES_TUP, <<"NoOfDiskPagesToDiskAfterRestartTUP">>}, % deprecated
     {?CFG_DB_MAX_DISK_WRITE_SPEED, <<"MaxDiskWriteSpeed">>},
     {?CFG_DB_MAX_DISK_WRITE_SPEED_OTHER_NODE_RESTART, <<"MaxDiskWriteSpeedOtherNodeRestart">>},
     {?CFG_DB_MAX_DISK_WRITE_SPEED_OWN_RESTART, <<"MaxDiskWriteSpeedOwnRestart">>},
     {?CFG_DB_MIN_DISK_WRITE_SPEED, <<"MinDiskWriteSpeed">>},
     {?CFG_DB_LCP_DISC_PAGES_ACC, <<"NoOfDiskPagesToDiskAfterRestartACC">>}, % deprecated
     {?CFG_DB_LCP_DISC_PAGES_TUP_SR, <<"NoOfDiskPagesToDiskDuringRestartTUP">>}, % deprecated
     {?CFG_DB_LCP_DISC_PAGES_ACC_SR, <<"NoOfDiskPagesToDiskDuringRestartACC">>}, % deprecated
     {?CFG_DB_ARBIT_TIMEOUT, <<"ArbitrationTimeout">>},
     {?CFG_DB_ARBIT_METHOD, <<"Arbitration">>},
     {?CFG_DB_AT_RESTART_SUBSCRIBER_CONNECT_TIMEOUT,  <<"RestartSubscriberConnectTimeout">>},
     %% -- "Buffering and logging" --
     {?CFG_DB_UNDO_INDEX_BUFFER, <<"UndoIndexBuffer">>},
     {?CFG_DB_UNDO_DATA_BUFFER, <<"UndoDataBuffer">>},
     {?CFG_DB_REDO_BUFFER, <<"RedoBuffer">>},
     {?CFG_DB_EVENTLOG_BUFFER_SIZE, <<"EventLogBufferSize">>},
     %% -- "Controlling log messages" --
     {?CFG_LOGLEVEL_STARTUP, <<"LogLevelStartup">>},
     {?CFG_LOGLEVEL_SHUTDOWN, <<"LogLevelShutdown">>},
     {?CFG_LOGLEVEL_STATISTICS, <<"LogLevelStatistic">>},
     {?CFG_LOGLEVEL_CHECKPOINT, <<"LogLevelCheckpoint">>},
     {?CFG_LOGLEVEL_NODERESTART, <<"LogLevelNodeRestart">>},
     {?CFG_LOGLEVEL_CONNECTION, <<"LogLevelConnection">>},
     {?CFG_LOGLEVEL_ERROR, <<"LogLevelError">>},
     {?CFG_LOGLEVEL_CONGESTION, <<"LogLevelCongestion">>},
     {?CFG_LOGLEVEL_INFO, <<"LogLevelInfo">>},
     {?CFG_DB_MEMREPORT_FREQUENCY, <<"MemReportFrequency">>},
     {?CFG_DB_STARTUP_REPORT_FREQUENCY, <<"StartupStatusReportFrequency">>},
     %% -- "Debugging Parameters" --
     {?CFG_DB_DICT_TRACE, <<"DictTrace">>},
     %% -- "Backup parameters" --
     {?CFG_DB_BACKUP_DATA_BUFFER_MEM, <<"BackupDataBufferSize">>},
     {?CFG_DB_BACKUP_DISK_WRITE_PCT, <<"BackupDiskWriteSpeedPct">>},
     {?CFG_DB_BACKUP_LOG_BUFFER_MEM, <<"BackupLogBufferSize">>},
     {?CFG_DB_BACKUP_MEM, <<"BackupMemory">>},
     {?CFG_DB_BACKUP_REPORT_FREQUENCY, <<"BackupReportFrequency">>},
     {?CFG_DB_BACKUP_WRITE_SIZE, <<"BackupWriteSize">>},
     {?CFG_DB_BACKUP_MAX_WRITE_SIZE, <<"BackupMaxWriteSize">>},
     %% -- "MySQL Cluster Realtime Performance Parameters" --
     {?CFG_DB_EXECUTE_LOCK_CPU, <<"LockExecuteThreadToCPU">>},
     {?CFG_DB_MAINT_LOCK_CPU, <<"LockMaintThreadsToCPU">>},
     {?CFG_DB_REALTIME_SCHEDULER, <<"RealtimeScheduler">>},
     {?CFG_DB_SCHED_EXEC_TIME, <<"SchedulerExecutionTimer">>},
     {?CFG_DB_SCHED_RESPONSIVENESS, <<"SchedulerResponsiveness">>},
     {?CFG_DB_SCHED_SPIN_TIME, <<"SchedulerSpinTimer">>},
     {?CFG_DB_MT_BUILD_INDEX, <<"BuildIndexThreads">>},
     {?CFG_DB_2PASS_INR, <<"TwoPassInitialNodeRestartCopy">>},
     {?CFG_DB_NUMA, <<"Numa">>},
     %% -- "Multi-Threading Configuration Parameters (ndbmtd)" --
     {?CFG_DB_MT_THREADS, <<"MaxNoOfExecutionThreads">>},
     {?CFG_DB_NO_REDOLOG_PARTS, <<"NoOfFragmentLogParts">>},
     {?CFG_DB_MT_THREAD_CONFIG, <<"ThreadConfig">>},
     %% -- "Disk Data Configuration Parameters" --
     {?CFG_DB_DISK_PAGE_BUFFER_ENTRIES, <<"DiskPageBufferEntries">>},
     {?CFG_DB_DISK_PAGE_BUFFER_MEMORY, <<"DiskPageBufferMemory">>},
     {?CFG_DB_SGA, <<"SharedGlobalMemory">>},
     {?CFG_DB_THREAD_POOL, <<"DiskIOThreadPool">>},
     %% -- "Disk Data file system parameters" --
     {?CFG_DB_DD_FILESYSTEM_PATH, <<"FileSystemPathDD">>},
     {?CFG_DB_DD_DATAFILE_PATH, <<"FileSystemPathDataFiles">>},
     {?CFG_DB_DD_UNDOFILE_PATH, <<"FileSystemPathUndoFiles">>},
     %% -- "Disk Data object creation parameters" --
     {?CFG_DB_DD_LOGFILEGROUP_SPEC, <<"InitialLogFileGroup">>},
     {?CFG_DB_DD_TABLEPACE_SPEC, <<"InitialTablespace">>},
     %% -- "Parameters for configuring send buffer memory allocation" --
     {?CFG_EXTRA_SEND_BUFFER_MEMORY, <<"ExtraSendBufferMemory">>},
     {?CFG_TOTAL_SEND_BUFFER_MEMORY, <<"TotalSendBufferMemory">>},
     {?CFG_RESERVED_SEND_BUFFER_MEMORY, <<"ReservedSendBufferMemory">>}, % deprecated
     %% -- "Redo log over-commit handling" --
     {?CFG_DB_REDO_OVERCOMMIT_COUNTER, <<"RedoOverCommitCounter">>},
     {?CFG_DB_REDO_OVERCOMMIT_LIMIT, <<"RedoOverCommitLimit">>},
     %% -- "Controlling restart attempts" --
     {?CFG_DB_START_FAIL_DELAY_SECS, <<"StartFailRetryDelay">>},
     {?CFG_DB_MAX_START_FAIL, <<"MaxStartFailRetries">>},
     %% -- "NDB index statistics parameters" --
     {?CFG_DB_INDEX_STAT_AUTO_CREATE, <<"IndexStatAutoCreate">>},
     {?CFG_DB_INDEX_STAT_AUTO_UPDATE, <<"IndexStatAutoUpdate">>},
     {?CFG_DB_INDEX_STAT_SAVE_SIZE, <<"IndexStatSaveSize">>},
     {?CFG_DB_INDEX_STAT_SAVE_SCALE, <<"IndexStatSaveScale">>},
     {?CFG_DB_INDEX_STAT_TRIGGER_PCT, <<"IndexStatTriggerPct">>},
     {?CFG_DB_INDEX_STAT_TRIGGER_SCALE, <<"IndexStatTriggerScale">>},
     {?CFG_DB_INDEX_STAT_UPDATE_DELAY, <<"IndexStatUpdateDelay">>},
     %% -- ? --
     {?CFG_DB_MAX_SEND_DELAY, <<"MaxSendDelay">>},
     {?CFG_DB_PARALLEL_BACKUPS, <<"ParallelBackups">>},
     {?CFG_NDBMT_LQH_WORKERS, <<"__ndbmt_lqh_workers">>},
     {?CFG_NDBMT_LQH_THREADS, <<"__ndbmt_lqh_threads">>},
     {?CFG_NDBMT_CLASSIC, <<"__ndbmt_classic">>},
     {?CFG_DB_AT_RESTART_SKIP_INDEXES, <<"__at_restart_skip_indexes">>},
     {?CFG_DB_AT_RESTART_SKIP_FKS, <<"__at_restart_skip_fks">>},
     {?CFG_MIXOLOGY_LEVEL, <<"__debug_mixology_level">>},
     {?CFG_DB_SCHED_SCAN_PRIORITY, <<"__sched_scan_priority">>}
    ];
names(?CFG_SECTION_NODE, ?NODE_TYPE_API) ->
    %%
    %% https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster-api-definition.html
    %%
    [
     %%{-1, <<"ConnectionMap">>},
     {?CFG_NODE_ID, <<"NodeId">>},
     %%{-1, <<"ExecuteOnComputer">>},
     {?CFG_NODE_HOST, <<"HostName">>},
     {?CFG_NODE_ARBIT_RANK, <<"ArbitrationRank">>},
     {?CFG_NODE_ARBIT_DELAY, <<"ArbitrationDelay">>},
     {?CFG_BATCH_BYTE_SIZE, <<"BatchByteSize">>},
     {?CFG_BATCH_SIZE, <<"BatchSize">>},
     {?CFG_EXTRA_SEND_BUFFER_MEMORY, <<"ExtraSendBufferMemory">>},
     {?CFG_HB_THREAD_PRIO, <<"HeartbeatThreadPriority">>},
     {?CFG_MAX_SCAN_BATCH_SIZE, <<"MaxScanBatchSize">>},
     {?CFG_TOTAL_SEND_BUFFER_MEMORY, <<"TotalSendBufferMemory">>},
     {?CFG_AUTO_RECONNECT, <<"AutoReconnect">>},
     {?CFG_DEFAULT_OPERATION_REDO_PROBLEM_ACTION, <<"DefaultOperationRedoProblemAction">>},
     {?CFG_DEFAULT_HASHMAP_SIZE, <<"DefaultHashMapSize">>},
     %%{-1, <<"Wan">>},
     {?CFG_CONNECT_BACKOFF_MAX_TIME, <<"ConnectBackoffMaxTime">>},
     {?CFG_START_CONNECT_BACKOFF_MAX_TIME, <<"StartConnectBackoffMaxTime">>},
     %% -- ? --
     {?CFG_MIXOLOGY_LEVEL, <<"__debug_mixology_level">>},
     {?CFG_API_VERBOSE, <<"ApiVerbose">>}
    ];
names(?CFG_SECTION_CONNECTION, ?CONNECTION_TYPE_TCP) ->
    %%
    %% https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster-tcp-definition.html
    %%
    [
     {?CFG_CONNECTION_NODE_1, <<"NodeId1">>},
     {?CFG_CONNECTION_NODE_2, <<"NodeId2">>},
     {?CFG_CONNECTION_HOSTNAME_1, <<"HostName1">>},
     {?CFG_CONNECTION_HOSTNAME_2, <<"HostName2">>},
     {?CFG_CONNECTION_OVERLOAD, <<"OverloadLimit">>},
     {?CFG_TCP_SEND_BUFFER_SIZE, <<"SendBufferMemory">>},
     {?CFG_CONNECTION_SEND_SIGNAL_ID, <<"SendSignalId">>},
     {?CFG_CONNECTION_CHECKSUM, <<"Checksum">>},
     {?CFG_CONNECTION_SERVER_PORT, <<"PortNumber">>}, % OBSOLETE
     {?CFG_TCP_RECEIVE_BUFFER_SIZE, <<"ReceiveBufferMemory">>},
     {?CFG_TCP_RCV_BUF_SIZE, <<"TCP_RCV_BUF_SIZE">>},
     {?CFG_TCP_SND_BUF_SIZE, <<"TCP_SND_BUF_SIZE">>},
     {?CFG_TCP_MAXSEG_SIZE, <<"TCP_MAXSEG_SIZE">>},
     {?CFG_TCP_BIND_INADDR_ANY, <<"TcpBind_INADDR_ANY">>},
     %% -- ? --
     {?CFG_CONNECTION_GROUP, <<"Group">>},
     {?CFG_CONNECTION_NODE_ID_SERVER, <<"NodeIdServer">>},
     {?CFG_TCP_PROXY, <<"Proxy">>}
    ].
