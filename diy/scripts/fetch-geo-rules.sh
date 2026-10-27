#!/bin/bash
# fetch-geo-rules.sh - 下载 geosite/geoip/GeoLite2-CNIPDb 数据到 diy/rule/
# 用法: bash fetch-geo-rules.sh [输出目录]
# 环境变量: GEO_RULES_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${GEO_RULES_OUT_DIR:-$REPO_ROOT/diy/rule}}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-geo-rules.XXXXXX")"
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

# GeoLite2 CNIPDb (二进制)
fetch "https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.dat" "geolite2_CNIPDb.dat"
# geosite / geoip (二进制)
fetch "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" "geosite.dat"
fetch "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" "geoip.dat"

mkdir -p "$OUT_DIR"
cp -f "$TMP"/*.dat "$OUT_DIR"/
echo "Fetched geo rule files to $OUT_DIR"
