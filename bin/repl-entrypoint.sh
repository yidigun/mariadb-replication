#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

# try to set locale and timezone
if locale -a 2>/dev/null | grep -q "$LANG"; then
  : do nothing
else
  locale-gen $LANG 2>/dev/null
  update-locale LANG=$LANG 2>/dev/null
fi
if [ -n "$TZ" -a -f /usr/share/zoneinfo/$TZ ]; then
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
fi

REPL_MODE=${REPL_MODE:-none}
if [ -z "$REPL_SERVER_ID" -a "$REPL_MODE" = master ]; then
  REPL_SERVER_ID=1
fi
REPL_USERNAME=${REPL_USERNAME:-repl}
PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
export REPL_USERNAME PASSWORD_SECRET REPL_MODE

if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$myname: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

CMD=$1; shift
case $CMD in
  start|run|mariadbd|mysqld)
    # 0. server config
    MARIADB_PORT=${MARIADB_PORT:-3306}
    if [ $MARIADB_PORT -ne 3306 ]; then
      sed -i -e "s/^port                    = 3306/port = $MARIADB_PORT/" \
          /etc/mysql/conf.d/00-default.cnf
    fi

    # 1. define server role & server_id
    echo "[$myname] Replication Role: $REPL_MODE"
    repl_config=/etc/mysql/conf.d/01-replication-${REPL_MODE}.cnf
    echo "[$myname] generate config: $repl_config"
    if [ "$REPL_MODE" = master ]; then
      cat <<EOF >$repl_config
[mariadbd]
server_id               = $REPL_SERVER_ID
log_bin
binlog_format           = MIXED
max_binlog_size         = 500M
EOF
    else
      cat <<EOF >$repl_config
[mariadbd]
server_id               = $REPL_SERVER_ID
EOF
    fi
    cat $repl_config | sed -e "s/^/[$myname] /"

    # 2. ssl config
    if [ -n "$SSL_CERT_FILE" -o "$SSL_CA_FILE" -o "$SSL_KEY_FILE" ]; then
      SSL_REQUIRE=${SSL_REQUIRE:-off}
      echo "[$myname] Replication Role: $REPL_MODE"
      ssl_config=/etc/mysql/conf.d/02-ssl.cnf
      echo "[$myname] generate config: $ssl_config"

      echo '[mariadbd]' >$ssl_config
      [ -n "$SSL_CERT_FILE" -a -f "$SSL_CERT_FILE" ] && echo "ssl_ca =   $SSL_CERT_FILE" >>$ssl_config
      [ -n "$SSL_CA_FILE"   -a -f "$SSL_CA_FILE" ]   && echo "ssl_cert = $SSL_CA_FILE"   >>$ssl_config
      [ -n "$SSL_KEY_FILE"  -a -f "$SSL_KEY_FILE" ]  && echo "ssl_key =  $SSL_KEY_FILE"  >>$ssl_config
      SSL_REQUIRE=`echo $SSL_REQUIRE | tr [[:lower:]] [[:upper:]]`
      if [ "$SSL_REQUIRE" = yes -o "$SSL_REQUIRE" = on -o "$SSL_REQUIRE" = true -o "$SSL_REQUIRE" = 1 ]; then
        echo "require_secure_transport = 1"  >>$ssl_config
      fi

      cat $ssl_config | sed -e "s/^/[$myname] /"
    fi

    # 3. call /usr/local/bin/docker-entrypoint.sh
    echo "[$myname] exec() to /usr/local/bin/docker-entrypoint.sh"
    MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
      exec /usr/local/bin/docker-entrypoint.sh mariadbd

    # /usr/local/bin/docker-entrypoint.sh will execute next steps:
    # 4. docker-entrypoint-initdb.d/04-root-password.sh
    # 5. docker-entrypoint-initdb.d/05-replication-user.sh
    ;;

  sh|bash|/bin/sh|/bin/bash)
    exec /bin/bash "$@"
    ;;

  *)
    echo "usage: $0 { run [ ARGS ... ] | sh [ ARGS ... ] }"
    ;;
esac
