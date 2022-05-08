#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: kenzo
#=================================================
#1. Modify default IP
sed -i 's/192.168.1.1/192.168.5.1/g' openwrt/package/base-files/files/bin/config_generate

#2. 自定义设置
#cp -f package/litte/default-settings package/lean/default-settings/files/zzz-default-settings
#cp -f package/litte/banner package/base-files/files/etc/banner
#cp -f package/litte/Leandiffconfig diffconfig && cp diffconfig .config && make defconfig
#./scripts/feeds update -a && ./scripts/feeds install -a && ./scripts/feeds install -a
sed -i "/list server/d" /etc/config/dhcp
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci set dhcp.@dnsmasq[0].noresolv="1"
uci set dhcp.@dnsmasq[0].cachesize='0'
uci set dhcp.@dnsmasq[0].filter_aaaa='0'
uci commit dhcp
