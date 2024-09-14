#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

snapshot=/snapshots/snapshot-`date +%Y%m%d`
(mariadb-backup --backup -u root --target-dir=$snapshot "$@" && \
  mariadb-backup --prepare --target-dir=$snapshot) | \
    sed -e 's/^/[mariadb-backup] /'

if [ -f $snapshot/xtrabackup_binlog_info ]; then
  chmod a+rx $snapshot && \
  echo "[$myname] backup createed: $snapshot"
fi
