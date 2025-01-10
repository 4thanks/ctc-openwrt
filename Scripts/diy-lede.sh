#!/bin/bash

# Make mosdns tailsale config persistent during sysupgrades
echo "/etc/mosdns/" >> package/base-files/files/etc/sysupgrade.conf
echo "/usr/share/mosdns" >> package/base-files/files/etc/sysupgrade.conf
echo "/etc/tailscale/" >> package/base-files/files/etc/sysupgrade.conf
echo "/usr/share/CloudflareSpeedTest/" >> package/base-files/files/etc/sysupgrade.conf
echo "/usr/bin/cloudflarespeedtest/" >> package/base-files/files/etc/sysupgrade.conf

source_dir="$GITHUB_WORKSPACE/diy"

# 查找 luci-app-mosdns/Makefile 并获取其所在目录
makefile_path=$(find package/mosdns -path "*/luci-app-mosdns/Makefile" -print -quit)

# 如果没有找到 Makefile，则输出错误信息并退出
if [ -z "$makefile_path" ]; then
  echo "Error: luci-app-mosdns/Makefile not found."
  exit 1
fi

makefile_dir=$(dirname "$makefile_path")

# 构建目标路径
mosdns_dir_a="$makefile_dir/root/usr/share/mosdns"
mosdns_dir_b="$makefile_dir/root/etc/mosdns/"

# 复制文件
for file in rule/whitelist_full.txt \
            rule/blacklist_full.txt \
            rule/gfw_ip_list.txt \
            rule/geolite2country_ipv4_6.txt \
            rule/adlist-oisd-vn.txt \
            rule/alibaba.txt \
            rule/bytedance.txt \
            rule/tencent.txt \
            mosdns/mos2list.sh \
            cdnspeedtest/cloudflarespeedtest.sh \
            cdnspeedtest/cloudfront_ipv4.txt \
            cdnspeedtest/cloudfront_ipv6.txt \
            cdnspeedtest/cloudfront_ipv46.txt; do
  cp -f "$source_dir/$file" "$mosdns_dir_a" || true
done
# 复制文件
for file in mosdns/config_custom.yaml \
            mosdns/hezhijie0327-ref.yaml \
            mosdns/bat_ref.yaml; do
  cp -f "$source_dir/$file" "$mosdns_dir_b" || true
done

# 查找 cdnspeedtest/Makefile 并获取其所在目录
cdnspeedtest_path=$(find package -path "*/cdnspeedtest/Makefile" -print -quit)

# 如果没有找到 Makefile，则输出错误信息并退出
if [ -z "$cdnspeedtest_path" ]; then
  echo "Error: cdnspeedtest/Makefile not found."
  exit 1
fi

cdnspeedtest_dir=$(dirname "$cdnspeedtest_path")

for file in cdnspeedtest/Makefile; do
  cp -f "$source_dir/$file" "$cdnspeedtest_dir" || true
done
