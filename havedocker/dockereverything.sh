#!/usr/bin/env bash

## RSS模组 RSS moudle

set +e

sysctl -w net.ipv4.ip_forward=1
cd /usr
mkdir dockereverything

if [[ -f /usr/nginx/dockereverything/redis/redis.conf ]]; then
  echo "redis已存在并写入执行完毕"
else
  cd /usr/dockereverything/
  mkdir -p /redis/data
  sleep 2
  wget https://raw.githubusercontent.com/redis/redis/6.2/redis.conf && mv redis.conf /usr/dockereverything/redis/data
  sed -i "s/appendonly no/appendonly yes/g" /usr/dockereverything/redis/data/redis.conf
  # if grep -q "unixsocket /var/run/redis/redis.sock" /usr/dockereverything/redis/redis.conf; then
  #   :
  # else
  #   echo "" >>/usr/dockereverything/redis/redis.conf
  #   echo "unixsocket /var/run/redis/redis.sock" >>/usr/dockereverything/redis/redis.conf
  #   echo "unixsocketperm 777" >>/usr/dockereverything/redis/redis.conf
  #   echo "redis写入执行完毕"
  # fi
fi

if [[ -f /usr/dockereverything/mariadbinit/init.sql ]]; then
  echo "mariadb服务器配置文件已经存在，正在跳过，执行安装"
  chmod -R 777 /usr/dockereverything/mariadbinit/init.sql
else
  mkdir mariadbinit
  touch /usr/dockereverything/mariadbinit/init.sql
  echo "CREATE DATABASE IF NOT EXISTS trojan;" >/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE DATABASE IF NOT EXISTS nextcloud;" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE DATABASE IF NOT EXISTS netdata;" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE DATABASE IF NOT EXISTS roundcubemail;" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE DATABASE IF NOT EXISTS npm;" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE USER IF NOT EXISTS 'nextcloud'@'%' IDENTIFIED BY '${password1}';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE USER IF NOT EXISTS 'netdata'@'%' IDENTIFIED BY '${password1}';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE USER IF NOT EXISTS 'trojan'@'%' IDENTIFIED BY '${password1}';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE USER IF NOT EXISTS 'roundcube'@'%' IDENTIFIED BY '${password1}';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "CREATE USER IF NOT EXISTS 'npm'@'%' IDENTIFIED BY '${password1}';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'nextcloud'@'%';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'netdata'@'%';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'trojan'@'%';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'roundcube'@'%';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'npm'@'%';" >>/usr/dockereverything/mariadbinit/init.sql
  echo "FLUSH PRIVILEGES;" >>/usr/dockereverything/mariadbinit/init.sql
  chmod -R 777 /usr/dockereverything/mariadbinit/init.sql
fi

