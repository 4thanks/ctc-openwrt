# get conf yaml

mkdir -p /tmp/confyaml && curl https://raw.githubusercontent.com/sbwml/luci-app-mosdns/master/luci-app-mosdns/root/etc/mosdns/config_custom.yaml > /tmp/confyaml/sbwml-conf.yaml && curl https://raw.githubusercontent.com/pmkol/easymosdns/main/config.yaml > /tmp/confyaml/easymosdns-conf.yaml && curl https://raw.githubusercontent.com/hezhijie0327/CMA_DNS/main/mosdns/config.yaml > /tmp/confyaml/hezhijie0327-conf.yaml && \cp -rf /tmp/confyaml/*.yaml /diy/mosdns && rm -rf /tmp/confyaml/*
