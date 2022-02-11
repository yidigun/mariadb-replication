#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$myname: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

run_query() {
  echo "$*" | sed -e "s/^/[$myname] /"
  echo "$*" | mysql -uroot mysql
}

if [ ! -f /var/lib/mysql/xtrabackup_binlog_info ]; then
  echo "$myname: /var/lib/mysql/xtrabackup_binlog_info: not found" >&2
  exit 1
fi
if [ "$REPL_MODE" != slave ]; then
  echo "$myname: invalid REPL_MODE: $REPL_MODE" >&2
  exit 1
fi
if [ -z "$REPL_MASTER_HOST" ]; then
  echo "$myname: \$REPL_MASTER_HOST is not specified" >&2
  exit 1
fi
REPL_MASTER_PORT=${REPL_MASTER_PORT:-3306}

eval `cat /var/lib/mysql/xtrabackup_binlog_info | awk '{print "MASTER_LOG_FILE=" $1 "\bMASTER_LOG_POS=" $2 }'`
run_query "CHANGE MASTER TO \
    MASTER_HOST='$REPL_MASTER_HOST', \
    MASTER_PORT=$REPL_MASTER_PORT, \
    MASTER_USER='$REPL_USERNAME', \
    MASTER_PASSWORD='$REPL_PASSWORD', \
    MASTER_LOG_FILE='$MASTER_LOG_FILE', \
    MASTER_LOG_POS=$MASTER_LOG_POS;"
run_query "START SLAVE;"
