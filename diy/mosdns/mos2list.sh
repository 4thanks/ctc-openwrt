#!/bin/sh

REPO_URL="https://github.com/4thanks/ctc-openwrt/raw/main/diy/rule"
CDN_URL="https://gh-proxy.com/"
DAT_PREFIX="$CDN_URL/$REPO_URL"

TMPDIR=$(mktemp -d) || exit 1

getdat() {
  local filename="$1"
  local max_retries=3
  local expected_size=0
  local min_size=1024  # 最小可接受文件大小（1KB）
  local max_size=10485760  # 最大可接受文件大小（10MB）

  # 尝试获取文件大小，同时处理压缩情况
  for url in "$DAT_PREFIX/$filename" "$REPO_URL/$filename"; do
    # 使用 -H 'Accept-Encoding: identity' 请求未压缩的文件
    expected_size=$(curl --connect-timeout 5 -sI -H 'Accept-Encoding: identity' "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    
    if [ -n "$expected_size" ] && [ "$expected_size" -gt 0 ]; then
      echo "Expected size for $filename: $expected_size bytes"
      break
    fi
  done

  # 下载文件
  for url in "$DAT_PREFIX/$filename" "$REPO_URL/$filename"; do
    local retry_count=0
    while [ $retry_count -le $max_retries ]; do
      if [ $retry_count -gt 0 ]; then
        echo "Retry $retry_count for $url"
      fi
      
      if curl --connect-timeout 5 -m 90 --ipv4 -fSLo "$TMPDIR/$filename" "$url"; then
        # 改进文件大小获取方法
        local actual_size
        if [ -f "$TMPDIR/$filename" ]; then
            # 尝试多种方法获取文件大小
            actual_size=$(wc -c < "$TMPDIR/$filename" 2>/dev/null || \
                        stat -f %z "$TMPDIR/$filename" 2>/dev/null || \
                        stat -c %s "$TMPDIR/$filename" 2>/dev/null || \
                        ls -l "$TMPDIR/$filename" | awk '{print $5}')
            
            if [ -n "$actual_size" ]; then
                echo "Downloaded file size: $actual_size bytes"
                
                # 文件大小验证逻辑
                if [ -n "$expected_size" ] && [ "$expected_size" -gt 0 ]; then
                    if [ "$actual_size" -eq "$expected_size" ]; then
                        echo "File size exactly matches for $filename ($actual_size bytes)"
                        return 0
                    elif [ "$actual_size" -lt "$expected_size" ] && [ "$actual_size" -ge "$min_size" ]; then
                        echo "File might be compressed, size acceptable ($actual_size bytes)"
                        return 0
                    fi
                else
                    if [ "$actual_size" -ge "$min_size" ] && [ "$actual_size" -le "$max_size" ]; then
                        echo "File size within acceptable range ($actual_size bytes)"
                        return 0
                    fi
                fi
                
                echo "File size out of acceptable range: $actual_size bytes"
            else
                echo "Warning: Could not determine file size, but file exists"
                # 如果无法获取文件大小但文件存在且不为空，仍然接受
                if [ -s "$TMPDIR/$filename" ]; then
                    echo "File exists and is not empty, accepting"
                    return 0
                fi
            fi
        fi
        
        echo "Removing invalid file"
        rm -f "$TMPDIR/$filename"
      fi
      
      retry_count=$((retry_count + 1))
      sleep 5
    done
  done

  echo "Failed to download $filename after all attempts"
  return 1
}

getdat "blacklist_full.txt"
if [ $? -eq 0 ]; then 
    if [ "$(grep -o google "$TMPDIR/blacklist_full.txt" | wc -l)" -eq 0 ]; then
        echo "No 'google' found in blacklist_full.txt. Removing file."
        rm -rf "$TMPDIR/blacklist_full.txt"
    else
        echo "Download of blacklist_full.txt successful"
    fi
else
    echo "Download of blacklist_full.txt failed"
    rm -rf "$TMPDIR/blacklist_full.txt"
fi

getdat "whitelist_full.txt"
if [ $? -eq 0 ]; then
    if [ "$(grep -o cn "$TMPDIR/whitelist_full.txt" | wc -l)" -lt 100 ]; then
        echo "No 'cn' found in whitelist_full.txt. Removing file."
        rm -rf "$TMPDIR/whitelist_full.txt"
    else
        echo "Download of whitelist_full.txt successful"
    fi
else
    echo "Download of whitelist_full.txt failed"
    rm -rf "$TMPDIR/whitelist_full.txt"
fi

getdat "geolite2country_ipv4_6.txt"
if [ $? -eq 0 ]; then
    echo "Download of geolite2country_ipv4_6.txt successful"
else
    echo "Download of geolite2country_ipv4_6.txt failed"
    rm -rf "$TMPDIR/geolite2country_ipv4_6.txt"
fi

getdat "adlist-oisd-vn.txt"
if [ $? -eq 0 ]; then
    if [ "$(grep -o ads "$TMPDIR/adlist-oisd-vn.txt" | wc -l)" -lt 100 ]; then
        echo "No 'ads' found in adlist-oisd-vn.txt. Removing file."
        rm -rf "$TMPDIR/adlist-oisd-vn.txt"
    else
        echo "Download of adlist-oisd-vn.txt successful"
    fi
else
    echo "Download of adlist-oisd-vn.txt failed"
    rm -rf "$TMPDIR/adlist-oisd-vn.txt"
fi

if [ -d "$TMPDIR" ] && [ "$(ls -A $TMPDIR)" ]; then
    [ -d "/etc/mosdns" ] || mkdir -p /etc/mosdns
    
    valid_files=0
    for file in blacklist_full.txt whitelist_full.txt geolite2country_ipv4_6.txt adlist-oisd-vn.txt; do
        if [ -f "$TMPDIR/$file" ]; then
            cp -f "$TMPDIR/$file" "/usr/share/mosdns/$file"
            echo "Copied $file to /usr/share/mosdns/"
            valid_files=$((valid_files + 1))
        fi
    done
    
    if [ "$valid_files" -gt 0 ]; then
        sleep 3
        if /etc/init.d/mosdns restart; then
            echo "mosdns restart successful"
        else
            echo "mosdns restart failed"
            exit 1
        fi
    else
        echo "No valid files were copied, skipping mosdns restart"
        exit 1
    fi
fi

rm -rf "$TMPDIR"
exit 0
