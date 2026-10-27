#!/bin/bash
# update-mosdns-conf.sh - 一键更新 mosdns & smartdns 配置与规则
#
# 实际工作由 diy/scripts/ 下的独立脚本完成，本脚本只按顺序调用：
#   fetch-mosdns-conf.sh      第三方 mosdns yaml 配置
#   gen-bat-lists.sh          从 domain-list-community 生成 alibaba/tencent/bytedance 列表
#   gen-apple-cn.sh           从 dnsmasq-china-list 生成 apple.cn 域名列表
#   fetch-geo-rules.sh        geosite / geoip / geolite2-CNIPDb 数据
#   gen-adlist.sh             oisd + hostsVN 广告/跟踪域名列表
#   fetch-ip-lists.sh         mosdns 用的 whitelist / blacklist / gfw_ip 文本规则
#   gen-smartdns-ip-conf.sh   smartdns 用的 blacklist-ip 配置
#
# 用法: bash diy/update-mosdns-conf.sh
# 环境变量: DLC_DATA_DIR 指定 domain-list-community/data 路径

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

cd "$REPO_ROOT"

step() {
    echo
    echo "==> $1"
}

run() {
    bash "$SCRIPTS_DIR/$1"
}

step "mosdns conf"
run fetch-mosdns-conf.sh

step "BAT domain lists (alibaba/tencent/bytedance)"
# gen-bat-lists.sh 自身也能探测路径，这里只负责决定是否跳过
dlc_data_dir=""
for p in "${DLC_DATA_DIR:-}" "domain-list-community/data" "../domain-list-community/data" "../../domain-list-community/data"; do
    if [ -n "$p" ] && [ -d "$p" ]; then
        dlc_data_dir="$p"
        break
    fi
done

if [ -n "$dlc_data_dir" ]; then
    bash "$SCRIPTS_DIR/gen-bat-lists.sh" "$dlc_data_dir" "diy/rule"
else
    echo "Warning: domain-list-community not found, skipping BAT list generation" >&2
    echo "Clone it with: git clone https://github.com/v2fly/domain-list-community.git" >&2
fi

step "apple.cn domain list"
run gen-apple-cn.sh

step "geo rules (geosite/geoip/geolite2)"
run fetch-geo-rules.sh

step "adlist (oisd + hostsVN)"
run gen-adlist.sh

step "ip & domain rule lists"
run fetch-ip-lists.sh

step "smartdns ip conf"
run gen-smartdns-ip-conf.sh

step "done"
