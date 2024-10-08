#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

# 4. create repliaction user if master

run_query() {
  echo "$*" | sed -e "s/^/[$myname] /"
  echo "$*" | mariadb -uroot mysql
}

if [ "$REPL_MODE" = master ]; then
  echo "[$myname] Create replication user: $REPL_USERNAME"
  PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
  if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
    echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
    exit 1
  fi
  . /run/secrets/$PASSWORD_SECRET

  if [ -n "$REPL_USERNAME" ]; then
    eval "password=\${`echo $REPL_USERNAME | tr [[:lower:]] [[:upper:]]`_PASSWORD}"
  fi

  run_query "CREATE USER IF NOT EXISTS $REPL_USERNAME@'%' IDENTIFIED BY '$password';"
  run_query "GRANT REPLICATION SLAVE ON *.* TO $REPL_USERNAME@'%';"
fi
