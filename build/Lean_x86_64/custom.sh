
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
# sed -i 's@#src-git helloworld@src-git helloworld@g' feeds.conf.default # 启用helloworld
# sed -i 's@src-git luci@# src-git luci@g' feeds.conf.default # 禁用18.06Luci
# sed -i 's@## src-git luci@src-git luci@g' feeds.conf.default # 启用23.05Luci
cat feeds.conf.default

# 添加第三方软件包
git clone https://github.com/db-one/dbone-packages.git -b 18.06 package/dbone-packages

# 更新并安装源
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a -f

# 删除部分默认包
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/luci/themes/luci-theme-argon

# 自定义定制选项
NET="package/base-files/files/bin/config_generate"
ZZZ="package/lean/default-settings/files/zzz-default-settings"
# 读取内核版本
KERNEL_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_PATCHVER | sed 's/^.\{17\}//g')
KERNEL_TESTING_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_TESTING_PATCHVER | sed 's/^.\{25\}//g')
if [[ $KERNEL_TESTING_PATCHVER > $KERNEL_PATCHVER ]]; then
  sed -i "s/$KERNEL_PATCHVER/$KERNEL_TESTING_PATCHVER/g" target/linux/x86/Makefile        # 修改内核版本为最新
  echo "内核版本已更新为 $KERNEL_TESTING_PATCHVER"
else
  echo "内核版本不需要更新"
fi

