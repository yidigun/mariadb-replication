#!/bin/sh
# 3. create root user's password

PASSWORD_SECRET=${PASSWORD_SECRET:-passwords}
if [ ! -f /run/secrets/$PASSWORD_SECRET ]; then
  echo "$0: /run/secrets/$PASSWORD_SECRET: not found" >&2
  exit 1
fi
. /run/secrets/$PASSWORD_SECRET

# delete root users except root@'%'
del_root_users=` \
    echo "SELECT host FROM proxies_priv WHERE user = 'root' AND host NOT IN ('localhost', '%');" | \
      mysql -uroot mysql | sed -e 1d`
for h in $del_root_users; do
  echo "DROP USER IF EXISTS root@'$h'; DELETE FROM proxies_priv WHERE Host = '$h';" | mysql -uroot mysql
done

cat <<EOF | mysql -uroot mysql
CREATE USER IF NOT EXISTS root@'%' IDENTIFIED BY '$ROOT_PASSWORD';
ALTER USER root@'%' IDENTIFIED BY '$ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO root@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
