---
title: '分析和解决Origin下载提示错误-4:302'
date: 2019-02-28 18:25:16
tags: 
    - network
categories:
    - 日常
---

最近新一代的快递员模拟器《Apex英雄》比较火，打算上去给大家送送快递温暖人心。
然而Origin不让我顺利送快递，直接安装好客户端下载游戏时不断提示”發生了一個無法預期的錯誤。請稍後再試。錯誤: -4:302“。

为了解决这个问题，进行了很多监控调试，尝试了网上的几个方案，最后得到了一个比较合适的解决办法。

**请注意：各地网络情况可能导致最后效果并不一定相同**

如果想直接看到我的最终解决方案，请[点此](#6)

---

# 1 初步尝试

对于这些国际的游戏客户端，出现下载问题第一反应应该就是被**了。所以我第一时间沿袭了魔法的姿势完成了游戏下载。
但是这样会消耗很多的魔法力（流量），毕竟一个客户端就几十G，而且听说其他人下载还是有正常的，所以不太像是直接被**了。

# 2 找到问题

打开抓包工具**Fiddler4**看一下下载时到底发生了什么。

{% asset_img ea-302.png EA CDN 302 %}

原来是EA的下载CDN做了一个重定向，从`http://lvlt.cdn.ea.com/***`定向到`http://120.52.**.**/lvlt.cdn.ea.com/***`。
那么看起来这应该是EA对国内CDN的一个部署，没有用DNS解析到国内节点IP的方式，而是直接重定向到国内的节点IP域名，那么看来是Origin客户端并不支持这么做。
随后我又使用魔法姿势然后查看了一遍抓包，正常下载确实没有重定向，而是直接下载文件，所以客户端就没有报错了。

# 3 换一个CDN？

然后我根据一个女装群大佬们的说法，修改`EACore.ini`这个文件使用**Akamai**的CDN下载。
然而结果还是直接报错，抓包看跟EA自己的CDN走向一样。

{% asset_img akamai-302.png Akamai CDN 302 %}

Akamai的CDN也是用302直接重定向到国内的节点IP域名。从`http://origin-a.akamaihd.net/***`定向到了`http://59.80.44.100/origin-a.akamaihd.net/***`。

# 4 安全模式

既然两个CDN直接走都不行，那就只能尝试Origin设置里的安全模式下载了。
根据官方的说法，这个模式会降低速度，然而抓包后发现这个所谓安全模式，其实就是让CDN连接走Https。
理论上应该是影响不大，毕竟CDN部署全Https已经不是新鲜事了。
但是一开始我还原Origin以后，直接打开这个模式确实速度很慢，不到1MB/s左右的下载。

# 5 DNS

根据以往经验来看，应该就是解析到的节点的问题了。通过抓包，得出EA的HttpsCDN域名是`ssl-lvlt.cdn.ea.com`。
使用`dig`命令分别用国内的DNS和`1.1.1.1`解析得到的都是美国的Level3的IP。

```shell
~ took 14s
➜ dig ssl-lvlt.cdn.ea.com @1.0.0.1

; <<>> DiG 9.11.3-1ubuntu1.5-Ubuntu <<>> ssl-lvlt.cdn.ea.com @1.0.0.1
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 15767
;; flags: qr rd ra; QUERY: 1, ANSWER: 4, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1452
;; QUESTION SECTION:
;ssl-lvlt.cdn.ea.com.           IN      A

;; ANSWER SECTION:
ssl-lvlt.cdn.ea.com.    147     IN      CNAME   ssl-lvlt.cdn.ea.com.c.footprint.net.
ssl-lvlt.cdn.ea.com.c.footprint.net. 60 IN A    67.24.137.250
ssl-lvlt.cdn.ea.com.c.footprint.net. 60 IN A    67.24.141.250
ssl-lvlt.cdn.ea.com.c.footprint.net. 60 IN A    67.24.105.250

;; Query time: 214 msec
;; SERVER: 1.0.0.1#53(1.0.0.1)
;; WHEN: Thu Feb 28 19:01:45 DST 2019
;; MSG SIZE  rcvd: 145


~
➜ geoip 67.24.137.250
["美国","美国","","","level3.com"]

~
➜ dig ssl-lvlt.cdn.ea.com @114.114.114.114

; <<>> DiG 9.11.3-1ubuntu1.5-Ubuntu <<>> ssl-lvlt.cdn.ea.com @114.114.114.114
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 9648
;; flags: qr rd ra; QUERY: 1, ANSWER: 4, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;ssl-lvlt.cdn.ea.com.           IN      A

;; ANSWER SECTION:
ssl-lvlt.cdn.ea.com.    33      IN      CNAME   ssl-lvlt.cdn.ea.com.c.footprint.net.
ssl-lvlt.cdn.ea.com.c.footprint.net. 33 IN A    8.253.129.53
ssl-lvlt.cdn.ea.com.c.footprint.net. 33 IN A    67.27.1.247
ssl-lvlt.cdn.ea.com.c.footprint.net. 33 IN A    8.253.129.77

;; Query time: 15 msec
;; SERVER: 114.114.114.114#53(114.114.114.114)
;; WHEN: Thu Feb 28 19:03:03 DST 2019
;; MSG SIZE  rcvd: 145


~
➜ geoip 8.253.129.53
["美国","加利福尼亚州","洛杉矶","","level3.com"]
```

然后随即强制使用Akamai的CDN，Akamai在安全模式下使用的域名是`origin-a.akamaihd.net`。
然后跟上面一样，分别用国内和1111解析。

```shell
~ 
➜ dig origin-a.akamaihd.net @1.0.0.1                               

; <<>> DiG 9.11.3-1ubuntu1.5-Ubuntu <<>> origin-a.akamaihd.net @1.0.0.1
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 40236
;; flags: qr rd ra; QUERY: 1, ANSWER: 4, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1452
;; QUESTION SECTION:
;origin-a.akamaihd.net.         IN      A

;; ANSWER SECTION:
origin-a.akamaihd.net.  94      IN      CNAME   origin-a.akamaihd.net.edgesuite.net. 
origin-a.akamaihd.net.edgesuite.net. 6636 IN CNAME a1750.w27.akamai.net.
a1750.w27.akamai.net.   20      IN      A       23.55.37.113
a1750.w27.akamai.net.   20      IN      A       23.55.37.89

;; Query time: 202 msec
;; SERVER: 1.0.0.1#53(1.0.0.1)
;; WHEN: Thu Feb 28 19:07:18 DST 2019
;; MSG SIZE  rcvd: 159


~ 
➜ geoip 23.55.37.113
["美国","加利福尼亚州","洛杉矶","","akamai.com"] 
 
~ 
➜ dig origin-a.akamaihd.net @114.114.114.114 

; <<>> DiG 9.11.3-1ubuntu1.5-Ubuntu <<>> origin-a.akamaihd.net @114.114.114.114 
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 23199
;; flags: qr rd ra; QUERY: 1, ANSWER: 10, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;origin-a.akamaihd.net.         IN      A

;; ANSWER SECTION:
origin-a.akamaihd.net.  33      IN      CNAME   origin-a.akamaihd.net.edgesuite.net.
origin-a.akamaihd.net.edgesuite.net. 33 IN CNAME a1750.w27.akamai.net.
a1750.w27.akamai.net.   33      IN      A       124.40.41.85
a1750.w27.akamai.net.   33      IN      A       124.40.41.75
a1750.w27.akamai.net.   33      IN      A       124.40.41.84
a1750.w27.akamai.net.   33      IN      A       124.40.41.76
a1750.w27.akamai.net.   33      IN      A       124.40.41.9
a1750.w27.akamai.net.   33      IN      A       124.40.41.17
a1750.w27.akamai.net.   33      IN      A       124.40.41.86
a1750.w27.akamai.net.   33      IN      A       124.40.41.6

;; Query time: 18 msec
;; SERVER: 114.114.114.114#53(114.114.114.114)
;; WHEN: Thu Feb 28 19:07:34 DST 2019
;; MSG SIZE  rcvd: 255


~ 
➜ 

~ 
➜ geoip 124.40.41.85
["日本","大阪府","大阪","","ntt.com"]
```

基本上问题到这里就算是有一个解了。使用安全模式加上Akamai的日本节点，下载应该没有问题了。
抓了一个链接用wget测试了一下大概能在5MB/s，虽然不够快，但也还算能接受了。
所以立马打开路由器，增加一条Dnsmasq规则`server=/origin-a.akamaihd.net/114.114.114.114`，保证这个域名能解析到日本的节点上。

至此，这个问题基本上就算是解决了。

# 6 总结 <a name="6"></a>

在不考虑用魔法姿势下载的情况下，做以下修改应该能保证一个可接受的速度下载：

+ 修改`EACore.ini`启动Akamai的CDN。
    ```ini
    [connection]
    EnvironmentName=production
    [Feature]
    CdnOverride=akamai
    ```
+ 打开Origin的安全模式下载
+ 保证`origin-a.akamaihd.net`域名解析到日本节点
  + 如果你什么代理/DNS工具都没有使用，可以更换常见的几个公共DNS并用nslookup测试解析。[国内DNS列表](https://www.ip.cn/dns.html)
  + 如果你使用了Dnsmasq，那么增加一条`server=/origin-a.akamaihd.net/114.114.114.114`。
  + 如果你使用了Pac代理（比如酸爽），则在user-list里增加`@@||origin-a.akamaihd.net^`使其不从远程服务器解析。
  + 其他方案请自行解决。

# 7 最后

到这里，我又把最开始302的地址拿出来分析了一下，首先IP都是国内的，甚至EA的CDN转发还是廊坊的IP。
通过`wget`测试了一下能稳定在15MB/s。看来EA本意是想改善国内的下载体验，但是他们可能只是随手弄了一下，并没有实际测试。
导致，CDN给了一个超好的节点，但是客户端不支持所以直接不能下载。
果然，烂橘子名副其实。