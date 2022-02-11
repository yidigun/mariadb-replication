#!/bin/sh
myname=`basename $0 .sh | sed -e 's!/!_!g'`

# 3. create root user's password

PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

run_query() {
  echo $* | sed -e "s/^/[$myname] /"
  echo $* | mysql -uroot mysql
}

# delete root users except root@'%'
echo "[$myname] Delete unused root users"
del_root_users=` \
    echo "SELECT host FROM proxies_priv WHERE user = 'root' AND host NOT IN ('localhost', '%');" | \
      mysql -uroot mysql | sed -e 1d`
for h in $del_root_users; do
  run_query "DROP USER IF EXISTS root@'$h';"
  run_query "DELETE FROM proxies_priv WHERE Host = '$h';"
done

echo "[$myname] Set root@'%' password: $ROOT_PASSWORD"
run_query "CREATE USER IF NOT EXISTS root@'%' IDENTIFIED BY '$ROOT_PASSWORD';"
run_query "ALTER USER root@'%' IDENTIFIED BY '$ROOT_PASSWORD';"
run_query "ALL PRIVILEGES ON *.* TO root@'%' WITH GRANT OPTION;"
run_query "FLUSH PRIVILEGES;"
