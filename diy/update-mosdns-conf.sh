# get conf yaml
#sbwml-conf
curl -sS https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config_custom.yaml diy/mosdns/sbwml-conf.conf

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml diy/mosdns/easymosdns-conf.conf

#easymosdns-conf
curl -sS https://raw.githubusercontent.com/hezhijie0327/CMA_DNS/main/mosdns/config.yaml diy/mosdns/hezhijie0327-conf.conf
