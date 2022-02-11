#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

snapshot=/snapshots/snapshot-`date +%Y%m%d`
(mariabackup --backup -u root --target-dir=$snapshot && \
  mariabackup --prepare --target-dir=$snapshot) | \
    sed -e 's/^/[mariabackup] /'

if [ -f $snapshot/xtrabackup_binlog_info ]; then
  chmod a+rx $snapshot && \
  echo "[$myname] backup createed: $snapshot"
fi
