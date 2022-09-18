# get conf yaml

#sbwml-conf
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/usr/share/mosdns/default.yaml > /tmp/sbwml-default.yaml
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config_custom.yaml > /tmp/sbwml-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml > /tmp/easymosdns-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/hezhijie0327/CMA_DNS/main/mosdns/config.yaml > /tmp/hezhijie0327-conf.yaml

cp -rf /tmp/*.yaml diy/mosdns/
rm -rf /tmp/*

#rules && Geosite GeoIP && cndbIP data
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.dat > /tmp/GeoIP_CNIPDb.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat > /tmp/geosite.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat > /tmp/geoip.dat

cp -rf /tmp/*.dat diy/mosdns/data/
rm -rf /tmp/*

#smartdns blacklist-ip
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb_geolite2/country_ipv4_6.txt
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/rules/gfw_ip_list.txt
cat country_ipv4_6.txt gfw_ip_list.txt > tempblackip.txt
sed 's/^/blacklist-ip /' > /tmp/CNIPDb_gfw.conf
cp -rf /tmp/*.conf diy/smartdns/
rm -rf /tmp/*
