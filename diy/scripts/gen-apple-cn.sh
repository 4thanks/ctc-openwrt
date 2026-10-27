#!/bin/bash
# gen-apple-cn.sh - 从 felixonmars/dnsmasq-china-list 抓取 apple.china.conf 并转换为 mosdns 域名列表
#   dnsmasq 格式: server=/a1.mzstatic.com/114.114.114.114
#   mosdns 格式:  a1.mzstatic.com            (省略前缀 = domain 后缀匹配，含所有子域)
# 输出: diy/rule/apple_cn.txt
# 用法: bash gen-apple-cn.sh [输出目录]
# 环境变量: APPLE_CN_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${APPLE_CN_OUT_DIR:-$REPO_ROOT/diy/rule}}"

URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf"
MIN_ENTRIES=50

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-apple-cn.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "  - apple.china.conf"
curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 300 \
    -o "$TMP/apple.china.conf" "$URL"
if [ ! -s "$TMP/apple.china.conf" ]; then
    echo "Error: empty download: $URL" >&2
    exit 1
fi

# server=/domain/114.114.114.114  ->  domain
# 兼容 server= / address= / local= 三种写法，忽略非域名段落
sed -nE 's#^[[:space:]]*(server|address|local)=/([^/]+)/.*$#\2#p' "$TMP/apple.china.conf" \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u > "$TMP/apple_cn.txt"

count="$(awk 'END { print NR }' "$TMP/apple_cn.txt")"
if [ "$count" -lt "$MIN_ENTRIES" ]; then
    echo "Error: only $count entries parsed from $URL (expect >= $MIN_ENTRIES)" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
cp -f "$TMP/apple_cn.txt" "$OUT_DIR"/
echo "Generated $OUT_DIR/apple_cn.txt ($count entries)"
