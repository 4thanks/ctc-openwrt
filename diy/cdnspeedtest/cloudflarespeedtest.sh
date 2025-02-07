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
        # 先检查 UCI 配置是否有cloudflare，有则备份配置，临时禁用cloudflare，并重启。
        if [ -n "$(grep 'option cloudflare' /etc/config/mosdns)" ]; then
            sed -i".bak" "/option cloudflare/d" /etc/config/mosdns
            sed -i '/^$/d' /etc/config/mosdns && echo -e "\toption cloudflare '0'" >> /etc/config/mosdns
            
            # UCI 配置禁用cloudflare后立即重启
            /etc/init.d/mosdns restart &>/dev/null
            if [ "x${openclash_restart}" == "x1" ] ;then
                /etc/init.d/openclash restart &>/dev/null
            fi
            echolog "UCI配置禁用cloudflare更新完成"
        else
        # 如果没有 UCI 配置，检查 YAML 配置
            if [ -f "/etc/mosdns/config_custom.yaml" ]; then
                echolog "speedtest未找到 UCI 配置，检查到 YAML 配置文件存在"
                # 查找配置块，并获取行数
                CONTENT_MATCH=$(find_match "mark 666" "/etc/mosdns/config_custom.yaml")
                if [ $? -eq 0 ]; then
                    LINE_NUMBER=$(echo "$CONTENT_MATCH" | sed -n 's/^行号 \([0-9]*\):.*/\1/p')
                    current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
                    current_ip=$(echo "$current_line_content" | sed -E 's/.*exec: black_hole[[:space:]]+//g' | xargs)
                    echolog "找到mark 666: $LINE_NUMBER 行，当前yaml文件IP: $current_ip"

                    # 强制备份当前配置
                    cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
                else
                    echolog "YAML配置未找到匹配行，请检查调整"
                fi
            else
                echolog "未找到任何 MosDNS 配置文件"
            fi
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

