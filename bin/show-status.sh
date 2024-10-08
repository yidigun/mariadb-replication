#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

echo
echo "############### Server Version ###############"
echo
mariadb-admin -uroot version | sed -e "s/^/[mariadb-admin] /"

echo
echo "############### Server Status ###############"
echo
mariadb-admin -uroot status | sed -e "s/^/[mariadb-admin] /"

if [ "$REPL_MODE" = master -o "$REPL_MODE" = slave ]; then
  echo
  echo "############### Replication Status ###############"
  echo
  echo "Replication Mode: $REPL_MODE"
  echo

  run_query() {
    echo "$*" | mariadb -uroot mysql | sed -e "s/^/[mysql] /"
  }
  case $REPL_MODE in
    master)
      run_query 'show master status\G'
      ;;

    slave)
      run_query 'show slave status\G'
      ;;
  esac
fi

echo
echo "############### Connections ###############"
echo
netstat -natp | grep -v TIME_WAIT | sed -e "s/^/[netstat] /"
