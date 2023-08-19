# mosdns
- [一个 DNS 转发器 - OpenWRT ](https://github.com/IrineSistiana/mosdns)
- [EasyMosdns](https://github.com/pmkol/easymosdns)
- [luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns)
- [Clash + MOSDNS + AdGuard Home | DNS Server Configuration ](https://github.com/hezhijie0327/CMA_DNS)
- [Deploy DNS over HTTPS service on PaaS platforms (Heroku, Okteto, etc.) | 在 Heroku / Okteto 等免费 PaaS 服务平台上部署 Mosdns ](https://github.com/wy580477/Mosdns-on-PaaS)

# smartdns
- [smartdns一个本地DNS服务器](https://github.com/pymumu/smartdns)
- [Generate & Combine muti-sources IPDb for China ](https://github.com/hezhijie0327/CNIPDb)
- [Generate diversion list for AdGuard Home and other softwares ](https://github.com/hezhijie0327/GFWList2AGH)
- [EasyMosdns Rules](https://github.com/pmkol/easymosdns/tree/rules)

# paopaodns
- [PaoPao DNS docker一键部署递归DNS的docker镜像](https://github.com/kkkgo/PaoPaoDNS)


#  CloudflareSpeedTest
- [自选优选 IP测试 Cloudflare CDN 延迟和速度，获取最快 IP ！](https://github.com/XIU2/CloudflareSpeedTest)

[mosdns v5测试](https://github.com/XIU2/CloudflareSpeedTest/discussions/317)
```yaml
  - tag: response_IP_Cloudflare
    type: ip_set
    args:
      ips:
        - "1.1.1.0/24"
        - "1.0.0.0/24"
        - "162.158.0.0/15"
        - "104.16.0.0/12"
        - "172.64.0.0/13"
  - tag: query_cf_ip
    type: sequence
    args:
      - matches:
          - 'resp_ip $response_IP_Cloudflare'
        exec: black_hole 127.0.0.1 # 自行修改为最优 IP
  - tag: forward_query
    type: sequence
    args:
      - exec: $sequence
      - exec: jump query_cf_ip

```
