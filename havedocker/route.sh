#!/usr/bin/env bash

## 路由追踪模组

set +e

apt-get -y install traceroute

routes=(AS4134 AS4837 AS9808 AS4538 AS4809 AS9929 AS2914 AS2497 AS2516 AS4725 AS3491 AS9269 AS4635 AS4760 AS58453 AS4637 AS64050 AS6939 AS174 AS3356 AS3257 AS6461 AS701 AS7018 AS1239 AS1299 AS6453 AS6830 AS5511 AS6762 AS3320)
routes_name=(163 169 CMNET CERNET CN2 CU-VIP NTT IIJ KDDI SoftBank PCCW HKBN HKIX HKT CMI Telstra BGPNET HE Cogent LEVEL3 GTT Zayo Verizon ATT T-Mobile Arelion TATA Liberty Orange SPARKLE Deutsche)

ct_ip="116.228.111.118"
cu_ip="210.22.70.3"
cm_ip="211.136.112.50"
inet_ip="1.1.1.1"

route_test() {

    TERM=ansi whiptail --title "路由测试" --infobox "路由测试，请耐心等待。" 7 68

    traceroute ${inet_ip} -n -T -m 25 -w 3 | tail -n +2 &>route_all.txt
    traceroute ${ct_ip} -n -T -m 25 -w 3 | tail -n +2 &>route_all.txt
    traceroute ${cu_ip} -n -T -m 25 -w 3 | tail -n +2 &>>route_all.txt
    traceroute ${cm_ip} -n -T -m 25 -w 3 | tail -n +2 &>>route_all.txt

    ips=()
    asns=()
    route_vps=()

    while IFS="" read -r p || [ -n "$p" ]; do
        ip=$(printf '%s\n' "$p" | cut -d' ' -f4)
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ips+=($ip)
        fi
    done <route_all.txt

    for ip in "${ips[@]}"; do
        asns+=($(curl --retry 5 -s https://ipinfo.io/${ip}/org?token=7f89388c8c439f --connect-timeout 300 | cut -d' ' -f1))
        if [[ $ip = 59.43* ]]; then
            route_vps+=(AS4809)
        fi
    done

    for asn in "${asns[@]}"; do
        for route in "${routes[@]}"; do
            if echo "$asn" | grep -q "$route"; then
                route_vps+=($route)
            fi
        done
    done

    rm route_all.txt
    rm route.txt &>/dev/null

    for i in "${!route_vps[@]}"; do
        for o in "${!routes[@]}"; do
            if [[ "${route_vps[$i]}" == "${routes[$o]}" ]]; then
                echo "${routes_name[$o]}" >>route.txt
            fi
        done
    done

    route_final=$(cat route.txt | sort | uniq | tr '\n' ' ')

    echo $route_final

    rm route.txt
}
