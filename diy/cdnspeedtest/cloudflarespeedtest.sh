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
            echolog "Cloudflare MosDNS UCI配置更新完成"
            
        # 如果没有 UCI 配置，检查 YAML 配置
        elif [ -f "/etc/mosdns/config_custom.yaml" ]; then
            echolog "speedtest未找到 UCI 配置，检查到 YAML 配置文件存在"
            need_restart=0
            
            # 检查配置块
            current_ips=$(find_current_ips_v3 'resp_ip .cf_ip_v4v6' "/etc/mosdns/config_custom.yaml")

            if [ $? -eq 0 ] && [ ! -z "$current_ips" ]; then
                echolog "speedtest找到配置块，检查是否需要更新..."
                first_ip=$(echo "$current_ips" | awk '{print $1}')
                if [[ ! " $current_ips " =~ " $bestip " ]]; then
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
                    sed -i "/resp_ip .cf_ip_v4v6/,+1{/black_hole/{s/black_hole.*/black_hole $new_ip_list/}}" /etc/mosdns/config_custom.yaml
                    echolog "Cloudflare MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
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

# 方案1 - 使用简单的行匹配
function find_current_ips_v1() {
    local pattern="$1"
    local config_file="$2"
    
    awk '
        /matches:/ { in_block = 1; next }
        in_block && $0 ~ "resp_ip .cf_ip_v4v6" { found = 1; next }
        /exec: black_hole/ && found { 
            print $0
            exit
        }
    ' "$config_file" | sed 's/.*black_hole\s\+\(.*\)/\1/'
}

# 方案2 - 使用状态追踪
function find_current_ips_v2() {
    local pattern="$1"
    local config_file="$2"
    
    awk '
        /sequence_check_response_has_cf_ip_blackhole/ { start = 1; next }
        start && /matches:/ { in_matches = 1; next }
        in_matches && /"resp_ip \$cf_ip_v4v6"/ { found = 1; next }
        found && /exec: black_hole/ { 
            print $0
            exit
        }
    ' "$config_file" | sed 's/.*black_hole\s\+\(.*\)/\1/'
}

# 方案3 - 使用缓冲区匹配
function find_current_ips_v3() {
    local pattern="$1"
    local config_file="$2"
    
    # 调试信息重定向到stderr
    >&2 echo "Debug: 查找模式: $pattern"
    >&2 echo "Debug: 配置文件: $config_file"
    
    awk -v pattern="$pattern" '
        # 找到包含 matches 的行
        /[[:space:]]*- matches:/ { 
            # 检查下一行是否包含我们要找的模式
            getline next_line
            if (next_line ~ pattern) {
                found = 1
            }
            next
        }
        
        # 如果找到了匹配的模式，提取 black_hole 行中的IP列表
        found && /[[:space:]]*exec: black_hole/ {
            # 只输出IP列表部分
            sub(/^[[:space:]]*exec: black_hole[[:space:]]+/, "")
            print $0
            exit
        }
    ' "$config_file"
}

# 生成新的IP列表
function generate_new_ip_list() {
    local bestip="$1"
    local current_ips="$2"
    
    local ip_count=$(echo "$current_ips" | wc -w)
    local new_ip_list
    
    if [ $ip_count -eq 0 ]; then
        new_ip_list="$bestip"
    elif [ $ip_count -eq 1 ]; then
        new_ip_list="$bestip $current_ips"
    else
        local keep_ips=$(echo "$current_ips" | tr ' ' '\n' | head -n 2 | tr '\n' ' ')
        new_ip_list="$bestip $keep_ips"
    fi
    
    echo "$new_ip_list"
}

