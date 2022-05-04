#!/usr/bin/env bash

## RSS模组 RSS moudle

set +e

if [[ -f ../jk/kk.sql ]]; then
  echo "mariadb服务器配置文件已经存在，正在跳过，执行安装"
else
  mkdir -p /jk
  touch ../jk/kk.sql
  # echo "mysql -u root" >/jk/kk.sql
  # # echo "CREATE DATABASE trojan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/jk/kk.sql
  # echo "CREATE DATABASE netdata CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >>/jk/kk.sql
  # # echo "CREATE DATABASE roundcubemail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >>/jk/kk.sql
  # echo "CREATE USER 'netdata'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  # # echo "CREATE USER 'trojan'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  # # echo "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  # echo "GRANT CREATE, ALTER, INDEX, LOCK TABLES, REFERENCES, UPDATE, DELETE, DROP, SELECT, INSERT ON *.* TO 'netdata'@'localhost';" >>/jk/kk.sql
  # # echo "GRANT CREATE, ALTER, INDEX, LOCK TABLES, REFERENCES, UPDATE, DELETE, DROP, SELECT, INSERT ON *.* TO 'trojan'@'localhost';" >>/jk/kk.sql
  # # echo "GRANT CREATE, ALTER, INDEX, LOCK TABLES, REFERENCES, UPDATE, DELETE, DROP, SELECT, INSERT ON *.* TO 'roundcube'@'localhost';" >>/jk/kk.sql
  # echo "FLUSH PRIVILEGES;" >>/jk/kk.sql

  echo "CREATE DATABASE IF NOT EXISTS trojan;" >/jk/kk.sql
  echo "CREATE DATABASE IF NOT EXISTS netdata;" >>/jk/kk.sql
  echo "CREATE DATABASE IF NOT EXISTS roundcubemail;" >>/jk/kk.sql
  echo "CREATE USER IF NOT EXISTS 'netdata'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  echo "CREATE USER IF NOT EXISTS 'trojan'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  echo "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '${password1}';" >>/jk/kk.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'netdata'@'localhost';" >>/jk/kk.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'trojan'@'localhost';" >>/jk/kk.sql
  echo "GRANT ALL PRIVILEGES ON *.* TO 'roundcube'@'localhost';" >>/jk/kk.sql
  echo "FLUSH PRIVILEGES;" >>/jk/kk.sql
fi

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
    echo "redis写入执行完毕"
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
    restart: always
    ports:
      - "6379:6379"
      # - "6378:6379"
    volumes:
      - "/etc/redis/data:/data"
      - "../etc/redis/redis.conf:/data/redis.conf"
      # - "/var/run/redis/redis.sock:/tmp/redis.sock"
    command: redis-server /data/redis.conf
      
  miniflux:
    # 8280
    image: miniflux/miniflux:latest
    container_name: miniflux
    restart: always
    ports:
      - "8280:8080"
    depends_on:
      - postgresqldb
    environment:
      - DATABASE_URL=postgresql://miniflux:adminadmin@localhost/miniflux?sslmode=disable
      - BASE_URL=https://${domain}/miniflux/
      - RUN_MIGRATIONS=1
      - CREATE_ADMIN=1
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=adminadmin

  postgresqldb:
    container_name: postgresqldb
    image: postgres:latest
    restart: always
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
    container_name: nextcloud
    restart: always
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
      - DOMAIN=https://${domain}/nextcloud/
      - DB_TYPE=mysql
      - DB_NAME=nextcloud
      - DB_USER=nextcloud
      - DB_PASSWORD="${password1}"
      - NEXTCLOUD_ADMIN_USER="admin"
      - NEXTCLOUD_ADMIN_PASSWORD="${password1}"
      - DB_HOST=db
    ports:
      - 12222:80
    volumes:
      - nextcloud:/var/www/html
      # - "/nextcloud/config/config.php:/var/www/html/data"
      # - "/usr/share/nginx/nextcloud/config:/var/www/html/config" 
      # - "/usr/share/nginx/nextcloud/apps:/var/www/html/custom_apps"

  db:
    image: mariadb:latest
    container_name: mariadb
    restart: always
    volumes:
      - db:/var/lib/mysql
      - "../jk/kk.sql:/docker-entrypoint-initdb.d/kk.sql"
      # - /etc/localtime:/etc/localtime
    ports:
      - 3306:3306
    environment:
      - MYSQL_ROOT_PASSWORD="${password1}"
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD="${password1}"
      - TZ="Asia/Shanghai"
    command: ['--character-set-server=utf8mb4', '--collation-server=utf8mb4_unicode_ci', '--transaction-isolation=READ-COMMITTED', '--binlog-format=ROW', '--default-storage-engine=innodb','--max-connections=1000','--max-connections=1000']
    healthcheck:
      test: mysqladmin -p${password1} ping -h localhost
      interval: 20s
      start_period: 10s
      timeout: 10s
      retries: 3
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
  # rm -rf /jk
}
