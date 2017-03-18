-module(mgmepi_backup).

-include("internal.hrl").

-import(mgmepi_client, [call/5]).
-import(mgmepi_util, [fold/2, get_result/1, get_result/2]).

%% -- public --
-export([start_backup/4, start_backup/5]).
-export([abort_backup/2, abort_backup/3]).

%% -- internal --
-define(IS_COMPLETED(T),    (is_integer(T) andalso (T >= 0) andalso (T =< 2))).
-define(IS_BACKUP_ID(T),    (is_integer(T) andalso (T >= 0))).
-define(IS_BACKUP_POINT(T), (is_integer(T) andalso (T >= 0))). % TODO

-type(completed()    :: 0 .. 2).
-type(backup_id()    :: non_neg_integer()).
-type(backup_point() :: non_neg_integer()).

%% completed
%%  0 : Do not wait for confirmation of the backup.
%%  1 : Wait for the backup to be started.
%%  2 : Wait for the backup to be completed.

%% == public ==

-spec start_backup(mgmepi(), completed(), backup_id(), backup_point()) ->
                          {ok, backup_id()}|{error, _}.
start_backup(Mgmepi, 2, BackupId, BackupPoint) ->
    start_backup(Mgmepi, 2, BackupId, BackupPoint, timer:hours(48));
start_backup(Mgmepi, 1, BackupId, BackupPoint) ->
    start_backup(Mgmepi, 1, BackupId, BackupPoint, timer:minutes(10));
start_backup(#mgmepi{timeout=T}=M, 0, BackupId, BackupPoint) ->
    start_backup(M, 0, BackupId, BackupPoint, T).

-spec start_backup(mgmepi(), completed(), backup_id(), backup_point(), timeout()) ->
                          {ok, backup_id()}|{error, _}.
start_backup(#mgmepi{worker=W}, Completed, BackupId, BackupPoint, Timeout)
  when ?IS_COMPLETED(Completed), ?IS_BACKUP_ID(BackupId),
       ?IS_BACKUP_POINT(BackupPoint), ?IS_TIMEOUT(Timeout)->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_start_backup3/6
    %%
    case call(W,
              <<"start backup">>,
              fold([
                    fun () ->
                            {<<"completed">>, integer_to_binary(Completed)}
                    end,
                    fun () when 0 < BackupId ->
                            {<<"backupid">>, integer_to_binary(BackupId)};
                        () ->
                            undefined
                    end,
                    fun () ->
                            {<<"backuppoint">>, integer_to_binary(BackupPoint)}
                    end
                   ], []),
              [
               {<<"start backup reply">>, null, mandatory},
               {<<"result">>, string, mandatory},
               {<<"id">>, integer, optional}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List, <<"id">>);
        {error, Reason} ->
            {error, Reason}
    end.


-spec abort_backup(mgmepi(), backup_id()) -> ok|{error, _}.
abort_backup(#mgmepi{timeout=T}=M, BackupId) ->
    abort_backup(M, BackupId, T).

-spec abort_backup(mgmepi(), backup_id(), timeout()) -> ok|{error, _}.
abort_backup(#mgmepi{worker=W}, BackupId, Timeout)
  when ?IS_BACKUP_ID(BackupId), ?IS_TIMEOUT(Timeout)->
    %%
    %% ~/src/mgmapi/mgmapi.cpp: ndb_mgm_abort_backup/3
    %%
    case call(W,
              <<"abort backup">>,
              [
               {<<"id">>, integer_to_binary(BackupId)}
              ],
              [
               {<<"abort backup reply">>, null, mandatory},
               {<<"result">>, string, mandatory}
              ],
              Timeout) of
        {ok, List, []} ->
            get_result(List);
        {error, Reason} ->
            {error, Reason}
    end.
