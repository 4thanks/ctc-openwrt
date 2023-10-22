#!/bin/bash
#
echo '修改机器名称'
sed -i 's/OpenWrt/cm520/g' package/base-files/files/bin/config_generate
 
echo '修改网关地址'
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
 
echo '修改时区NTP'
#sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
sed -i 's/ntp.aliyun.com/cn.ntp.org.cn/g' package/base-files/files/bin/config_generate
sed -i 's/time1.cloud.tencent.com/ntp.ntsc.ac.cn/g' package/base-files/files/bin/config_generate
sed -i '/time.ustc.edu.cn/d' package/base-files/files/bin/config_generate
sed -i '/cn.pool.ntp.org/d' package/base-files/files/bin/config_generate
 
echo '去除默认bootstrap主题'
sed -i '/set luci.main.mediaurlbase=\/luci-static\/bootstrap/d' feeds/luci/themes/luci-theme-bootstrap/root/etc/uci-defaults/30_luci-theme-bootstrap
 
echo '修改wifi名称'
sed -i 's/OpenWrt/cm520/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
 
echo '修改Turboacc设置'
sed -i '56,70d' feeds/luci/applications/luci-app-turboacc/Makefile
sed -i '57,81d;45,49d' feeds/luci/applications/luci-app-turboacc/luasrc/model/cbi/turboacc.lua
sed -i '20,21d;13d;15d;6,7d' feeds/luci/applications/luci-app-turboacc/luasrc/view/turboacc/turboacc_status.htm
 
echo '去吧皮卡丘'
cd package
 
echo '最新argon主题'
rm -rf ../feeds/luci/themes/luci-theme-argon
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon luci-theme-argon
