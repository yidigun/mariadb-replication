#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

snapshot=/snapshots/snapshot-`date +%Y%m%d`
mariabackup --backup -u root --target-dir=$snapshot && \
  mariabackup --prepare --target-dir=$snapshot && \

if [ -f $snapshot/xtrabackup_binlog_info ]; then
  chmod a+rx $snapshot && \
  echo "[$myanem] backup createed: $snapshot"
fi
