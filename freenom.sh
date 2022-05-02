# !/usr/bin/env bash

# freenom模组 freenom moudle

set +e

install_freenom() {
    cd
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
    cd /usr
    mkdir -p /usr/freenom/conf
    mkdir -p /usr/freenom/logs
    cd /usr/freenom
    cat >'docker-compose.yml' <<EOF
version: "3.8"
services:
  freenom:
    image: luolongfei/freenom:latest
    container_name: freenom
    restart: always
    volumes:
      - "/usr/freenom/conf:/conf"
      - "/usr/freenom/logs:/app/logs"

EOF
    docker-compose up -d
    cd
    sed -i "s/FREENOM_USERNAME=''/FREENOM_USERNAME=${idcard}/g" /usr/freenom/conf.env
    sed -i "s/FREENOM_PASSWORD=''/FREENOM_PASSWORD=${passw}/g" /usr/freenom/conf.env
    sed -i "s/TELEGRAM_CHAT_ID=''/TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}/g" /usr/freenom/conf.env
    sed -i "s/TELEGRAM_BOT_TOKEN=''/TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}/g" /usr/freenom/conf.env
    sed -i "s/TELEGRAM_BOT_ENABLE=0/TELEGRAM_BOT_ENABLE=1/g" /usr/freenom/conf.env
    docker restart freenom
    # if grep -q "unixsocket /var/run/redis/redis.sock" /etc/redis/redis.conf; then
    #     :
    # else
    #     echo "" >>/etc/redis/redis.conf
    #     echo "unixsocket /var/run/redis/redis.sock" >>/etc/redis/redis.conf
    #     echo "unixsocketperm 770" >>/etc/redis/redis.conf
    # fi
    # systemctl enable redis-server
    # systemctl restart redis-server
    cd
}