install_dockereverything() {
  ## Install Miniflux
  cd /usr/dockereverything
  cat >"/usr/dockereverything/docker-compose.yml" <<EOF
version: '3.8'
services:
  rsshub:
    # 1200
    image: diygod/rsshub:latest
    restart: always
    container_name: rsshub
    ports:
      - '1200:1200'
    environment:
      # PROXY_URI: 'http://127.0.0.1:8080'
      NODE_ENV: production
      CACHE_TYPE: redis
      REDIS_URL: 'redis://redis:6379/'
      PUPPETEER_WS_ENDPOINT: 'ws://browserless:3000'
    depends_on:
      - browserless
      - redis

  browserless:
    # 3000
    image: browserless/chrome:latest
    container_name: browserless
    restart: unless-stopped
    ports:
      - 127.0.0.1:3000:3000

  redis:
    # 6379
    image: "redis:latest"
    container_name: redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - /usr/dockereverything/redis/data:/data
      # - "/redis/redis.conf:/data/redis.conf"
      # - "/var/run/redis/redis.sock:/tmp/redis.sock"
    # command: redis-server /data/redis.conf
      
  miniflux:
    # 8280
    image: miniflux/miniflux:latest
    container_name: miniflux
    restart: always
    ports:
      - "8280:8080"
    depends_on:
      - postgresqldb
    volumes:
      - miniflux_socket:/socket/postgresql
    environment:
      #新版不建议在套接字中指定主机
      - TZ=Aisa/Shanghai
      - DATABASE_URL=user=miniflux password=adminadmin dbname=miniflux sslmode=disable host=/socket/postgresql port=5432
      - BASE_URL=https://127.0.0.1/miniflux/
      - RUN_MIGRATIONS=1
      - CREATE_ADMIN=1
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=adminadmin
    healthcheck:
      test: [ "CMD", "/usr/bin/miniflux", "-healthcheck", "auto" ]
      interval: 10s
      start_period: 30s

  postgresqldb:
    container_name: postgresqldb
    image: postgres:latest
    restart: unless-stopped
    environment:
      - POSTGRES_USER=miniflux
      - POSTGRES_PASSWORD=adminadmin
      - POSTGRES_DB=miniflux
    volumes:
      # - /usr/miniflux-data/mariadb:/var/lib/postgresql/data
      - miniflux_socket:/var/run/postgresql
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "miniflux" ]
      interval: 10s
      start_period: 30s

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: always
    user: "1000:1000"
    depends_on:
      - mariadb
      - redis
    environment:
      - REDIS_HOST=redis
      # - UID=1000
      # - GID=1000
      - PHP_UPLOAD_LIMIT=10G
      - NEXTCLOUD_TRUSTED_DOMAINS='localhost' '172.18.0.*' '172.*.*.*'
      - TZ=Aisa/Shanghai
      - OVERWRITEPROTOCOL='https'
      # - DOMAIN=127.0.0.1:8281
      - DB_TYPE=mysql
      - DB_NAME=nextcloud
      - DB_USER=nextcloud
      - DB_PASSWORD=${password1}
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=nextcloud
      - DB_HOST=mariadb
    ports:
      - 8281:80
    volumes:
      - /usr/dockereverything/nextcloud:/var/www/html
      # - /usr/dockereverything/nextcloud/confredis:/usr/local/etc/php/conf.d
      # - "/usr/nginx/miniflux/nextcloud/config:/var/www/html/config" 
      # - "/usr/nginx/miniflux/nextcloud/apps:/var/www/html/custom_apps"

  freenom:
      image: luolongfei/freenom:latest
      container_name: freenom
      restart: always
      volumes:
        - /usr/dockereverything/freenom/conf:/conf
        - /usr/dockereverything/freenom/logs:/app/logs

  mariadb:
    image: mariadb:10.7.4
    container_name: mariadb
    restart: unless-stopped
    volumes:
      - /usr/dockereverything/mariadb:/var/lib/mysql
      - /usr/dockereverything/mariadbinit:/docker-entrypoint-initdb.d
      # - /etc/localtime:/etc/localtime
    ports:
      - 3306:3306
    environment:
      - MYSQL_ROOT_PASSWORD="${password1}"
      # - MYSQL_DATABASE=init
      # - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD="${password1}"
      - TZ="Asia/Shanghai"
    command: 
      [
        '--character-set-server=utf8mb4',
        '--collation-server=utf8mb4_unicode_ci',
        '--default-storage-engine=innodb',
        '--max-connections=1000',
        '--max-connections=1000',
        '--binlog-format=ROW'
      ]
    healthcheck:
      test: [ "CMD-SHELL", 'mysqladmin ping' ]
      interval: 20s
      start_period: 10s
      timeout: 10s
      retries: 3

  hexo:
    image: spurin/hexo:latest
    user: 1000:1000
    restart: unless-stopped
    # stdin_open: true
    # tty: true
    environment:
      - GIT_USER="Kept😀Cry"
      - GIT_EMAIL="ceshizh01@gmail.com"
    container_name: hexo
    ports:
      - 4000:4000
    volumes:
      - /usr/dockereverything/blog/domain.com:/app

  netdata:
    image: netdata/netdata
    container_name: netdata
    hostname: my_docker_compose_netdata
    ports:
      - 19999:19999
    restart: unless-stopped
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    volumes:
      - /usr/dockereverything/netdata/netdataconfig:/etc/netdata:ro
      - netdatalib:/var/lib/netdata
      - netdatacache:/var/cache/netdata
      - /usr/dockereverything/netdata/etc/passwd:/host/etc/passwd:ro
      - /usr/dockereverything/netdata/etc/group:/host/etc/group:ro
      - /usr/dockereverything/netdata/proc:/host/proc:ro
      - /usr/dockereverything/netdata/sys:/host/sys:ro
      - /usr/dockereverything/netdata/etc/os-release:/host/etc/os-release:ro

  nginxmanager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx_manager
    restart: unless-stopped
    depends_on:
      - mariadb
    ports:
      - '80:80'
      - '8181:81'
      - '443:443'
    environment:
      DB_MYSQL_HOST: "mariadb"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "${password1}"
      DB_MYSQL_NAME: "npm"
    volumes:
      - /usr/dockereverything/nginx/data:/data
      - /usr/dockereverything/nginx/letsencrypt/${domain}_ecc:/etc/letsencrypt

  unlockmusic:
    image: nondanee/unblockneteasemusic:latest
    container_name: unlockmusic
    restart: unless-stopped
    user: "1000:1000"
    ports:
      - 8282:8080

  alist:
    image: xhofe/alist:v2
    container_name: alist
    restart: always
    user: "1000:1000"
    ports:
      - 5244:5244
    volumes:
      - /usr/dockereverything/alist:/opt/alist/data
