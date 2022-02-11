#!/bin/sh
# 3. create root user's password

PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

run_query() {
  echo $* | sed -e "s/^/[$0] /"
  echo $* | mysql -uroot mysql
}

# delete root users except root@'%'
del_root_users=` \
    echo "SELECT host FROM proxies_priv WHERE user = 'root' AND host NOT IN ('localhost', '%');" | \
      mysql -uroot mysql | sed -e 1d`
for h in $del_root_users; do
  run_query "DROP USER IF EXISTS root@'$h'; DELETE FROM proxies_priv WHERE Host = '$h';"
done

run_query "CREATE USER IF NOT EXISTS root@'%' IDENTIFIED BY '$ROOT_PASSWORD';"
run_query "ALTER USER root@'%' IDENTIFIED BY '$ROOT_PASSWORD';"
run_query "ALL PRIVILEGES ON *.* TO root@'%' WITH GRANT OPTION;"
run_query "FLUSH PRIVILEGES;"
