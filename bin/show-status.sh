#!/bin/sh

echo "############### Server Version ###############"
mysqladmin -uroot version

echo "############### Server Status ###############"
mysqladmin -uroot status

if [ "$REPL_MODE" = master -o "$REPL_MODE" = slave ]; then
  echo "############### Replication Status ###############"
  echo "Replication Mode: $REPL_MODE"
  case $REPL_MODE in
    master)
      run_query 'show master status\G'
      ;;

    slave)
      run_query 'show slave status\G'
      ;;
  esac
fi

echo "############### Connections ###############"
netstat -natp | grep -v TIME_WAIT
