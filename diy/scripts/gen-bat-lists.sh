#!/bin/bash
# gen-bat-lists.sh - 从 domain-list-community 生成 BAT (alibaba/tencent/bytedance) 完整域名列表
# 用法: bash gen-bat-lists.sh <domain-list-community-data-dir> <output-dir>
# 环境变量: DLC_DATA_DIR, DLC_OUT_DIR 也可用于指定路径

set -euo pipefail

# 支持参数、环境变量、相对路径回退
DATA_DIR="${1:-${DLC_DATA_DIR:-}}"
OUT_DIR="${2:-${DLC_OUT_DIR:-}}"

# 如果未指定，尝试常见相对路径 (适配本地开发和 GitHub Actions)
if [ -z "$DATA_DIR" ]; then
    for p in \
        "domain-list-community/data" \
        "../domain-list-community/data" \
        "../../domain-list-community/data" \
        "/workspace/domain-list-community/data" \
        "/github/workspace/domain-list-community/data"; do
        if [ -d "$p" ]; then
            DATA_DIR="$p"
            break
        fi
    done
fi

if [ -z "$OUT_DIR" ]; then
    for p in \
        "diy/rule" \
        "../diy/rule" \
        "../../diy/rule" \
        "/workspace/ctc-openwrt/diy/rule" \
        "/github/workspace/ctc-openwrt/diy/rule"; do
        if [ -d "$(dirname "$p")" ] || [ -d "$p" ]; then
            OUT_DIR="$p"
            break
        fi
    done
fi

if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    echo "Error: Data directory not found. Tried: domain-list-community/data, ../domain-list-community/data, ../../domain-list-community/data" >&2
    echo "Set DLC_DATA_DIR env var or pass as first argument." >&2
    exit 1
fi

if [ -z "$OUT_DIR" ]; then
    echo "Error: Output directory not determined. Set DLC_OUT_DIR env var or pass as second argument." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

expand_list() {
    local list_name="$1"
    local output_file="$2"
    local tmp_seen="/tmp/seen_${list_name}.txt"
    > "$tmp_seen"

    process_file() {
        local file="$1"
        [ -f "$file" ] || return 0

        while IFS= read -r line; do
            # 移除注释和首尾空格
            line="${line%%#*}"
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [ -z "$line" ] && continue

            if [[ "$line" == include:* ]]; then
                local inc="${line#include:}"
                inc="${inc%%@*}"  # 移除 @attribute
                inc="$(echo "$inc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                [ -f "$DATA_DIR/$inc" ] && process_file "$DATA_DIR/$inc"
            elif [[ "$line" == domain:* ]]; then
                local d="${line#domain:}"
                d="${d%%@*}"
                d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                [ -n "$d" ] && ! grep -q "^$d$" "$tmp_seen" && echo "$d" >> "$tmp_seen"
            elif [[ "$line" == full:* ]]; then
                local d="${line#full:}"
                d="${d%%@*}"
                d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                [ -n "$d" ] && ! grep -q "^$d$" "$tmp_seen" && echo "$d" >> "$tmp_seen"
            elif [[ "$line" == *.* && "$line" != keyword:* && "$line" != regexp:* ]]; then
                # 裸域名行
                local d="${line%%@*}"
                d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                [ -n "$d" ] && ! grep -q "^$d$" "$tmp_seen" && echo "$d" >> "$tmp_seen"
            fi
        done < "$file"
    }

    process_file "$DATA_DIR/$list_name"
    sort -u "$tmp_seen" > "$output_file"
    rm -f "$tmp_seen"
    echo "Generated $output_file ($(wc -l < "$output_file") domains)"
}

echo "=== Generating BAT domain lists from $DATA_DIR ==="
expand_list "alibaba" "$OUT_DIR/alibaba.txt"
expand_list "tencent" "$OUT_DIR/tencent.txt"
expand_list "bytedance" "$OUT_DIR/bytedance.txt"
echo "=== BAT domain lists generation complete ==="