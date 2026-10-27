#!/bin/bash
# fetch-mosdns-conf.sh - 下载第三方 mosdns 配置文件到 diy/mosdns/
# 用法: bash fetch-mosdns-conf.sh [输出目录]
# 环境变量: MOSDNS_CONF_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${MOSDNS_CONF_OUT_DIR:-$REPO_ROOT/diy/mosdns}}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-mosdns-conf.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fetch() { # <url> <filename>
    local url="$1" name="$2"
    echo "  - $name"
    curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 300 \
        -o "$TMP/$name" "$url"
    if [ ! -s "$TMP/$name" ]; then
        echo "Error: empty download: $url" >&2
        exit 1
    fi
}

# sbwml/luci-app-mosdns
#curl -fsSL "https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/usr/share/mosdns/default.yaml" -o "$TMP/sbwml-default.yaml"
fetch "https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/config_custom.yaml" "sbwml-conf.yaml"

# easymosdns
fetch "https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml" "easymosdns-conf.yaml"

# ZJDNS
#curl -fsSL "https://raw.githubusercontent.com/hezhijie0327/ZJDNS/main/mosdns/config.yaml" -o "$TMP/hezhijie0327-conf.yaml"

# hplee0120/luci-app-mosdns
# 上游仓库已删除 (curl 返回 404)，原脚本会把 "404: Not Found" 写进 hplee0120.yaml，故移除
#fetch "https://raw.githubusercontent.com/hplee0120/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config.yaml" "hplee0120.yaml"

mkdir -p "$OUT_DIR"
cp -f "$TMP"/*.yaml "$OUT_DIR"/
echo "Fetched mosdns conf files to $OUT_DIR"