volumes:
  miniflux_socket:
  netdatalib:
  netdatacache:
EOF
  sed -i "s/adminadmin/${password1}/g" docker-compose.yml
  docker-compose build --pull
  docker-compose up -d
  sleep 10
  docker logs alist
  sudo chmod -R 777 /usr/dockereverything
  sleep 3
  TERM=ansi whiptail --title "安装中" --infobox "安装freenom中..." 7 68
  while [[ -z ${idcard} ]]; do
    idcard=$(whiptail --inputbox --nocancel "请輸入你的freenom账号 | Please enter your USERid" 8 68 --title "USERID input" 3>&1 1>&2 2>&3)
  done
  clear
  while [[ -z ${passw} ]]; do
    passw=$(whiptail --inputbox --nocancel "请輸入你的freenom密码 | Please enter your password" 8 68 --title "PASSword input" 3>&1 1>&2 2>&3)
  done
  clear
  while [[ -z ${TELEGRAM_CHAT_ID} ]]; do
    TELEGRAM_CHAT_ID=$(whiptail --inputbox --nocancel "请輸入你的TELEGRAM_CHAT_ID | Please enter your TELEGRAM_CHAT_ID" 8 68 --title "TELEGRAM_CHAT_ID input" 3>&1 1>&2 2>&3)
  done
  clear
  while [[ -z ${TELEGRAM_BOT_TOKEN} ]]; do
    TELEGRAM_BOT_TOKEN=$(whiptail --inputbox --nocancel "请輸入你的TELEGRAM_BOT_TOKEN | Please enter your TELEGRAM_BOT_TOKEN" 8 68 --title "TELEGRAM_BOT_TOKEN input" 3>&1 1>&2 2>&3)
  done
  clear
  cd /usr/dockereverything/freenom
  sed -i "s/FREENOM_USERNAME=''/FREENOM_USERNAME=${idcard}/g" /usr/dockereverything/freenom/conf/.env
  sed -i "s/FREENOM_PASSWORD=''/FREENOM_PASSWORD=${passw}/g" /usr/dockereverything/freenom/conf/.env
  sed -i "s/TELEGRAM_CHAT_ID=''/TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}/g" /usr/dockereverything/freenom/conf/.env
  sed -i "s/TELEGRAM_BOT_TOKEN=''/TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}/g" /usr/dockereverything/freenom/conf/.env
  sed -i "s/TELEGRAM_BOT_ENABLE=0/TELEGRAM_BOT_ENABLE=1/g" /usr/dockereverything/freenom/conf/.env
  sed -i "s/NOTICE_FREQ=1/NOTICE_FREQ=0/g" /usr/dockereverything/freenom/conf/.env
  # usermod -a -G redis www-data
}
