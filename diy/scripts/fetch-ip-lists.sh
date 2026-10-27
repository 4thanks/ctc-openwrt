#!/bin/bash
# fetch-ip-lists.sh - 下载 mosdns 使用的 IP/域名文本规则到 diy/rule/
#   whitelist_full.txt / blacklist_full.txt / geolite2country_ipv4_6.txt / gfw_ip_list.txt
# 用法: bash fetch-ip-lists.sh [输出目录]
# 环境变量: IP_LISTS_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${IP_LISTS_OUT_DIR:-$REPO_ROOT/diy/rule}}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-ip-lists.XXXXXX")"
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

# 白名单 / 黑名单域名
fetch "https://raw.githubusercontent.com/hezhijie0327/GFWList2AGH/main/gfwlist2domain/whitelist_full.txt" "whitelist_full.txt"
fetch "https://raw.githubusercontent.com/hezhijie0327/GFWList2AGH/main/gfwlist2domain/blacklist_full.txt" "blacklist_full.txt"

# 中国 IP 段 / GFW IP 段
fetch "https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.txt" "geolite2country_ipv4_6.txt"
fetch "https://raw.githubusercontent.com/pmkol/easymosdns/rules/gfw_ip_list.txt" "gfw_ip_list.txt"

mkdir -p "$OUT_DIR"
cp -f "$TMP"/*.txt "$OUT_DIR"/
echo "Fetched ip/domain rule files to $OUT_DIR"
