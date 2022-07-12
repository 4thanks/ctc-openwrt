# get conf yaml

#sbwml-conf
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config_custom.yaml > /tmp/sbwml-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml > /tmp/easymosdns-conf.yaml

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/hezhijie0327/CMA_DNS/main/mosdns/config.yaml > /tmp/hezhijie0327-conf.yaml

cp -rf /tmp/*.yaml diy/mosdns/

#rules && Geosite GeoIP && cndbIP data
curl -sS https://github.com/hezhijie0327/CNIPDb/raw/main/cnipdb/country_ipv4_6.dat > /tmp/country_ipv4_6.dat

cp -f /tmp/country_ipv4_6.dat diy/mosdns/country_ipv4_6.dat
