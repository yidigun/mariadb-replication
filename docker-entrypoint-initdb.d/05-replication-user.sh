#!/bin/sh
# 4. create repliaction user if master

if [ "$REPL_ROLE" = master ]; then
  PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
  if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
    echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
    exit 1
  fi
  . /run/secrets/$PASSWORD_SECRET

  if [ -n "$REPL_USERNAME" ]; then
    eval "REPL_PASSWORD=`echo $REPL_USERNAME | tr [[:lower:]] [[:upper:]]`_PASSWORD"
  fi

  cat <<EOF | mysql -uroot mysql
CREATE USER IF NOT EXISTS $REPL_USERNAME@'%' IDENTIFIED BY '$REPL_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO $REPL_USERNAME@'%';
EOF
fi
