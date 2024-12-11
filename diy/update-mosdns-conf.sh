# get conf yaml

#sbwml-conf
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/usr/share/mosdns/default.yaml > /tmp/sbwml-default.yaml
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/config_custom.yaml > /tmp/sbwml-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml > /tmp/easymosdns-conf.yaml

#ZJDNS
#curl -sS https://raw.githubusercontent.com/hezhijie0327/ZJDNS/main/mosdns/config.yaml > /tmp/hezhijie0327-conf.yaml

#hplee0120
curl -sS https://raw.githubusercontent.com/hplee0120/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config.yaml > /tmp/hplee0120.yaml

cp -rf /tmp/*.yaml diy/mosdns/
rm -rf /tmp/*

#rules && Geosite GeoIP && cndbIP data
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.dat > /tmp/geolite2_CNIPDb.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat > /tmp/geosite.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat > /tmp/geoip.dat

cp -rf /tmp/*.dat diy/rule
rm -rf /tmp/*

#adlist mix oisd_dbl_basic+vn
curl -sS https://raw.githubusercontent.com/bigdargon/hostsVN/master/option/domain.txt > /tmp/vn-ad.txt
#curl -sS https://dbl.oisd.nl/basic/ > /tmp/oisd_dbl_basic.txt
curl -sS https://small.oisd.nl/domainswild2 > /tmp/oisd_dbl_basic.txt
cat /tmp/vn-ad.txt /tmp/oisd_dbl_basic.txt | grep -E "^[[:space:]]*#|^[^#]" | sort | uniq > /tmp/adlist-oisd-vn.txt
cp -rf /tmp/adlist-oisd-vn.txt diy/rule/
rm -rf /tmp/*

#white&blacklist-ip
curl -sS https://raw.githubusercontent.com/hezhijie0327/GFWList2AGH/main/gfwlist2domain/whitelist_full.txt > /tmp/whitelist_full.txt
curl -sS https://raw.githubusercontent.com/hezhijie0327/GFWList2AGH/main/gfwlist2domain/blacklist_full.txt > /tmp/blacklist_full.txt
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.txt > /tmp/geolite2country_ipv4_6.txt
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/rules/gfw_ip_list.txt > /tmp/gfw_ip_list.txt

#smartdns blacklist-ip
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.txt | \
  sed 's/^/blacklist-ip /' > /tmp/geolite2CNIPDb.conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/rules/gfw_ip_list.txt | \
  sed 's/^/blacklist-ip /' > /tmp/gfw_ip.conf
cat /tmp/CNIPDb.conf /tmp/gfw_ip.conf > /tmp/geolite2CNIPDb_gfw.conf

cp -rf /tmp/*.conf diy/smartdns/
cp -rf /tmp/*.txt diy/rule/
rm -rf /tmp/*
