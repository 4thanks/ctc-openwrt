#!/bin/sh

LOG_FILE='/var/log/cloudflarespeedtest.log'
IP_FILE='/usr/share/cloudflarespeedtestresult.txt'
IPV4_TXT='/usr/share/CloudflareSpeedTest/ip.txt'
IPV6_TXT='/usr/share/CloudflareSpeedTest/ipv6.txt'

CLOUDFRONT_IP_FILE='/usr/share/cloudfrontspeedtestresult.txt'
CLOUDFRONT_IPV4_TXT='/usr/share/mosdns/cloudfront_ipv4.txt'
CLOUDFRONT_IPV6_TXT='/usr/share/mosdns/cloudfront_ipv6.txt'
CLOUDFRONT_URL='https://images-assets.nasa.gov/video/GSFC_20100722_Hubble_m10619_Exoplanets/GSFC_20100722_Hubble_m10619_Exoplanets~orig.mp4'

function get_global_config(){
    while [[ "$*" != "" ]]; do
        eval ${1}='`uci get cloudflarespeedtest.global.$1`' 2>/dev/null
        shift
    done
}

function get_servers_config(){
    while [[ "$*" != "" ]]; do
        eval ${1}='`uci get cloudflarespeedtest.servers.$1`' 2>/dev/null
        shift
    done
}

echolog() {
    local d="$(date "+%Y-%m-%d %H:%M:%S")"
    echo -e "$d: $*"
    echo -e "$d: $*" >>$LOG_FILE
}

function read_config(){
    get_global_config "enabled" "speed" "custome_url" "threads" "custome_cors_enabled" "custome_cron" "t" "tp" "dt" "dn" "dd" "tl" "tll" "ipv6_enabled" "advanced" "proxy_mode"
    get_servers_config "ssr_services" "ssr_enabled" "passwall_enabled" "passwall_services" "passwall2_enabled" "passwall2_services" "bypass_enabled" "bypass_services" "vssr_enabled" "vssr_services" "DNS_enabled" "HOST_enabled" "MosDNS_enabled" "openclash_restart"
}

function appinit(){
    ssr_started='';
    passwall_started='';
    passwall2_started='';
    bypass_started='';
    vssr_started='';
}

