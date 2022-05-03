#!/usr/bin/env bash

## RSS模组 RSS moudle

set +e

install_rss() {
  cd
  # mkdir -p /usr/share/nginx/nextcloud_data
  # mkdir -p /usr/share/nginx/nextcloud/apps
  mkdir /etc/redis/
  wget https://raw.githubusercontent.com/redis/redis/6.2/redis.conf && mv redis.conf /etc/redis/
  sed -i "s/appendonly no/appendonly yes/g" /etc/redis/redis.conf
  if grep -q "unixsocket /var/run/redis/redis.sock" /etc/redis/redis.conf; then
    :
  else
    echo "" >>/etc/redis/redis.conf
    echo "unixsocket /var/run/redis/redis.sock" >>/etc/redis/redis.conf
    echo "unixsocketperm 777" >>/etc/redis/redis.conf
  fi
  # cd /usr/share/nginx/

  ## Install Miniflux
  cd /usr/share/nginx/
  mkdir miniflux
  cd /usr/share/nginx/miniflux
  cat >"/usr/share/nginx/miniflux/docker-compose.yml" <<EOF
version: '3.8'
services:
  rsshub:
    # 1200
    image: diygod/rsshub:latest
    restart: unless-stopped
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
    restart: unless-stopped
    ports:
      - "6379:6379"
      # - "6378:6379"
    volumes:
      - "/etc/redis:/data"
      - "/etc/redis/redis.conf:/data/redis.conf"
      # - "/var/run/redis/redis.sock:/tmp/redis.sock"
    command:
      - redis-server /etc/redis/redis.conf
      
  miniflux:
    # 8280
    image: miniflux/miniflux:latest
    restart: unless-stopped
    ports:
      - "8280:8080"
    depends_on:
      - postgresqldb
      - rsshub
    environment:
      - DATABASE_URL=postgres://miniflux:adminadmin@postgresqldb/miniflux?sslmode=disable
      - BASE_URL=https://${domain}/miniflux/
      - RUN_MIGRATIONS=1
      - CREATE_ADMIN=1
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=adminadmin
  postgresqldb:
    image: postgres:latest
    restart: unless-stopped
    environment:
      - POSTGRES_USER=miniflux
      - POSTGRES_PASSWORD=adminadmin
    volumes:
      - miniflux-db:/var/lib/postgresql/data
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "miniflux" ]
      interval: 10s
      start_period: 30s

  nextcloud:
    image: nextcloud:apache
    # env_file:
    #   - db.env
    depends_on:
      - db
      - redis
    environment:
      - REDIS_HOST=redis
      - UID=1000
      - GID=1000
      - UPLOAD_MAX_SIZE=10G
      - APC_SHM_SIZE=128M
      - OPCACHE_MEM_SIZE=128
      - CRON_PERIOD=15m
      - TZ=Aisa/Shanghai
      - DOMAIN="${domain}"
      - DB_TYPE=mysql
      - DB_NAME=nextcloud
      - DB_USER=nextcloud
      - DB_PASSWORD="${password1}"
      - NEXTCLOUD_ADMIN_USER="admin"
      - NEXTCLOUD_ADMIN_PASSWORD="${password1}"
      - DB_HOST=db
    ports:
      - 9000:80
    volumes:
      - nextcloud:/var/www/html
      # - "/usr/share/nginx/nextcloud_data:/var/www/html/data"
      # - "/usr/share/nginx/nextcloud/config:/var/www/html/config" 
      # - "/usr/share/nginx/nextcloud/apps:/var/www/html/custom_apps"
  db:
    image: mariadb:latest
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    restart: always
    volumes:
      - db:/var/lib/mysql
      - /etc/localtime:/etc/localtime
    ports:
      - 3306:3306
    environment:
      - MYSQL_ROOT_PASSWORD:"${password1}"
      - MYSQL_DATABASE:nextcloud
      - MYSQL_USER:nextcloud
      - MYSQL_PASSWORD:"${password1}"
    command: ['mysqld', '--character-set-server=utf8mb4', '--collation-server=utf8mb4_unicode_ci', '--innodb_read_only_compressed=OFF']
    # env_file:
    #   - db.env
volumes:
  nextcloud:
  miniflux-db:
  db:

EOF
  sed -i "s/adminadmin/${password1}/g" docker-compose.yml
  docker-compose build --pull
  docker-compose up -d
  # usermod -a -G redis www-data
  # mysql -u root -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  # mysql -u root -e "create user 'nextcloud'@'localhost' IDENTIFIED BY '${password1}';"
  # mysql -u root -e "GRANT ALL PRIVILEGES ON nextcloud.* to nextcloud@'localhost';"
  # mysql -u root -e "flush privileges;"
  cd
}
