#!/usr/bin/env bash

## 用户输入模组 User Input moudle

set +e

userinput_full() {
  set +e
  clear
  if [[ ${install_status} == 1 ]]; then
    if (whiptail --title "Installed" --yes-button "读取" --no-button "修改" --yesno "检测到现有配置，读取/修改现有配置?(Installed,read configuration?)" 8 68); then
      readconfig
    fi
  fi

  if [[ -z ${check_trojan} ]]; then
    check_trojan="on"
  fi
  if [[ -z ${check_dns} ]]; then
    check_dns="off"
  fi
  if [[ -z ${check_dockereverything} ]]; then
    check_dockereverything="on"
  fi
  if [[ -z ${check_file} ]]; then
    check_file="off"
  fi
  if [[ -z ${check_fail2ban} ]]; then
    check_fail2ban="on"
  fi
  if [[ -z ${fastopen} ]]; then
    fastopen="on"
  fi

  whiptail --clear --ok-button "下一步" --backtitle "Hi,请按空格以及方向键来选择需要安装/更新的软件,请自行下拉以查看更多(Please press space and Arrow keys to choose)" --title "Install checklist" --checklist --separate-output --nocancel "请按空格及方向键来选择需要安装/更新的软件。" 24 65 16 \
    "Back" "返回上级菜单(Back to main menu)" off \
    "基础" "基础" on \
    "trojan" "Trojan-GFW+TCP-BBR" on \
    "grpc" "Vless+gRPC+TLS(支持CDN)" off \
    "port" "自定义Trojan-GFW/Vless(grpc)端口" off \
    \
    \
    "check_dockereverything" "check_dockereverything" ${check_dockereverything} \
    "13" "Qbt原版+高性能Tracker+Filebrowser" off 2>results # "alist" "alist网盘管理器" on \
  # "speed" "Speedtest(测试本地网络到VPS的延迟及带宽)" ${check_speed} \
  # "nextcloud" "Nextcloud(私人网盘)" ${check_cloud} \

  while read choice; do
    case $choice in
    Back)
      MasterMenu
      break
      ;;
    trojan)
      install_trojan=1
      install_bbr=1
      ;;
    # alist)
    #   # install_hexo=0
    #   install_alist=1
    #   ;;
    dns)
      check_dns="on"
      install_dnscrypt=1
      ;;
    grpc)
      install_grpc=1
      ;;
    check_dockereverything)
      check_dockereverything="on"
      install_docker=1
      ;;
    port)
      trojan_other_port=1
      ;;
    *) ;;
    esac
  done <results

  rm results

  if [[ ${trojan_other_port} == 1 ]]; then
    trojanport=$(whiptail --inputbox --nocancel "Trojan-GFW 端口(若不確定，請直接回車)" 8 68 443 --title "port input" 3>&1 1>&2 2>&3)
    if [[ -z ${trojanport} ]]; then
      trojanport="443"
    fi
  fi

  while [[ -z ${domain} ]]; do
    domain=$(whiptail --inputbox --nocancel "请輸入你的域名,例如 example.com(请先完成A/AAAA解析) | Please enter your domain" 8 68 --title "Domain input" 3>&1 1>&2 2>&3)
  done
  clear
  #hostnamectl set-hostname ${domain}
  #echo "${domain}" > /etc/hostname
  rm -rf /etc/dhcp/dhclient.d/google_hostname.sh
  rm -rf /etc/dhcp/dhclient-exit-hooks.d/google_set_hostname
  #echo "" >> /etc/hosts
  #echo "$(jq -r '.ip' "/root/.trojan/ip.json") ${domain}" >> /etc/hosts
  if [[ ${install_trojan} = 1 ]]; then
    while [[ -z ${password1} ]] || [[ ${n} > 30 ]]; do
      password1=$(whiptail --passwordbox --nocancel "VPSToolBox系统主密码 (**最长30字符，请勿添加特殊符号**)" 8 68 --title "设置主系统密码" 3>&1 1>&2 2>&3)
      n=${#password1}
      if [[ ${n} == 0 ]]; then
        password1=$(
          head /dev/urandom | tr -dc a-z0-9 | head -c 6
          echo ''
        )
      fi
      if [[ ${n} > 30 ]]; then
        password1=""
      fi
    done
    while [[ -z ${password2} ]]; do
      password2=$(
        head /dev/urandom | tr -dc a-z0-9 | head -c 6
        echo ''
      )
    done
  fi
  if [[ ${password1} == ${password2} ]]; then
    password2=$(
      head /dev/urandom | tr -dc a-z0-9 | head -c 6
      echo ''
    )
  fi
  if [[ -z ${password1} ]]; then
    password1=$(
      head /dev/urandom | tr -dc a-z0-9 | head -c 6
      echo ''
    )
  fi
  if [[ -z ${password2} ]]; then
    password2=$(
      head /dev/urandom | tr -dc a-z0-9 | head -c 6
      echo ''
    )
  fi
}
