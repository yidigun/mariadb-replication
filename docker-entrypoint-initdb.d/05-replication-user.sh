#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

# 4. create repliaction user if master

run_query() {
  echo $* | sed -e "s/^/[$myname] /"
  echo $* | mysql -uroot mysql
}

if [ "$REPL_ROLE" = master ]; then
  echo "[$myname] Create replication user: $REPL_USERNAME"
  PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
  if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
    echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
    exit 1
  fi
  . /run/secrets/$PASSWORD_SECRET

  if [ -n "$REPL_USERNAME" ]; then
    eval "REPL_PASSWORD=`echo $REPL_USERNAME | tr [[:lower:]] [[:upper:]]`_PASSWORD"
  fi

  run_query "CREATE USER IF NOT EXISTS $REPL_USERNAME@'%' IDENTIFIED BY '$REPL_PASSWORD';"
  run_query "GRANT REPLICATION SLAVE ON *.* TO $REPL_USERNAME@'%';"
fi
