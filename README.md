# Mariadb Replication

Mariadb replication settings

## Mariadb License

See https://mariadb.com/kb/en/mariadb-license/

## Dockerfile License

It's just free. (Public Domain)

See https://github.com/yidigun/mariadb-replication

## Environment variables

- **REPL_MODE**: replication mode (required. ```none``` | ```master``` | ```slave```)
- **REPL_SERVER_ID**: unique id for each server instance (required)
- **REPL_USERNAME**: replication username. password must be specified using ```PASSWORD_SECRET``` (default: ```repl```)
- **REPL_BACKUP**: full path of backup copy to restore.
- **REPL_MASTER_HOST**: master servier's FQDN or address. (required for slave setup)
- **REPL_MASTER_PORT**: master servier's port. only for slave setup (default: ```3306```)
- **PASSWORD_SECRET**: password secret name (default: ```passwords```)
- **SSL_CERT_FILE**: ssl certificate file
- **SSL_CA_FILE**: ssl ca certificate file
- **SSL_KEY_FILE**: ssl private-key file
- **SSL_REQUIRE**: require_secure_transport variable value
- **MARIADB_PORT**: service port (default: 3306)

## How to inject initial passwords

Make password config file using shell script syntax.

Format: ***USERNAME***_PASSWORD="___Password in plain text___"

#### passwords.sh

```shell
ROOT_PASSWORD="s3cret12#$"  # database admin
REPL_PASSWORD="cp1fly*"     # replication user
```

#### docker-compose.yaml

```yaml
...
services:
  mariadb:
    ...
    env:
      - REPL_USERNAME=repl
      - PASSWORD_SECRET=passwords
    ...
  secrets:
    passwords:
      - file: ${HOME}/passwords.sh
```

## Setting up Replication

See https://mariadb.com/kb/en/setting-up-a-replication-slave-with-mariabackup/ for more details.

### 1. Master setup

#### 1) passwords.sh

```shell
ROOT_PASSWORD="s3cret12#$"  # database admin
REPL_PASSWORD="cp1fly*"     # replication user
```

#### 2) docker-compose.yaml

```shell
version: "3.3"

services:
  mariadb-replication:
    image: yidigun/mariadb-replication:10.7
    restart: unless-stopped
    hostname: ${HOSTNAME}
    ports:
      - "3306:3306/tcp"
    environment:
      - TZ=Asia/Seoul
      - LANG=ko_KR.UTF-8
      - REPL_MODE=master
      - REPL_SERVER_ID=1
      - REPL_USERNAME=repl
    volumes:
      - /data/mariadb-replication/data:/var/lib/mysql
      - /data/mariadb-replication/log:/var/log/mysql
      - /data/mariadb-replication/run:/run/mysqld
      - /data/mariadb-replication/snapshots:/snapshots
    secrets:
      - passwords

secrets:
  passwords:
    file: /path/to/passwords.sh
```

#### 3) Start master database

```shell
[MASTER]$ docker-compose up -d
```

Start service and check master database work properly.

### 2. Make backup and copy to slave server

First, make full backup of master server using ```mariabackup```.
Following command will create backup copy in ```/snapshots/snapshot-%Y%m%d```.
(eg: ```/snapshots/snapshot-20220210```)

```shell
[MASTER]$ docker-compose exec mariadb-replication backup-master
```

And move the backup files to slave server's ```/var/lib/mysql``` volume by any means.

```shell
[MASTER]$ (cd /data/mariadb-replication/snapshots/snapshot-`date +%Y%m%d`; tar cf - *) | \
          ssh slave-server ' \
              sudo mkdir -p /data/mariadb-replication/data; \
              (cd /data/mariadb-replication/data; sudo tar xf -) && \
              sudo chown -R 999:999 /data/mariadb-replication/data'
```

### 3. Slave setup

#### 1) passwords.sh

```shell
REPL_PASSWORD="cp1fly*"     # replication user
```

#### 2) docker-compose.yaml

***Note: REPL_SERVER_ID value must be unique in cluster.***

```shell
version: "3.3"

services:
  mariadb-replication:
    image: yidigun/mariadb-replication:10.7
    restart: unless-stopped
    hostname: ${HOSTNAME}
    ports:
      - "3306:3306/tcp"
    environment:
      - TZ=Asia/Seoul
      - LANG=ko_KR.UTF-8
      - REPL_MODE=slave
      - REPL_SERVER_ID=2
      - REPL_USERNAME=repl
      - REPL_MASTER_HOST=mariadb-replication-master.example.com
      - REPL_MASTER_PORT=3306
    volumes:
      - /data/mariadb-replication/data:/var/lib/mysql
      - /data/mariadb-replication/log:/var/log/mysql
      - /data/mariadb-replication/run:/run/mysqld
    secrets:
      - passwords

secrets:
  passwords:
    file: /path/to/passwords.sh
```

#### 3) Start slave database

```shell
[SLAVE]$ docker-compose up -d
```

#### 4) Start replication

Replication position will retrieved from ```/var/lib/mysql```/```xtrabackup_binlog_info```.
This file was generated when ```mariabackip``` make backup copy.

```shell
[SLAVE]$ docker-compose exec mariadb-replication start-slave
```

### 4. Check status

```shell
docker-compose exec mariadb-replication show-status
```