function find_match() {
    # 定义文件路径
    KEYWORD="$1"
    FILE_PATH="$2"  # 赋值给全局变量
    
    # 检查文件是否存在（建议在调用 awk 前就判断）
    if [ ! -f "$FILE_PATH" ]; then
      echo "Error: File '$FILE_PATH' not found."
      exit 1
    fi

    # 初始化变量
    result=""

    # 使用 awk 处理文件内容
    result=$(awk -v key="$KEYWORD" '
    BEGIN {
        found = 0;
        context = "";
        line_number = 0;
    }
    {
        line_number++;
    }
    $0 ~ key {
        found = 1;
        count = 0;
        context = "";
        start_line = line_number;
    }
    found && count < 2 {
        context = context $0 "\n";
        count++;
        if ($0 ~ /exec: black_hole/) {
            gsub(/\n+$/, "", context);
            print "LINE:" line_number ":" context;  # 添加行号输出
            found = 0;
            context = "";
        }
    }
    found && count == 2 {
        found = 0;
        context = "";
    }
    ' "$FILE_PATH")

    # 输出结果变量
    if [ -n "$result" ]; then
      echo "符合条件的行及之后的几行："
      # 使用 sed 来格式化输出，将 LINE:number: 转换为更易读的格式
      echo "$result" | sed 's/^LINE:\([0-9]*\):/行号 \1:\n/'
      # 获取LINE行数并赋值给全局变量
      LINE_NUMBER=$(echo "$result" | sed -n 's/^LINE:\([0-9]*\):.*/\1/p')
      if [ -n "$LINE_NUMBER" ]; then
          echo "替换第: $LINE_NUMBER 行的IP"
      fi
    else
      echo "未找到符合条件的行。"
    fi
}

#用find_match函数中的行数，替换符合条件中exec: black_hole的IP，生成临时测试文件预览
function match_replace_ip() {
    # 测试IP和临时文件
    #temp_ip="1.1.1.1"
    temp_ip="$1"
    # 创建临时文件 - 修改为绝对路径且避免空格问题
    #temp_config="/tmp/test_mosdns_config.yaml"
    FILE_PATH="$2"
    # cp "$FILE_PATH" "$temp_config"

    # 符合条件行数
    LINE_NUMBER="$3"

    # 其他函数的IP和配置文件备用占位符

    # 添加调试信息
    echo "Debug: LINE_NUMBER = $LINE_NUMBER"
    echo "Debug: FILE_PATH = $FILE_PATH"

    # 检查必要变量
    if [ -z "$LINE_NUMBER" ] || [ -z "$FILE_PATH" ]; then
        echo "Error: Missing required variables"
        return 1
    fi
    
    # 先检查当前行数内容是mark 666666还是black_hole
    current_line_content=$(sed -n "${LINE_NUMBER}p" "$FILE_PATH")

    # 检查当前行是否是exec: black_hole，并更新替换IP
    current_ip=$(echo "$current_line_content" | sed -E 's/.*exec: black_hole[[:space:]]+//g' | xargs)
    echo "当前yaml文件IP: $current_ip"


    # 检查是否一个或多个相同的IP
    if echo "$current_ip" | grep -w "$temp_ip" > /dev/null; then
        echo "IP: $temp_ip 已存在，没有新IP可以更新"
    else
        echo "有新IP可以更新: $temp_ip"
        # 计数当前IP，保留最多3个IP组合，最少1个IP组合
        current_ip_count=$(echo "$current_ip" | wc -w)
        if [ $current_ip_count -eq 0 ]; then
            new_ip_list="$temp_ip"
        elif [ $current_ip_count -eq 1 ]; then
            new_ip_list="$temp_ip $current_ip"
        else
            # 保留前2个IP组合
            keep_ips=$(echo "$current_ip" | tr ' ' '\n' | head -n 2 | tr '\n' ' ')
            new_ip_list="$temp_ip $keep_ips"
        fi

        sed -i "${LINE_NUMBER}s/exec: black_hole.*/exec: black_hole ${new_ip_list}/g" "$FILE_PATH"

        # 抓取LINE行数新的IP组合
        new_ip=$(sed -n "${LINE_NUMBER}p" "$FILE_PATH")
        echo "新的IP组合: $new_ip"
    fi
}

# 使用示例 - 在 mosdns_ip 函数中：
function mosdns_ip() {
    if [ "x${MosDNS_enabled}" == "x1" ] ;then
        echolog "mark开始更新Cloudflare IP给 MosDNS 配置..."
        # 先检查 UCI 配置mosdns是否启用自定义配置
        if [ -n "$(grep 'option cloudflare' /etc/config/mosdns)" ]; then
            sed -i".bak" "/option cloudflare/d" /etc/config/mosdns
            if [ -n "$(grep 'list cloudflare_ip' /etc/config/mosdns)" ]; then
                sed -i".bak" "/list cloudflare_ip/d" /etc/config/mosdns
            fi
            sed -i '/^$/d' /etc/config/mosdns && echo -e "\toption cloudflare '1'\n\tlist cloudflare_ip '$bestip'" >> /etc/config/mosdns
            
            # UCI 配置更新后立即重启
            /etc/init.d/mosdns restart &>/dev/null
            if [ "x${openclash_restart}" == "x1" ] ;then
                /etc/init.d/openclash restart &>/dev/null
            fi
            echolog "UCI配置完成更新IP并重启MosDNS"
            
        # 如果没有 UCI 配置，检查 YAML 配置
        elif [ -f "/etc/mosdns/config_custom.yaml" ]; then
            echolog "mark未找到 UCI 配置，检查到 YAML 配置文件存在"

            CONTENT_MATCH=$(find_match "mark 666" "/etc/mosdns/config_custom.yaml")
            if [ $? -eq 0 ]; then
                cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.mark
                LINE_NUMBER=$(echo "$CONTENT_MATCH" | sed -n 's/^行号 \([0-9]*\):.*/\1/p')
                current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
                echo "当前mark 666行是: $current_line_content"
                echo "即将更新IP: $bestip"

                # 替换更新IP
                match_replace_ip "$bestip" "/etc/mosdns/config_custom.yaml" "$LINE_NUMBER"
                replace_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
                # echo "替换后行是: $replace_line_content"
                # 如果match_replace_ip的执行到更换新IP重启
                if echo "$replace_line_content" | grep -q "exec: black_hole"; then
                    /etc/init.d/mosdns restart &>/dev/null
                    if [ "x${openclash_restart}" == "x1" ] ;then
                        /etc/init.d/openclash restart &>/dev/null
                    fi
                    echolog "YAML配置完成更新IP并重启MosDNS"
                else
                    replace_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")   
                    echolog "当前行是：$replace_line_content ，请检查调整"
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

# 临时IPv6测速
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

    # 检查yaml文件及查找匹配关键词
    if [ -f "/etc/mosdns/config_custom.yaml" ]; then
        echolog "检查到 YAML 配置文件存在"
        # 查找配置块，并获取行数
        CONTENT_MATCH=$(find_match "mark 666" "/etc/mosdns/config_custom.yaml")
        if [ $? -eq 0 ]; then
            LINE_NUMBER=$(echo "$CONTENT_MATCH" | sed -n 's/^行号 \([0-9]*\):.*/\1/p')
            current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
            current_ip=$(echo "$current_line_content" | sed -E 's/.*exec: black_hole[[:space:]]+//g' | xargs)
            echolog "找到mark 666: $LINE_NUMBER 行，当前yaml文件IP: $current_ip"
            # 强制备份当前配置
            cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
            # 开始IPv6测速
            echo $command  >> $LOG_FILE 2>&1
            echolog "-----------start----------"
            $command >> $LOG_FILE 2>&1
            echolog "-----------end------------"
        else
            echolog "未找到mark 666的匹配行，跳过测速"
        fi
    else
        echolog "未找到任何 MosDNS 配置文件，跳过测速"
    fi
}

# 临时测试CloudFront
function speed_test_cloudfront_unified() {
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

    # 检查yaml文件及查找匹配关键词cloudfront_ip
    if [ -f "/etc/mosdns/config_custom.yaml" ]; then
        echolog "检查到 YAML 配置文件存在"
        # 查找配置块，并获取行数
        CONTENT_MATCH=$(find_match "mark 777" "/etc/mosdns/config_custom.yaml")
        if [ $? -eq 0 ]; then
            LINE_NUMBER=$(echo "$CONTENT_MATCH" | sed -n 's/^行号 \([0-9]*\):.*/\1/p')
            current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
            current_ip=$(echo "$current_line_content" | sed -E 's/.*exec: black_hole[[:space:]]+//g' | xargs)
            echolog "找到mark 777: $LINE_NUMBER 行，当前yaml文件IP: $current_ip"
            # 强制备份当前配置
            cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.bak
            # 开始IPv6测速
            echo $command  >> $LOG_FILE 2>&1
            echolog "-----------start----------"
            $command >> $LOG_FILE 2>&1
            echolog "-----------end------------"
        else
            echolog "未找到匹配的行，跳过测速"
        fi
    else
        echolog "未找到任何 MosDNS 配置文件，跳过测速"
    fi
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
    # 检查yaml文件及查找匹配关键词cloudfront_ip
    if [ -f "/etc/mosdns/config_custom.yaml" ]; then
        CONTENT_MATCH=$(find_match "mark 777" "/etc/mosdns/config_custom.yaml")
        if [ $? -eq 0 ]; then
            cp /etc/mosdns/config_custom.yaml /etc/mosdns/config_custom.yaml.mark
            LINE_NUMBER=$(echo "$CONTENT_MATCH" | sed -n 's/^行号 \([0-9]*\):.*/\1/p')
            current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
            echo "当前mark 777行是: $current_line_content"
            echo "即将更新IP: $bestip"
            # 替换更新IP
            match_replace_ip "$bestip" "/etc/mosdns/config_custom.yaml" "$LINE_NUMBER"
            replace_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")
            # echo "替换后行是: $replace_line_content"
            # 如果match_replace_ip的执行到更换新IP重启
            if echo "$replace_line_content" | grep -q "exec: black_hole"; then
                /etc/init.d/mosdns restart &>/dev/null
                if [ "x${openclash_restart}" == "x1" ] ;then
                    /etc/init.d/openclash restart &>/dev/null
                fi
                echolog "YAML配置完成更新IP并重启MosDNS"
            else
                current_line_content=$(sed -n "${LINE_NUMBER}p" "/etc/mosdns/config_custom.yaml")   
                echolog "当前行是：$current_line_content ，请检查调整"
            fi
        else
            echolog "未找到匹配的行，跳过更新"
        fi
    else
        echolog "mark未找到任何 MosDNS 配置文件"
    fi
}

read_config

# 启动参数
if [ "$1" ] ;then
    [ $1 == "start" ] && speed_test && ip_replace
    [ $1 == "test" ] && speed_test
    [ $1 == "replace" ] && ip_replace
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
