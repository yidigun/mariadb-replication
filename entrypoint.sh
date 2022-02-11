#!/bin/sh

REPL_ROLE=${REPL_ROLE:-none}
if [ -z "$REPL_SERVER_ID" -a "REPL_ROLE" = master ]; then
  REPL_SERVER_ID=1
fi
REPL_USERNAME=${REPL_USERNAME:-repl}
PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
export REPL_USERNAME PASSWORD_SECRET REPL_ROLE

if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

run_query() {
  echo $* | sed -e "s/^/[$0] /"
  echo $* | mysql -uroot mysql
}

CMD=$1; shift
case $CMD in
  start|run|mariadbd|mysqld)
    # 1. define server role & server_id
    echo "[$0] Replication Role: $REPL_ROLE"
    repl_config=/etc/mysql/conf.d/01-replication-${REPL_ROLE}.cnf
    echo "[$0] generate config: $repl_config"
    if [ "$REPL_ROLE" = master ]; then
      cat <<EOF >$repl_config
[mysqld]
server_id               = $REPL_SERVER_ID
log_bin
binlog_format           = MIXED
max_binlog_size         = 500M
EOF
    else
      cat <<EOF >$repl_config
[mysqld]
server_id               = $REPL_SERVER_ID
EOF
    fi
    cat $repl_config | sed -e "s/^/[$0] /"

    # 2. ssl config
    if [ -n "$SSL_CERT_FILE" -o "$SSL_CA_FILE" -o "$SSL_KEY_FILE" ]; then
      SSL_REQUIRE=${SSL_REQUIRE:-off}
      echo "[$0] Replication Role: $REPL_ROLE"
      ssl_config=/etc/mysql/conf.d/02-ssl.cnf
      echo "[$0] generate config: $ssl_config"

      echo '[mysqld]' >$ssl_config
      [ -n "$SSL_CERT_FILE" -a -f "$SSL_CERT_FILE" ] && echo "ssl_ca =   $SSL_CERT_FILE" >>$ssl_config
      [ -n "$SSL_CA_FILE"   -a -f "$SSL_CA_FILE" ]   && echo "ssl_cert = $SSL_CA_FILE"   >>$ssl_config
      [ -n "$SSL_KEY_FILE"  -a -f "$SSL_KEY_FILE" ]  && echo "ssl_key =  $SSL_KEY_FILE"  >>$ssl_config
      SSL_REQUIRE=`echo $SSL_REQUIRE | tr [[:lower:]] [[:upper:]]`
      if [ "$SSL_REQUIRE" = yes -o "$SSL_REQUIRE" = on -o "$SSL_REQUIRE" = true -o "$SSL_REQUIRE" = 1 ]; then
        echo "require_secure_transport = 1"  >>$ssl_config
      fi

      cat $ssl_config | sed -e "s/^/[$0] /"
    fi

    # 3. call /usr/local/bin/docker-entrypoint.sh
    echo "[$0] exec() to /usr/local/bin/docker-entrypoint.sh"
    MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
      exec /usr/local/bin/docker-entrypoint.sh mariadbd

    # docker-entrypoint.sh will execute next steps:
    # 4. docker-entrypoint-initdb.d/04-root-password.sh
    # 5. docker-entrypoint-initdb.d/05-replication-user.sh
    ;;

  backup-master)
    snapshot=/snapshots/snapshot-`date +%Y%m%d`
    echo "[$0] create backup: --target-dir=$snapshot"
    mariabackup --backup --target-dir=$snapshot && \
      mariabackup --prepare --target-dir=$snapshot
    ;;

  start-slave)
    if [ ! -f /var/lib/mysql/xtrabackup_binlog_info ]; then
      echo "$0: /var/lib/mysql/xtrabackup_binlog_info: not found" >&2
      exit 1
    fi
    if [ "$REPL_MODE" != slave ]; then
      echo "$0: invalid REPL_MODE: $REPL_MODE" >&2
      exit 1
    fi
    if [ -z "$REPL_MASTER_HOST" ]; then
      echo "$0: \$REPL_MASTER_HOST is not specified" >&2
      exit 1
    fi
    REPL_MASTER_PORT=${REPL_MASTER_PORT:-3306}

    eval `cat /var/lib/mysql/xtrabackup_binlog_info | awk '{print "MASTER_LOG_FILE=" $1 "\bMASTER_LOG_POS=" $2 }'`
    run_query "CHANGE MASTER TO \
        MASTER_HOST="$REPL_MASTER_HOST", \
        MASTER_PORT=$REPL_MASTER_PORT, \
        MASTER_USER="$REPL_USERNAME", \
        MASTER_PASSWORD="$REPL_PASSWORD", \
        MASTER_LOG_FILE='$MASTER_LOG_FILE', \
        MASTER_LOG_POS=$MASTER_LOG_POS;"
    run_query "START SLAVE;"
    ;;

  sh|bash|/bin/sh|/bin/bash)
    exec /bin/bash "$@"
    ;;

  *)
    echo "usage: $0 { run [ ARGS ... ] | sh [ ARGS ... ] | backup-master | start-slave }"
    ;;
esac
