#!/usr/bin/env bash
# VPSTOOLBOX

# 一键安装Trojan-GFW代理,Hexo博客,Nextcloud等應用程式.
# One click install Trojan-gfw Hexo Nextcloud and so on.

# MIT License
#
# Copyright (c) 2019-2022 JohnRosen

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#如果你在使用VPSToolBox时遇到任何问题,请仔细阅读README.md/code或者**通过 [Telegram](https://t.me/vpstoolbox_chat)请求支援** !

clear

set +e

## Predefined env
export DEBIAN_FRONTEND=noninteractive
export COMPOSER_ALLOW_SUPERUSER=1

#System Requirement
if [[ $(id -u) != 0 ]]; then
  echo -e "请使用root或者sudo用户运行,Please run this script as root or sudoer."
  exit 1
fi

# ----------------------------------
# Colors
# ----------------------------------
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'
###Legacy Defined Colors
ERROR="31m"   # Error message
SUCCESS="32m" # Success message
WARNING="33m" # Warning message
INFO="36m"    # Info message
LINK="92m"    # Share Link Message

#Predefined install,do not change!!!
install_bbr=1
install_socat=1
install_nodejs=1
install_trojan=1
trojanport="443"
tcp_fastopen="true"

#Disable cloud-init
rm -rf /lib/systemd/system/cloud*

colorEcho() {
  COLOR=$1
  echo -e "\033[${COLOR}${@:2}\033[0m"
}

#设置系统语言
setlanguage() {
  mkdir /root/.trojan/
  mkdir /etc/certs/
  chattr -i /etc/locale.gen
  cat >'/etc/locale.gen' <<EOF
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
en_US.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
EOF
  locale-gen
  update-locale
  chattr -i /etc/default/locale
  cat >'/etc/default/locale' <<EOF
LANGUAGE="zh_CN.UTF-8"
LANG="zh_CN.UTF-8"
LC_ALL="zh_CN.UTF-8"
EOF
  export LANGUAGE="zh_CN.UTF-8"
  export LANG="zh_CN.UTF-8"
  export LC_ALL="zh_CN.UTF-8"
}

## 写入配置文件
prasejson() {
  set +e
  cat >'/root/.trojan/config.json' <<EOF
{
  "installed": "1",
  "trojanport": "${trojanport}",
  "domain": "$domain",
  "password1": "$password1",
  "password2": "$password2",
  "filepath": "$filepath",
  "check_trojan": "$check_trojan",
  "check_dns": "$check_dns",
  "check_dockereverything": "$check_dockereverything",
  "check_file": "$check_file",
  "check_fail2ban": "$check_fail2ban",
  "fastopen": "${fastopen}"
}
EOF
}

## 读取配置文件
readconfig() {
  domain="$(jq -r '.domain' "/root/.trojan/config.json")"
  trojanport="$(jq -r '.trojanport' "/root/.trojan/config.json")"
  password2="$(jq -r '.password2' "/root/.trojan/config.json")"
  password1="$(jq -r '.password1' "/root/.trojan/config.json")"
  filepath="$(jq -r '.filepath' "/root/.trojan/config.json")"
  check_trojan="$(jq -r '.check_trojan' "/root/.trojan/config.json")"
  check_dns="$(jq -r '.check_dns' "/root/.trojan/config.json")"
  check_dockereverything="$(jq -r '.check_dockereverything' "/root/.trojan/config.json")"
  check_file="$(jq -r '.check_file' "/root/.trojan/config.json")"
  check_fail2ban="$(jq -r '.check_fail2ban' "/root/.trojan/config.json")"
  fastopen="$(jq -r '.fastopen' "/root/.trojan/config.json")"
}

