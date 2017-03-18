#
#MYSQL_HOME ?= /opt/mysql/debug/5.6.35-ndb-7.3.16
#MYSQL_HOME ?= /opt/mysql/debug/5.6.35-ndb-7.4.14
 MYSQL_HOME ?= /opt/mysql/debug/5.7.17-ndb-7.5.5

 MGM  = $(MYSQL_HOME)/bin/ndb_mgm
 MGMD = $(MYSQL_HOME)/bin/ndb_mgmd
 NDBD = $(MYSQL_HOME)/bin/ndbd
 WAIT = $(MYSQL_HOME)/bin/ndb_waiter

 OPT  =
#OPT += --ndb-connectstring="127.0.0.1"

 DATA = /tmp/mgmepi

#
default: show

#
$(VERBOSE).SILENT:

start: mstart-91 dstart-1 dstart-4 dwait

restart: stop-91 mwait-91 mrestart-91 sleep-5 restart-1 restart-4 dinitial-2 dinitial-5

stop: shutdown mwait-91

mstart-%: $(DATA)-%
	$(MGMD) --ndb-nodeid=$* --config-file=etc/start.ini --config-cache=FALSE
mrestart-%:
	$(MGMD) --ndb-nodeid=$* --config-file=etc/restart.ini --config-cache=FALSE
mwait-%:
	while [[ -e $(DATA)/$*/ndb_$*.pid ]]; do sleep 1; done

dstart-%: $(DATA)-%
	$(NDBD) --ndb-nodeid=$* $(OPT)
dinitial-%: $(DATA)-%
	$(NDBD) --ndb-nodeid=$* $(OPT) --initial
dwait:
	$(WAIT) $(OPT) > /dev/null 2>& 1

console:
	$(MGM) $(OPT)
restart-%:
	$(MGM) $(OPT) -e "$* RESTART"
	$(WAIT) $(OPT) --wait-nodes=$* > /dev/null 2>& 1
show:
	$(MGM) $(OPT) -e "SHOW"
shutdown:
	$(MGM) $(OPT) -e "SHUTDOWN"
stop-%:
	$(MGM) $(OPT) -e "$* STOP"

sleep-%:
	sleep $*

clean: rm-data

#
$(DATA)-%:
	mkdir -p $(subst -,/,$@)

rm-data:
	rm -rf $(DATA)
