#
 MYSQL_HOME ?= /opt/mysql/debug/5.7.17-ndb-7.5.5

 OPT  =
 OPT += "--nodeid=$(1)"
 OPT += "--backupid=$(2)"
 OPT += "--backup_path=./backup"
 OPT += "--restore_data"
 OPT += "--include-databases=test"
 OPT += "--no-binlog"

#
default: show_tables

#
$(VERBOSE).SILENT:

restore: restore-1-1 restore-4-1

restore-1-%:
	$(MYSQL_HOME)/bin/ndb_restore $(call OPT,1,$*) --restore_meta
restore-4-%:
	$(MYSQL_HOME)/bin/ndb_restore $(call OPT,4,$*)

#
show_tables:
	$(MYSQL_HOME)/bin/ndb_show_tables

counters diskpagebuffer logbuffers logspaces nodes resources threadblocks threadstat transporters:
	$(MYSQL_HOME)/bin/ndbinfo_select_all $@

#
desc index_stat select_count:
	$(MYSQL_HOME)/bin/ndb_$@ city -d test