## 清理apt以及模块化的.sh文件等
clean_env() {
  prasejson
  apt-get autoremove -y
  cd /root
  if [[ -n ${uuid_new} ]]; then
    echo "vless://${uuid_new}@${myip}:${trojanport}?mode=multi&security=tls&type=grpc&serviceName=${path_new}&sni=${domain}#Vless(${route_final} ${mycountry} ${mycity} ${myip} ${myipv6})"
    echo "trojan://${password1}@${myip}:${trojanport}?security=tls&headerType=none&type=tcp&sni=${domain}#Trojan(${route_final}${mycountry} ${mycity} ${myip} ${myipv6})"
  else
    echo "trojan://${password1}@${myip}:${trojanport}?security=tls&headerType=none&type=tcp&sni=${domain}#Trojan(${route_final}${mycountry} ${mycity} ${myip} ${myipv6})"
  fi
  cd
  if [[ ${install_dnscrypt} == 1 ]]; then
    if [[ ${dist} = ubuntu ]]; then
      systemctl stop systemd-resolved
      systemctl disable systemd-resolved
    fi
    if [[ $(systemctl is-active dnsmasq) == active ]]; then
      systemctl disable dnsmasq
    fi
    echo "nameserver 127.0.0.1" >/etc/resolv.conf
    systemctl restart dnscrypt-proxy
    echo "nameserver 127.0.0.1" >/etc/resolvconf/resolv.conf.d/base
    resolvconf -u
  fi
  cd
  rm -rf /root/*.sh
  # rm -rf /usr/share/nginx/*.sh
  clear
}

## 检测系统是否支援
initialize() {
  set +e
  TERM=ansi whiptail --title "初始化中(initializing)" --infobox "初始化中...(initializing)" 7 68
  if [[ -f /etc/sysctl.d/60-disable-ipv6.conf ]]; then
    mv /etc/sysctl.d/60-disable-ipv6.conf /etc/sysctl.d/60-disable-ipv6.conf.bak
  fi
  if cat /etc/*release | grep ^NAME | grep -q Ubuntu; then
    dist="ubuntu"
    if [[ -f /etc/sysctl.d/60-disable-ipv6.conf.bak ]]; then
      sed -i 's/#//g' /etc/netplan/01-netcfg.yaml
      netplan apply
    fi
    apt-get update
    apt-get install sudo whiptail curl dnsutils locales jq socat -y #lsb-release
  elif cat /etc/*release | grep ^NAME | grep -q Debian; then
    dist="debian"
    apt-get update
    apt-get install sudo whiptail curl dnsutils locales jq -y #lsb-release
  else
    whiptail --title "操作系统不支援 OS incompatible" --msgbox "请使用Debian或者Ubuntu运行 Please use Debian or Ubuntu to run" 8 68
    echo "操作系统不支援,请使用Debian或者Ubuntu运行 Please use Debian or Ubuntu."
    exit 1
  fi

  ## 卸载腾讯云云盾

  rm -rf /usr/local/sa
  rm -rf /usr/local/agenttools
  rm -rf /usr/local/qcloud
  rm -rf /usr/local/telescope
  #挂载目录

  # mkdir -p /dockercontainer/nextcloud

  ## 卸载阿里云云盾
  cat /etc/apt/sources.list | grep aliyun &>/dev/null

  if [[ $? == 0 ]] || [[ -d /usr/local/aegis ]]; then
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/uninstall-aegis.sh
    source uninstall-aegis.sh
    uninstall_aegis
  fi
}

## 初始化安装
install_initial() {
  clear
  if [[ -f /root/.trojan/config.json ]]; then
    install_status="$(jq -r '.installed' "/root/.trojan/config.json")"
  fi

  if [[ $install_status != 1 ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak1
    if [[ $(systemctl is-active caddy) == active ]]; then
      systemctl disable caddy --now
    fi
    if [[ $(systemctl is-active apache2) == active ]]; then
      systemctl disable apache2 --now
    fi
    if [[ $(systemctl is-active httpd) == active ]]; then
      systemctl disable httpd --now
    fi
  fi
  curl --ipv4 --retry 5 -s https://ipinfo.io?token=7f89388c8c439f --connect-timeout 300 >/root/.trojan/ip.json
  myip="$(jq -r '.ip' "/root/.trojan/ip.json")"
  mycountry="$(jq -r '.country' "/root/.trojan/ip.json")"
  mycity="$(jq -r '.city' "/root/.trojan/ip.json")"
  localip=$(ip -4 a | grep inet | grep "scope global" | awk '{print $2}' | cut -d'/' -f1)
  myipv6=$(ip -6 a | grep inet6 | grep "scope global" | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
}

## 安装基础软件
install_base() {
  set +e
  TERM=ansi whiptail --title "安装中" --infobox "安装基础软件中..." 7 68
  # if [[ ${install_dockereverything} == 1 ]]; then
  #   apt upgrade -y
  # fi
  colorEcho ${INFO} "Installing all necessary Software"
  apt-get install sudo git curl xz-utils wget apt-transport-https unzip resolvconf ntpdate systemd dbus ca-certificates locales iptables cron socat -y #libcap2-bin lsb-release
  sh -c 'echo "y\n\ny\ny\n" | DEBIAN_FRONTEND=noninteractive apt-get install ntp -q -y'
  clear
}

## 安装具体软件
install_moudles() {
  curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/bbr.sh
  source bbr.sh
  install_bbr
  if [[ ${install_docker} == 1 ]]; then
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/docker.sh
    source docker.sh
    install_docker
  fi
  if [[ ${install_grpc} == 1 ]]; then
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/grpc.sh
    source grpc.sh
    install_grpc
  fi
  if [[ ${install_fail2ban} == 1 ]]; then
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/fail2ban.sh
    source fail2ban.sh
    install_fail2ban
  fi
  if [[ 1 == 1 ]]; then
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/dockereverything.sh
    source dockereverything.sh
    install_dockereverything
  fi
  # Install Trojan-gfw
  curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/trojan.sh
  source trojan.sh
  install_trojan
  curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/route.sh
  source route.sh
  route_test
}

## 主菜单
MasterMenu() {
  Mainmenu=$(whiptail --clear --ok-button "选择完毕,下一步" --backtitle "Hi,欢迎使用VPSTOOLBOX。https://github.com/johnrosen1/vpstoolbox / https://t.me/vpstoolbox_chat。" --title "VPS ToolBox Menu" --menu --nocancel "Welcome to VPS Toolbox main menu,Please Choose an option 欢迎使用VPSTOOLBOX,请选择一个选项" 14 68 5 \
    "Install_extend" "安裝" \
    "Benchmark" "效能测试" \
    "Uninstall" "卸载" \
    "Exit" "退出" 3>&1 1>&2 2>&3)
  case $Mainmenu in
  ## 扩展安装
  Install_extend)
    ## 初始化安装
    install_initial
    echo "nameserver 1.1.1.1" >/etc/resolv.conf
    echo "nameserver 1.0.0.1" >>/etc/resolv.conf
    ## 用户输入
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/userinput.sh
    source userinput.sh
    userinput_full
    prasejson
    ## 检测证书是否已有
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/detectcert.sh
    source detectcert.sh
    detectcert
    ## 开始安装
    TERM=ansi whiptail --title "开始安装" --infobox "安装开始,请不要按任何按键直到安装完成(Please do not press any button until the installation is completed)!" 7 68
    colorEcho ${INFO} "安装开始,请不要按任何按键直到安装完成(Please do not press any button until the installation is completed)!"
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/system-upgrade.sh
    source system-upgrade.sh
    upgrade_system
    ## 基础软件安装
    install_base
    echo "nameserver 1.1.1.1" >/etc/resolv.conf
    echo "nameserver 1.0.0.1" >>/etc/resolv.conf
    ## 开启防火墙
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/firewall.sh
    source firewall.sh
    openfirewall
    # ## 安装NGINX
    # curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/nginx.sh
    # source nginx.sh
    # install_nginx
    ## 证书签发
    echo "nameserver 1.1.1.1" >/etc/resolv.conf
    echo "nameserver 1.0.0.1" >>/etc/resolv.conf
    # curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/issuecert.sh
    # source issuecert.sh
    ## HTTP证书签发
    # if [[ ${httpissue} == 1 ]]; then
    #   http_issue
    # fi
    ## DNS API证书签发
    # if [[ ${dnsissue} == 1 ]]; then
    #   dns_issue
    # fi
    ## 具体软件安装
    install_moudles
    echo "nameserver 1.1.1.1" >/etc/resolv.conf
    echo "nameserver 1.0.0.1" >>/etc/resolv.conf
    # curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/nginx-config.sh
    # source nginx-config.sh
    # nginx_config
    clean_env
    # 初始化Nextcloud
    curl 127.0.0.1:12222
    sleep 20s

    # 输出结果
    echo "nameserver 1.1.1.1" >/etc/resolv.conf
    echo "nameserver 1.0.0.1" >>/etc/resolv.conf
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/output.sh
    source output.sh
    prase_output
    rm output.sh
    exit 0
    ;;
  Benchmark)
    clear
    if (whiptail --title "测试模式" --yes-button "快速测试" --no-button "完整测试" --yesno "效能测试方式(fast or full)?" 8 68); then
      curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s fast
    else
      curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s full
    fi
    exit 0
    ;;
  Exit)
    whiptail --title "Bash Exited" --msgbox "Goodbye" 8 68
    exit 0
    ;;
  Uninstall)
    curl --retry 5 -LO https://raw.githubusercontent.com/MoeSinon/vp/master/havedocker/uninstall.sh
    source uninstall.sh
    uninstall
    exit 0
    ;;
  esac
}
cd /root
clear
initialize
setlanguage
clear
MasterMenu