function speed_test(){

    rm -rf $LOG_FILE

    command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${custome_url} -o ${IP_FILE}"

    if [ $ipv6_enabled -eq "1" ] ;then
        command="${command} -f ${IPV6_TXT}"
    else
        command="${command} -f ${IPV4_TXT}"
    fi

    if [ $advanced -eq "1" ] ; then
        command="${command} -tl ${tl} -tll ${tll} -n ${threads} -t ${t} -dt ${dt} -dn ${dn}"
        if [ $dd -eq "1" ] ; then
            command="${command} -dd"
        fi
        if [ $tp -ne "443" ] ; then
            command="${command} -tp ${tp}"
        fi
    else
        command="${command} -tl 200 -tll 40 -n 200 -t 4 -dt 10 -dn 1"
    fi

    appinit

    ssr_original_server=$(uci get shadowsocksr.@global[0].global_server 2>/dev/null)
    ssr_original_run_mode=$(uci get shadowsocksr.@global[0].run_mode 2>/dev/null)
    if [ "x${ssr_original_server}" != "xnil" ] && [ "x${ssr_original_server}"  !=  "x" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set shadowsocksr.@global[0].global_server="nil"
            elif  [ $proxy_mode  == "gfw" ] ;then
            uci set shadowsocksr.@global[0].run_mode="gfw"
        fi
        ssr_started='1';
        uci commit shadowsocksr
        /etc/init.d/shadowsocksr restart
    fi

    passwall_server_enabled=$(uci get passwall.@global[0].enabled 2>/dev/null)
    passwall_original_run_mode=$(uci get passwall.@global[0].tcp_proxy_mode 2>/dev/null)
    if [ "x${passwall_server_enabled}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set passwall.@global[0].enabled="0"
            elif  [ $proxy_mode  == "gfw" ] ;then
            uci set passwall.@global[0].tcp_proxy_mode="gfwlist"
        fi
        passwall_started='1';
        uci commit passwall
        /etc/init.d/passwall  restart 2>/dev/null
    fi

    passwall2_server_enabled=$(uci get passwall2.@global[0].enabled 2>/dev/null)
    passwall2_original_run_mode=$(uci get passwall2.@global[0].tcp_proxy_mode 2>/dev/null)
    if [ "x${passwall2_server_enabled}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set passwall2.@global[0].enabled="0"
            elif  [ $proxy_mode  == "gfw" ] ;then
            uci set passwall2.@global[0].tcp_proxy_mode="gfwlist"
        fi
        passwall2_started='1';
        uci commit passwall2
        /etc/init.d/passwall2 restart 2>/dev/null
    fi

    vssr_original_server=$(uci get vssr.@global[0].global_server 2>/dev/null)
    vssr_original_run_mode=$(uci get vssr.@global[0].run_mode 2>/dev/null)
    if [ "x${vssr_original_server}" != "xnil" ] && [ "x${vssr_original_server}"  !=  "x" ] ;then

        if [ $proxy_mode  == "close" ] ;then
            uci set vssr.@global[0].global_server="nil"
            elif  [ $proxy_mode  == "gfw" ] ;then
            uci set vssr.@global[0].run_mode="gfw"
        fi
        vssr_started='1';
        uci commit vssr
        /etc/init.d/vssr restart
    fi

    bypass_original_server=$(uci get bypass.@global[0].global_server 2>/dev/null)
    bypass_original_run_mode=$(uci get bypass.@global[0].run_mode 2>/dev/null)
    if [ "x${bypass_original_server}" != "x" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set bypass.@global[0].global_server=""
            elif  [ $proxy_mode  == "gfw" ] ;then
            uci set bypass.@global[0].run_mode="gfw"
        fi
        bypass_started='1';
        uci commit bypass
        /etc/init.d/bypass restart
    fi

    if [ "x${MosDNS_enabled}" == "x1" ] ;then
        # 先检查 UCI 配置
        if [ -n "$(grep 'option cloudflare\|list cloudflare_ip' /etc/config/mosdns)" ]; then
            if [ -n "$(grep 'option cloudflare' /etc/config/mosdns)" ]; then
                sed -i".bak" "/option cloudflare/d" /etc/config/mosdns
            fi
            if [ -n "$(grep 'list cloudflare_ip' /etc/config/mosdns)" ]; then
                sed -i".bak" "/list cloudflare_ip/d" /etc/config/mosdns
            fi
            sed -i '/^$/d' /etc/config/mosdns && echo -e "\toption cloudflare '1'\n\tlist cloudflare_ip '$bestip'" >> /etc/config/mosdns
            
            # UCI 配置更新后立即重启
            /etc/init.d/mosdns restart &>/dev/null
            if [ "x${openclash_restart}" == "x1" ] ;then
                /etc/init.d/openclash restart &>/dev/null
            fi
            echolog "MosDNS UCI配置更新完成"
            
        # 如果没有 UCI 配置，检查 YAML 配置
        elif [ -f "/etc/mosdns/config_custom.yaml" ]; then
            echolog "未找到 UCI 配置，检查到 YAML 配置文件存在"
            need_restart=0
            
            # 检查配置块
            current_ips=$(awk '
                /[[:space:]]*- matches: ["'\'']resp_ip \$cf_ip_v4v6["'\'']/ {
                    p=NR+1
                    found_cf=1
                    next
                }
                NR==p && /[[:space:]]*exec: black_hole/ {
                    if(found_cf==1) {
                        print $0
                        exit 0
                    }
                }
                END {
                    if(found_cf!=1) exit 1
                }
            ' /etc/mosdns/config_custom.yaml | sed 's/.*black_hole\s\+\(.*\)/\1/')

            if [ $? -eq 0 ] && [ ! -z "$current_ips" ]; then
                echolog "找到配置块，检查是否需要更新..."
                first_ip=$(echo "$current_ips" | awk '{print $1}')
                if [ "$first_ip" != "$bestip" ]; then
                    # 备份配置（如果还没有备份）
                    if [ ! -f "/etc/mosdns/config_custom.yaml.bak" ]; then
                        cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
                    fi
                    
                    # 更新配置
                    ip_count=$(echo "$current_ips" | wc -w)
                    if [ $ip_count -eq 0 ]; then
                        new_ip_list="$bestip"
                    elif [ $ip_count -eq 1 ]; then
                        new_ip_list="$bestip $current_ips"
                    else
                        keep_ips=$(echo "$current_ips" | tr ' ' '\n' | head -n 2 | tr '\n' ' ')
                        new_ip_list="$bestip $keep_ips"
                    fi
                    
                    # 更新 black_hole IP 列表
                    sed -i "/resp_ip \$cf_ip_v4v6/,+1{/black_hole/{s/black_hole.*/black_hole $new_ip_list/}}" /etc/mosdns/config_custom.yaml
                    echolog "MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
                    need_restart=1
                fi
            fi

            # 如果有配置更新，重启服务
            if [ "$need_restart" = "1" ]; then
                /etc/init.d/mosdns restart &>/dev/null
                if [ "x${openclash_restart}" == "x1" ] ;then
                    /etc/init.d/openclash restart &>/dev/null
                fi
            fi
        else
            echolog "未找到任何 MosDNS 配置文件"
        fi
    fi

    echo $command  >> $LOG_FILE 2>&1
    echolog "-----------start----------"
    $command >> $LOG_FILE 2>&1
    echolog "-----------end------------"
}

function ip_replace(){

    # 获取最快 IP（从 result.csv 结果文件中获取第一个 IP）
    bestip=$(sed -n "2,1p" $IP_FILE | awk -F, '{print $1}')
    if [[ -z "${bestip}" ]]; then
        echolog "CloudflareST 测速结果 IP 数量为 0,跳过下面步骤..."
    else
        host_ip
        mosdns_ip
        alidns_ip
        ssr_best_ip
        vssr_best_ip
        bypass_best_ip
        passwall_best_ip
        passwall2_best_ip
        restart_app

    fi
}

function host_ip() {
    if [ "x${HOST_enabled}" == "x1" ] ;then
        get_servers_config "host_domain"
        HOSTS_LINE=$(echo "$host_domain" | sed 's/,/ /g' | sed "s/^/$bestip /g")
        host_domain_first=$(echo "$host_domain" | awk -F, '{print $1}')

        if [ -n "$(grep $host_domain_first /etc/hosts)" ]
        then
            echo $host_domain_first
            sed -i".bak" "/$host_domain_first/d" /etc/hosts
            echo $HOSTS_LINE >> /etc/hosts;
        else
            echo $HOSTS_LINE >> /etc/hosts;
        fi
        /etc/init.d/dnsmasq reload &>/dev/null
        echolog "HOST 完成"
    fi
}

function mosdns_ip() {
    if [ "x${MosDNS_enabled}" == "x1" ] ;then
        echolog "开始处理 MosDNS 配置..."
        
        # 先检查 UCI 配置
        if [ -n "$(grep 'option cloudflare\|list cloudflare_ip' /etc/config/mosdns)" ]; then
            echolog "找到 UCI 配置，开始处理..."
            if [ -n "$(grep 'option cloudflare' /etc/config/mosdns)" ]; then
                sed -i".bak" "/option cloudflare/d" /etc/config/mosdns
            fi
            if [ -n "$(grep 'list cloudflare_ip' /etc/config/mosdns)" ]; then
                sed -i".bak" "/list cloudflare_ip/d" /etc/config/mosdns
            fi
            sed -i '/^$/d' /etc/config/mosdns && echo -e "\toption cloudflare '1'\n\tlist cloudflare_ip '$bestip'" >> /etc/config/mosdns
            
            # UCI 配置更新后立即重启
            /etc/init.d/mosdns restart &>/dev/null
            if [ "x${openclash_restart}" == "x1" ] ;then
                /etc/init.d/openclash restart &>/dev/null
            fi
            echolog "MosDNS UCI配置更新完成"
            
        # 如果没有 UCI 配置，检查 YAML 配置
        elif [ -f "/etc/mosdns/config_custom.yaml" ]; then
            echolog "未找到 UCI 配置，检查到 YAML 配置文件存在"
            need_restart=0
            
            # 检查配置块
            current_ips=$(awk '
                /[[:space:]]*- matches: ["'\'']resp_ip \$cf_ip_v4v6["'\'']/ {
                    p=NR+1
                    found_cf=1
                    next
                }
                NR==p && /[[:space:]]*exec: black_hole/ {
                    if(found_cf==1) {
                        print $0
                        exit 0
                    }
                }
                END {
                    if(found_cf!=1) exit 1
                }
            ' /etc/mosdns/config_custom.yaml | sed 's/.*black_hole\s\+\(.*\)/\1/')

            if [ $? -eq 0 ] && [ ! -z "$current_ips" ]; then
                echolog "找到配置块，检查是否需要更新..."
                first_ip=$(echo "$current_ips" | awk '{print $1}')
                if [ "$first_ip" != "$bestip" ]; then
                    # 备份配置（如果还没有备份）
                    if [ ! -f "/etc/mosdns/config_custom.yaml.bak" ]; then
                        cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
                    fi
                    
                    # 更新配置
                    ip_count=$(echo "$current_ips" | wc -w)
                    if [ $ip_count -eq 0 ]; then
                        new_ip_list="$bestip"
                    elif [ $ip_count -eq 1 ]; then
                        new_ip_list="$bestip $current_ips"
                    else
                        keep_ips=$(echo "$current_ips" | tr ' ' '\n' | head -n 2 | tr '\n' ' ')
                        new_ip_list="$bestip $keep_ips"
                    fi
                    
                    # 更新 black_hole IP 列表
                    sed -i "/resp_ip \$cf_ip_v4v6/,+1{/black_hole/{s/black_hole.*/black_hole $new_ip_list/}}" /etc/mosdns/config_custom.yaml
                    echolog "MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
                    need_restart=1
                fi
            fi

            # 如果有配置更新，重启服务
            if [ "$need_restart" = "1" ]; then
                /etc/init.d/mosdns restart &>/dev/null
                if [ "x${openclash_restart}" == "x1" ] ;then
                    /etc/init.d/openclash restart &>/dev/null
                fi
            fi
        else
            echolog "未找到任何 MosDNS 配置文件"
        fi
    fi
}

function passwall_best_ip(){
    if [ "x${passwall_enabled}" == "x1" ] ;then
        echolog "设置passwall IP"
        for ssrname in $passwall_services
        do
            echo $ssrname
            uci set passwall.$ssrname.address="${bestip}"
        done
        uci commit passwall
    fi
}

function passwall2_best_ip(){
    if [ "x${passwall2_enabled}" == "x1" ] ;then
        echolog "设置passwall2 IP"
        for ssrname in $passwall2_services
        do
            echo $ssrname
            uci set passwall2.$ssrname.address="${bestip}"
        done
        uci commit passwall2
    fi
}

function ssr_best_ip(){
    if [ "x${ssr_enabled}" == "x1" ] ;then
        echolog "设置ssr IP"
        for ssrname in $ssr_services
        do
            echo $ssrname
            uci set shadowsocksr.$ssrname.server="${bestip}"
            uci set shadowsocksr.$ssrname.ip="${bestip}"
        done
        uci commit shadowsocksr
    fi
}

function vssr_best_ip(){
    if [ "x${vssr_enabled}" == "x1" ] ;then
        echolog "设置Vssr IP"
        for ssrname in $vssr_services
        do
            echo $ssrname
            uci set vssr.$ssrname.server="${bestip}"
        done
        uci commit vssr
    fi
}

function bypass_best_ip(){
    if [ "x${bypass_enabled}" == "x1" ] ;then
        echolog "设置Bypass IP"
        for ssrname in $bypass_services
        do
            echo $ssrname
            uci set bypass.$ssrname.server="${bestip}"
        done
        uci commit bypass
    fi
}

function restart_app(){
    if [ "x${ssr_started}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set shadowsocksr.@global[0].global_server="${ssr_original_server}"
            elif [ $proxy_mode  == "gfw" ] ;then
            uci set  shadowsocksr.@global[0].run_mode="${ssr_original_run_mode}"
        fi
        uci commit shadowsocksr
        /etc/init.d/shadowsocksr restart &>/dev/null
        echolog "ssr重启完成"
    fi

    if [ "x${passwall_started}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set passwall.@global[0].enabled="${passwall_server_enabled}"
            elif [ $proxy_mode  == "gfw" ] ;then
            uci set passwall.@global[0].tcp_proxy_mode="${passwall_original_run_mode}"
        fi
        uci commit passwall
        /etc/init.d/passwall restart 2>/dev/null
        echolog "passwall重启完成"
    fi

    if [ "x${passwall2_started}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set passwall2.@global[0].enabled="${passwall2_server_enabled}"
            elif [ $proxy_mode  == "gfw" ] ;then
            uci set passwall2.@global[0].tcp_proxy_mode="${passwall2_original_run_mode}"
        fi
        uci commit passwall2
        /etc/init.d/passwall2 restart 2>/dev/null
        echolog "passwall2重启完成"
    fi

    if [ "x${vssr_started}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set vssr.@global[0].global_server="${vssr_original_server}"
            elif [ $proxy_mode  == "gfw" ] ;then
            uci set vssr.@global[0].run_mode="${vssr_original_run_mode}"
        fi
        uci commit vssr
        /etc/init.d/vssr restart &>/dev/null
        echolog "Vssr重启完成"
    fi

    if [ "x${bypass_started}" == "x1" ] ;then
        if [ $proxy_mode  == "close" ] ;then
            uci set bypass.@global[0].global_server="${bypass_original_server}"
            elif [ $proxy_mode  == "gfw" ] ;then
            uci set  bypass.@global[0].run_mode="${bypass_original_run_mode}"
        fi
        uci commit bypass
        /etc/init.d/bypass restart &>/dev/null
        echolog "Bypass重启完成"
    fi
}

function alidns_ip(){
    if [ "x${DNS_enabled}" == "x1" ] ;then
        get_servers_config "DNS_type" "app_key" "app_secret" "main_domain" "sub_domain" "line"
        if [ $DNS_type == "aliyu" ] ;then
            for sub in $sub_domain
            do
                /usr/bin/cloudflarespeedtest/aliddns.sh $app_key $app_secret $main_domain $sub $line $ipv6_enabled $bestip
                echolog "更新域名${sub}阿里云DNS完成"
                sleep 1s
            done
        fi
        echo "aliyun done"
    fi
}

function test_mosdns_ip() {
    # 设置测试环境
    MosDNS_enabled="1"
    bestip="1.1.1.1"  # 测试用IP
    LOG_FILE="/tmp/cloudflare_test.log"
    openclash_restart="0"

    # 定义日志函数
    echolog() {
        local d="$(date "+%Y-%m-%d %H:%M:%S")"
        echo -e "$d: $*"
        echo -e "$d: $*" >> $LOG_FILE
    }

    # 调用原函数
    mosdns_ip
}

function speed_test_ipv6() {
    rm -rf $LOG_FILE

    command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${custome_url} -o ${IP_FILE} -f ${IPV6_TXT}"

    if [ $advanced -eq "1" ] ; then
        command="${command} -tl ${tl} -tll ${tll} -n ${threads} -t ${t} -dt ${dt} -dn ${dn}"
        if [ $dd -eq "1" ] ; then
            command="${command} -dd"
        fi
        if [ $tp -ne "443" ] ; then
            command="${command} -tp ${tp}"
        fi
    else
        command="${command} -tl 200 -tll 40 -n 200 -t 4 -dt 10 -dn 1"
    fi

    # 临时设置 ipv6_enabled 为 1
    local original_ipv6_enabled=$ipv6_enabled
    ipv6_enabled=1

    echo $command  >> $LOG_FILE 2>&1
    echolog "-----------start----------"
    $command >> $LOG_FILE 2>&1
    echolog "-----------end------------"

    # 恢复原来的 ipv6_enabled 设置
    ipv6_enabled=$original_ipv6_enabled
}

function speed_test_cloudfront(){
    rm -rf $LOG_FILE
    mkdir -p $(dirname $CLOUDFRONT_IP_FILE)

    command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${CLOUDFRONT_URL} -o ${CLOUDFRONT_IP_FILE} -f ${CLOUDFRONT_IPV4_TXT}"

    if [ $advanced -eq "1" ] ; then
        command="${command} -tl ${tl} -tll ${tll} -n ${threads} -t ${t} -dt ${dt} -dn ${dn}"
        if [ $dd -eq "1" ] ; then
            command="${command} -dd"
        fi
        if [ $tp -ne "443" ] ; then
            command="${command} -tp ${tp}"
        fi
    else
        command="${command} -tl 200 -tll 40 -n 200 -t 4 -dt 10 -dn 1"
    fi

    # 确保 IP 列表文件存在
    if [ ! -f "${CLOUDFRONT_IPV4_TXT}" ]; then
        echolog "错误：IP列表文件不存在: ${CLOUDFRONT_IPV4_TXT}"
        return 1
    fi

    echo $command  >> $LOG_FILE 2>&1
    echolog "-----------start cloudfront test----------"
    $command >> $LOG_FILE 2>&1
    echolog "-----------end cloudfront test------------"
}

function speed_v6_cloudfront(){
    rm -rf $LOG_FILE
    mkdir -p $(dirname $CLOUDFRONT_IP_FILE)

    command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${CLOUDFRONT_URL} -o ${CLOUDFRONT_IP_FILE} -f ${CLOUDFRONT_IPV6_TXT}"

    if [ $advanced -eq "1" ] ; then
        command="${command} -tl ${tl} -tll ${tll} -n ${threads} -t ${t} -dt ${dt} -dn ${dn}"
        if [ $dd -eq "1" ] ; then
            command="${command} -dd"
        fi
        if [ $tp -ne "443" ] ; then
            command="${command} -tp ${tp}"
        fi
    else
        command="${command} -tl 200 -tll 40 -n 200 -t 4 -dt 10 -dn 1"
    fi

    # 确保 IP 列表文件存在
    if [ ! -f "${CLOUDFRONT_IPV6_TXT}" ]; then
        echolog "错误：IP列表文件不存在: ${CLOUDFRONT_IPV6_TXT}"
        return 1
    fi

    echo $command  >> $LOG_FILE 2>&1
    echolog "-----------start cloudfront test----------"
    $command >> $LOG_FILE 2>&1
    echolog "-----------end cloudfront test------------"
}

function cloudfront_ip_replace(){
    if [ ! -f "$CLOUDFRONT_IP_FILE" ]; then
        echolog "CloudFront 测速结果文件不存在"
        return 1
    fi

    # 获取最快 IP
    bestip=$(sed -n "2,1p" $CLOUDFRONT_IP_FILE | awk -F, '{print $1}')
    if [[ -z "${bestip}" ]]; then
        echolog "CloudFront 测速结果 IP 数量为 0,跳过更新..."
        return 1
    fi
    
    echolog "CloudFront 测速完成，最快 IP: ${bestip}"
    update_cloudfront_ip
}

function update_cloudfront_ip() {
    if [ "x${MosDNS_enabled}" != "x1" ] ;then
        return
    fi
    
    if [ ! -f "/etc/mosdns/config_custom.yaml" ]; then
        echolog "未找到 MosDNS 配置文件"
        return 1
    fi
    
    echolog "开始处理 CloudFront MosDNS 配置..."
    need_restart=0
    
    # 使用更准确的匹配方式
    current_ips=$(awk '
        /[[:space:]]*- matches:/ {
            p=NR+3
            found_matches=1
            next
        }
        found_matches && /[[:space:]]*- "resp_ip \$cloudfront_ip"/ {
            found_cf=1
            next
        }
        NR<=p && /[[:space:]]*exec: black_hole/ {
            if(found_cf==1) {
                print $0
                exit 0
            }
        }
        END {
            if(found_cf!=1) exit 1
        }
    ' /etc/mosdns/config_custom.yaml | sed 's/.*black_hole\s\+\(.*\)/\1/')

    if [ ! -z "$current_ips" ]; then
        echolog "找到配置块，检查是否需要更新..."
        first_ip=$(echo "$current_ips" | awk '{print $1}')
        if [ "$first_ip" != "$bestip" ]; then
            # 备份配置（如果还没有备份）
            if [ ! -f "/etc/mosdns/config_custom.yaml.bak" ]; then
                cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
            fi
            
            # 更新配置
            ip_count=$(echo "$current_ips" | wc -w)
            if [ $ip_count -eq 0 ]; then
                new_ip_list="$bestip"
            elif [ $ip_count -eq 1 ]; then
                new_ip_list="$bestip $current_ips"
            else
                keep_ips=$(echo "$current_ips" | tr ' ' '\n' | head -n 2 | tr '\n' ' ')
                new_ip_list="$bestip $keep_ips"
            fi
            
            # 使用严格的替换方式，确保匹配和替换使用相同的标识符
            sed -i '
                /[[:space:]]*- matches:/,+3 {
                    /[[:space:]]*- "resp_ip \$cloudfront_ip"/,/[[:space:]]*exec: black_hole/ {
                        /exec: black_hole/ {
                            s/black_hole.*/black_hole '"$new_ip_list"'/
                        }
                    }
                }
            ' /etc/mosdns/config_custom.yaml
            
            echolog "CloudFront MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
            need_restart=1
        fi
    fi

    # 如果有配置更新，重启服务
    if [ "$need_restart" = "1" ]; then
        /etc/init.d/mosdns restart &>/dev/null
        if [ "x${openclash_restart}" == "x1" ] ;then
            /etc/init.d/openclash restart &>/dev/null
        fi
    fi
}

read_config

# 启动参数
if [ "$1" ] ;then
    [ $1 == "start" ] && speed_test && ip_replace
    [ $1 == "test" ] && speed_test
    [ $1 == "replace" ] && ip_replace
    [ $1 == "test_mosdns_ip" ] && test_mosdns_ip
    [ $1 == "ipv6" ] && speed_test_ipv6 && ip_replace
    # CloudFront 测速和更新，保持与其他命令相同的组合方式
    [ $1 == "cloudfront" ] && speed_test_cloudfront && cloudfront_ip_replace
    [ $1 == "cloudfront_v6" ] && speed_v6_cloudfront && cloudfront_ip_replace
    [ $1 == "cloudfront_ip" ] && cloudfront_ip_replace
    exit
fi
