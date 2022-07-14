# get conf yaml

#sbwml-conf
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config_custom.yaml > /tmp/sbwml-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml > /tmp/easymosdns-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/hezhijie0327/CMA_DNS/main/mosdns/config.yaml > /tmp/hezhijie0327-conf.yaml

cp -rf /tmp/*.yaml diy/mosdns/
rm -rf /tmp/*

#rules && Geosite GeoIP && cndbIP data
curl -sS https://raw.githubusercontent.com/hezhijie0327/CNIPDb/main/cnipdb/country_ipv4_6.dat > /tmp/datGeoIP_CNIPDb.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat > /tmp/geosite.dat
curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat > /tmp/geoip.dat

cp -rf /tmp/*.dat diy/mosdns/data/
rm -rf /tmp/*
