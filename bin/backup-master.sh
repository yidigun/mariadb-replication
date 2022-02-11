#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

snapshot=/snapshots/snapshot-`date +%Y%m%d`
mariabackup --backup --target-dir=$snapshot && \
  mariabackup --prepare --target-dir=$snapshot