# 更新配置文件中的IP列表
function update_config_ip_list() {
    local config_file="$1"
    local pattern="$2"
    local new_ip_list="$3"
    
    echo "Debug: 更新配置文件: $config_file"
    echo "Debug: 匹配模式: $pattern"
    echo "Debug: 新IP列表: $new_ip_list"
    
    # 备份配置（如果还没有备份）
    if [ ! -f "${config_file}.bak" ]; then
        cp "$config_file" "${config_file}.bak"
    fi
    
    awk -v pattern="$pattern" -v new_list="$new_list" '
        # 存储上一行和当前匹配状态
        { prev_line = line; line = $0 }
        
        # 找到包含 matches 的行
        /matches:/ { 
            print
            # 检查下一行是否包含我们要找的模式
            getline next_line
            if (next_line ~ "- \"" pattern "\"") {
                found = 1
            }
            print next_line
            next
        }
        
        # 如果找到了匹配的模式，替换对应的 black_hole 行
        found && /exec: black_hole/ {
            indent = gensub(/^([[:space:]]*).*/, "\\1", 1)
            print indent "exec: black_hole " new_list
            found = 0
            next
        }
        
        # 打印其他行
        { print }
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
}

# 使用示例 - 在 mosdns_ip 函数中：
function mosdns_ip() {
    if [ "x${MosDNS_enabled}" != "x1" ] ;then
        return
    fi
    
    echolog "mark开始处理Cloudflare MosDNS 配置..."
    
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
            echolog "Cloudflare MosDNS UCI配置更新完成"
            
        # 如果没有 UCI 配置，检查 YAML 配置
        elif [ -f "/etc/mosdns/config_custom.yaml" ]; then
            echolog "mark未找到 UCI 配置，检查到 YAML 配置文件存在"
            need_restart=0
            
            # 检查配置块
            current_ips=$(find_current_ips_v3 'resp_ip .cf_ip_v4v6' "/etc/mosdns/config_custom.yaml")
            echo "current_ips: $current_ips"

            if [ $? -eq 0 ] && [ ! -z "$current_ips" ]; then
                echolog "mark找到配置块，检查是否需要更新..."
                first_ip=$(echo "$current_ips" | awk '{print $1}')

                if echo "$current_ips" | grep -w "$bestip" > /dev/null; then
                    echo "测速IP: $bestip 已存在，没有新IP可以更新"
                else
                    echolog "有新IP可以更新: $bestip"
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
                    sed -i "/resp_ip .cf_ip_v4v6/,+1{/black_hole/{s/black_hole.*/black_hole $new_ip_list/}}" /etc/mosdns/config_custom.yaml
                    echolog "Cloudflare MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
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
            echolog "mark未找到任何 MosDNS 配置文件"
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
    bestip="1.1.1.1"
    LOG_FILE="/tmp/cloudflare_test.log"
    
    local config_file="/etc/mosdns/config_custom.yaml"
    
    echo "=== 测试查找功能 ==="
    echo "测试方案1:"
    local result1=$(find_current_ips_v1 'cf_ip_v4v6' "$config_file")
    echo "方案1结果: $result1"
    
    echo "测试方案2:"
    local result2=$(find_current_ips_v2 'cf_ip_v4v6' "$config_file")
    echo "方案2结果: $result2"
    
    echo "测试方案3:"
    local result3=$(find_current_ips_v3 'cf_ip_v4v6' "$config_file")
    echo "方案3结果: $result3"
    
    echo -e "\n=== 测试替换功能 ==="
    if [ ! -z "$result3" ]; then
        echo "当前IP列表: $result3"
        
        # 测试生成新IP列表
        local new_ip_list=$(generate_new_ip_list "$bestip" "$result3")
        echo "生成的新IP列表: $new_ip_list"
        
        # 创建临时配置文件进行测试
        local test_config="/tmp/test_mosdns_config.yaml"
        cp "$config_file" "$test_config"
        
        # 测试更新配置
        echo "测试更新配置文件..."
        update_config_ip_list "$test_config" 'resp_ip \$cf_ip_v4v6' "$new_ip_list"
        
        # 检查更新结果
        echo "更新后的配置:"
        local updated_ips=$(find_current_ips_v3 'cf_ip_v4v6' "$test_config")
        echo "更新后的IP列表: $updated_ips"
        
        # 清理测试文件
        rm -f "$test_config"
    else
        echo "未找到当前IP列表，跳过替换测试"
    fi
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

function speed_test_cloudfront_unified() {
    local ipv6_test="$1"
    rm -rf $LOG_FILE
    mkdir -p $(dirname $CLOUDFRONT_IP_FILE)

    command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${CLOUDFRONT_URL} -o ${CLOUDFRONT_IP_FILE}"

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

    # 根据 ipv6_test 参数决定是否使用 IPv6 IP 列表文件
    if [ "$ipv6_test" == "1" ]; then
        command="${command} -f ${CLOUDFRONT_IPV6_TXT}"
        # 确保 IPv6 列表文件存在
        if [ ! -f "${CLOUDFRONT_IPV6_TXT}" ]; then
            echolog "错误：IPv6 列表文件不存在: ${CLOUDFRONT_IPV6_TXT}"
            return 1
        fi
    else
        command="${command} -f ${CLOUDFRONT_IPV4_TXT}"
        # 确保 IPv4 列表文件存在
        if [ ! -f "${CLOUDFRONT_IPV4_TXT}" ]; then
            echolog "错误：IPv4 列表文件不存在: ${CLOUDFRONT_IPV4_TXT}"
            return 1
        fi
    fi

    echo $command  >> $LOG_FILE 2>&1
    echolog "-----------start cloudfront test----------"
    $command >> $LOG_FILE 2>&1
    echolog "-----------end cloudfront test------------"
}

function speed_v6_cloudfront_wrapper() {
    speed_test_cloudfront_unified "1"
    cloudfront_ip_replace
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
        return 1  # 当 IP 为空时，直接返回，阻止后续操作
    fi
    
    echolog "CloudFront 测速完成，最快 IP: ${bestip}"
    update_cloudfront_ip
}

# 使用示例 - 在 update_cloudfront_ip 函数中：
function update_cloudfront_ip() {
    if [ "x${MosDNS_enabled}" != "x1" ] ;then
        return
    fi
    
    local config_file="/etc/mosdns/config_custom.yaml"
    if [ ! -f "$config_file" ]; then
        echolog "未找到 MosDNS 配置文件"
        return 1
    fi
    
    echolog "开始处理 CloudFront MosDNS 配置..."
    local need_restart=0
    
    # 查找当前IP列表
    echolog "正在查找当前 CloudFront IP 配置..."
    current_ips=$(find_current_ips_v3 'resp_ip .cloudfront_ip' "$config_file")
    echo "current_ips: $current_ips"
    
    if [ ! -z "$current_ips" ]; then
        echolog "找到当前 CloudFront IP 列表: $current_ips"
        echolog "新的最快 IP: $bestip"
        
        # 检查IP是否需要更新
        if [[ ! " $current_ips " =~ " $bestip " ]]; then
            # 生成新的IP列表
            local new_ip_list=$(generate_new_ip_list "$bestip" "$current_ips")
            echolog "生成新的 CloudFront IP 列表: $new_ip_list"
            
            # 更新配置
            update_config_ip_list "$config_file" 'resp_ip \$cloudfront_ip' "$new_ip_list"
            
            echolog "CloudFront MosDNS 配置更新完成，IP列表更新为: $new_ip_list"
            need_restart=1
        else
            echolog "当前 IP ($bestip) 已经在列表中，无需更新"
            echolog "现有IP列表: $current_ips"
        fi
    else
        echolog "未找到 CloudFront IP 配置块"
    fi

    # 如果有配置更新，重启服务
    if [ "$need_restart" = "1" ]; then
        /etc/init.d/mosdns restart &>/dev/null
        if [ "x${openclash_restart}" == "x1" ] ;then
            /etc/init.d/openclash restart &>/dev/null
        fi
        echolog "服务已重启"
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
    [ $1 == "cloudfront" ] && speed_test_cloudfront_unified "0" && cloudfront_ip_replace
    # 修改 ipv6_cf 命令，先设置 ipv6_enabled=1，再执行测速
    if [ "$1" == "ipv6_cf" ]; then
        speed_v6_cloudfront_wrapper
    fi
    [ $1 == "cloudfront_ip" ] && cloudfront_ip_replace
    exit
fi
