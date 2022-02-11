#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

snapshot=/snapshots/snapshot-`date +%Y%m%d`
mariabackup --backup --target-dir=$snapshot -u root && \
  mariabackup --prepare --target-dir=$snapshot