#
sed -i 's#192.168.1.1#10.0.0.1#g' $NET                                                    # 定制默认IP
# sed -i 's#OpenWrt#OpenWrt-X86#g' $NET                                                     # 修改默认名称为OpenWrt-X86
sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' $ZZZ                                             # 取消系统默认密码
sed -i "s/OpenWrt /ONE build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" $ZZZ              # 增加自己个性名称
# sed -i "/uci commit luci/i\uci set luci.main.mediaurlbase=/luci-static/neobird" $ZZZ        # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)
sed -i 's#localtime  = os.date()#localtime  = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")#g' package/lean/autocore/files/*/index.htm               # 修改默认时间格式

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
sed -i 's#%D %V, %C#%D %V, %C Lean_x86_64#g' package/base-files/files/etc/banner               # 自定义banner显示
sed -i 's@list listen_https@# list listen_https@g' package/network/services/uhttpd/files/uhttpd.config               # 停止监听443端口
# sed -i 's#option commit_interval 24h#option commit_interval 10m#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计写入为10分钟
# sed -i 's#option database_generations 10#option database_generations 3#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据周期
# sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据存放默认位置
sed -i 's#interval: 5#interval: 1#g' feeds/luci/applications/luci-app-wrtbwmon/htdocs/luci-static/wrtbwmon/wrtbwmon.js               # wrtbwmon默认刷新时间更改为1秒
sed -i '/exit 0/i\ethtool -s eth0 speed 10000 duplex full' package/base-files/files//etc/rc.local               # 强制显示2500M和全双工（默认PVE下VirtIO不识别）

# ●●●●●●●●●●●●●●●●●●●●●●●●定制部分●●●●●●●●●●●●●●●●●●●●●●●● #

cat >> $ZZZ <<-EOF
# 设置旁路由模式
uci set network.lan.gateway='10.0.0.254'                     # 旁路由设置 IPv4 网关
uci set network.lan.dns='223.5.5.5 119.29.29.29'            # 旁路由设置 DNS(多个DNS要用空格分开)
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
uci delete network.lan.type                                  # 旁路由桥接模式-禁用
uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')

# 旁路IPV6需要全部禁用
uci set network.lan.ip6assign=''                             # IPV6分配长度-禁用
uci set dhcp.lan.ra=''                                       # 路由通告服务-禁用
uci set dhcp.lan.dhcpv6=''                                   # DHCPv6 服务-禁用
uci set dhcp.lan.ra_management=''                            # DHCPv6 模式-禁用

# 如果有用IPV6的话,可以使用以下命令创建IPV6客户端(LAN口)（去掉全部代码uci前面#号生效）
uci set network.ipv6=interface
uci set network.ipv6.proto='dhcpv6'
uci set network.ipv6.ifname='@lan'
uci set network.ipv6.reqaddress='try'
uci set network.ipv6.reqprefix='auto'
uci set firewall.@zone[0].network='lan ipv6'

EOF

# 修改退出命令到最后
sed -i '/exit 0/d' $ZZZ && echo "exit 0" >> $ZZZ

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
# 下载 OpenClash 内核
grep "CONFIG_PACKAGE_luci-app-openclash=y" $WORKPATH/$CUSTOM_SH >/dev/null
if [ $? -eq 0 ]; then
  echo "正在执行：为OpenClash下载内核"
  mkdir -p $HOME/clash-core
  mkdir -p $HOME/files/etc/openclash/core
  cd $HOME/clash-core
# 下载Dve内核
  wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-amd64.tar.gz
  if [[ $? -ne 0 ]];then
    wget -q https://github.com/vernesong/OpenClash/releases/download/Clash/clash-linux-amd64.tar.gz
  else
    echo "OpenClash Dve内核压缩包下载成功，开始解压文件"
  fi
  tar -zxvf clash-linux-amd64.tar.gz
  if [[ -f "$HOME/clash-core/clash" ]]; then
    mkdir -p $HOME/files/etc/openclash/core
    mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash
    chmod +x $HOME/files/etc/openclash/core/clash
    echo "OpenClash Dve内核配置成功"
  else
    echo "OpenClash Dve内核配置失败"
  fi
  rm -rf $HOME/clash-core/clash-linux-amd64.tar.gz
# 下载Meta内核
  wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  if [[ $? -ne 0 ]];then
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  else
    echo "OpenClash Meta内核压缩包下载成功，开始解压文件"
  fi
  tar -zxvf clash-linux-amd64.tar.gz
  if [[ -f "$HOME/clash-core/clash" ]]; then
    mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash_meta
    chmod +x $HOME/files/etc/openclash/core/clash_meta
    echo "OpenClash Meta内核配置成功"
  else
    echo "OpenClash Meta内核配置失败"
  fi
  rm -rf $HOME/clash-core/clash-linux-amd64.tar.gz
# 下载TUN内核
  wget -q  https://raw.githubusercontent.com/vernesong/OpenClash/core/master/core_version
  TUN="clash-linux-amd64-"$(sed -n '2p' core_version)".gz"
  wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/premium/$TUN
  if [[ $? -ne 0 ]];then
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/premium/$TUN
  else
    echo "OpenClash TUN内核压缩包下载成功，开始解压文件"
  fi
  gunzip  $TUN
  TUNS="$(ls | grep -Eo "clash-linux-amd64-.*")"
  if [[ -f "$HOME/clash-core/$TUNS" ]]; then
    mv -f $HOME/clash-core/clash-linux-amd64-* $HOME/files/etc/openclash/core/clash_tun
    chmod +x $HOME/files/etc/openclash/core/clash_tun
    echo "OpenClash TUN内核配置成功"
  else
    echo "OpenClash TUN内核配置失败"
  fi
  rm -rf $HOME/clash-core/$TUN

  rm -rf $HOME/clash-core
fi

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# 创建自定义配置文件

cd $WORKPATH
touch ./.config

#
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分●●●●●●●●●●●●●●●●●●●●●●●●
# 

# 
# 如果不对本区块做出任何编辑, 则生成默认配置固件. 
# 

# 以下为定制化固件选项和说明:
#

#
# 有些插件/选项是默认开启的, 如果想要关闭, 请参照以下示例进行编写:
# 
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#        ■|  # 取消编译VMware镜像:                    |■
#        ■|  cat >> .config <<EOF                   |■
#        ■|  # CONFIG_VMDK_IMAGES is not set        |■
#        ■|  EOF                                    |■
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#

# 
# 以下是一些提前准备好的一些插件选项.
# 直接取消注释相应代码块即可应用. 不要取消注释代码块上的汉字说明.
# 如果不需要代码块里的某一项配置, 只需要删除相应行.
#
# 如果需要其他插件, 请按照示例自行添加.
# 注意, 只需添加依赖链顶端的包. 如果你需要插件 A, 同时 A 依赖 B, 即只需要添加 A.
# 
# 无论你想要对固件进行怎样的定制, 都需要且只需要修改 EOF 回环内的内容.
# 





# 常用LuCI插件:
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y

# CONFIG_PACKAGE_chinadns-ng is not set
# CONFIG_PACKAGE_coreutils is not set
# CONFIG_PACKAGE_dns2socks is not set
# CONFIG_PACKAGE_dns2tcp is not set
# CONFIG_PACKAGE_etherwake is not set
# CONFIG_PACKAGE_kmod-nf-conntrack-netlink is not set
# CONFIG_PACKAGE_kmod-shortcut-fe is not set
# CONFIG_PACKAGE_kmod-shortcut-fe-cm is not set

# CONFIG_PACKAGE_kmod-tcp-bbr is not set
# CONFIG_PACKAGE_libcares is not set
# CONFIG_PACKAGE_libev is not set
# CONFIG_PACKAGE_libmbedtls is not set

# CONFIG_PACKAGE_libopenssl-legacy is not set

# CONFIG_PACKAGE_libpcre2 is not set
# CONFIG_PACKAGE_libsodium is not set
# CONFIG_PACKAGE_libudns is not set
# CONFIG_PACKAGE_lua-neturl is not set
# CONFIG_PACKAGE_luci-app-accesscontrol is not set
# CONFIG_PACKAGE_luci-app-arpbind is not set
# CONFIG_PACKAGE_luci-app-ddns is not set
# CONFIG_PACKAGE_luci-app-filetransfer is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-ssr-plus is not set
# CONFIG_PACKAGE_luci-app-turboacc is not set
# CONFIG_PACKAGE_luci-app-upnp is not set
# CONFIG_PACKAGE_luci-app-vlmcsd is not set
# CONFIG_PACKAGE_luci-app-vsftpd is not set
# CONFIG_PACKAGE_luci-app-wol is not set
# CONFIG_PACKAGE_luci-lib-fs is not set
# CONFIG_PACKAGE_luci-lib-ipkg is not set
CONFIG_PACKAGE_luci-proto-ipv6=y
# CONFIG_PACKAGE_microsocks is not set
# CONFIG_PACKAGE_miniupnpd is not set
# CONFIG_PACKAGE_mosdns is not set
# CONFIG_PACKAGE_nlbwmon is not set

# CONFIG_PACKAGE_pdnsd-alt is not set
# CONFIG_PACKAGE_resolveip is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-server is not set
# CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-check is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-local is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set
# CONFIG_PACKAGE_simple-obfs-client is not set
CONFIG_PACKAGE_snmpd=y
# CONFIG_PACKAGE_tcping is not set
# CONFIG_PACKAGE_vlmcsd is not set
# CONFIG_PACKAGE_vsftpd-alt is not set
# CONFIG_PACKAGE_wol is not set
# CONFIG_PACKAGE_xray-core is not set

EOF



# 
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分结束●●●●●●●●●●●●●●●●●●●●●●●● #
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回目录
cd $HOME

# 配置文件创建完成
