#!/bin/bash
# gen-adlist.sh - 合并 oisd small + hostsVN 生成广告/跟踪域名列表
# 输出: diy/rule/adlist-oisd-vn.txt
# 用法: bash gen-adlist.sh [输出目录]
# 环境变量: ADLIST_OUT_DIR 也可用于指定输出目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-${ADLIST_OUT_DIR:-$REPO_ROOT/diy/rule}}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctc-adlist.XXXXXX")"
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

# hostsVN 广告域名
fetch "https://raw.githubusercontent.com/bigdargon/hostsVN/master/option/domain.txt" "vn-ad.txt"
# oisd (small)
fetch "https://small.oisd.nl/domainswild2" "oisd_dbl_basic.txt"

# 保留注释行与普通行，去掉缩进/空行，排序去重
cat "$TMP/vn-ad.txt" "$TMP/oisd_dbl_basic.txt" \
    | grep -E '^[[:space:]]*#|^[^#]' \
    | sort -u > "$TMP/adlist-oisd-vn.txt"

if [ ! -s "$TMP/adlist-oisd-vn.txt" ]; then
    echo "Error: generated empty adlist" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
cp -f "$TMP/adlist-oisd-vn.txt" "$OUT_DIR"/
echo "Generated $OUT_DIR/adlist-oisd-vn.txt ($(wc -l < "$OUT_DIR/adlist-oisd-vn.txt") lines)"
