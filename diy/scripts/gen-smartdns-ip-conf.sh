#!/bin/bash
# gen-smartdns-ip-conf.sh - 生成 smartdns 使用的 blacklist-ip 配置
#   geolite2CNIPDb.conf      中国 IP 段
#   gfw_ip.conf              GFW IP 段
#   geolite2CNIPDb_gfw.conf  两者合并
# 输出: diy/smartdns/
# 用法: bash gen-smartdns-ip-conf.sh [输出目录]
# 环境变量: SMARTDNS_CONF_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${SMARTDNS_CONF_OUT_DIR:-$REPO_ROOT/diy/smartdns}}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-smartdns-ip.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fetch() { # <url> <filename>
    local url="$1" name="$2"
    echo "  - $name"
    curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 600 \
        -o "$TMP/$name" "$url"
    if [ ! -s "$TMP/$name" ]; then
        echo "Error: empty download: $url" >&2
        exit 1
    fi
}

fetch "https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.txt" "country_ipv4_6.txt"
fetch "https://raw.githubusercontent.com/pmkol/easymosdns/rules/gfw_ip_list.txt" "gfw_ip_list.txt"

sed 's/^/blacklist-ip /' "$TMP/country_ipv4_6.txt" > "$TMP/geolite2CNIPDb.conf"
sed 's/^/blacklist-ip /' "$TMP/gfw_ip_list.txt"    > "$TMP/gfw_ip.conf"
cat "$TMP/geolite2CNIPDb.conf" "$TMP/gfw_ip.conf"   > "$TMP/geolite2CNIPDb_gfw.conf"

mkdir -p "$OUT_DIR"
cp -f "$TMP"/*.conf "$OUT_DIR"/
echo "Generated smartdns ip confs to $OUT_DIR"
