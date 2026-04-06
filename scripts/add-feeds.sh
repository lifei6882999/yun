#!/bin/bash
# ============================================================
# 添加第三方软件源到 OpenWrt 编译系统
# 此脚本应在 OpenWrt 源码根目录下执行
#
# 软件源优先级策略:
#   1. 综合集合 (kenzok8) 先列出，提供广泛覆盖
#   2. 独立维护的高质量源后列出，覆盖综合集合中的同名包
#   3. feeds install -a -f 按顺序安装，后者覆盖前者
# ============================================================

set -e

FEEDS_CONF="feeds.conf.default"

if [ ! -f "$FEEDS_CONF" ]; then
    echo "错误: 未找到 $FEEDS_CONF，请确保在 OpenWrt 源码根目录下执行"
    exit 1
fi

echo "=========================================="
echo " 添加第三方软件源"
echo "=========================================="

# 备份原始配置
cp "$FEEDS_CONF" "${FEEDS_CONF}.bak"

cat >> "$FEEDS_CONF" << 'FEEDS'

# ===================================================================
# 第三方软件源 - Third Party Feeds
# 顺序说明: 综合集合在前 (低优先级), 独立源在后 (高优先级)
#           feeds install -a -f 时后列出的源会覆盖前面的同名包
# ===================================================================

# ----- 综合软件包集合 (最先, 最低优先级) -----

# kenzok8 软件包集合 (包含大量常用插件: alist, adguardhome, ddns-go, filebrowser, etc.)
src-git kenzok8_packages https://github.com/kenzok8/openwrt-packages.git;master
src-git kenzok8_small https://github.com/kenzok8/small.git;master

# ----- 代理 / VPN (独立源, 高优先级, 覆盖综合集合) -----

# Passwall 共享依赖包 (v2ray-core, xray-core, sing-box, hysteria, etc.)
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main

# Passwall
src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main

# Passwall 2
src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main

# SSR Plus+ (HelloWorld)
src-git helloworld https://github.com/fw876/helloworld.git;master

# OpenClash (Clash 客户端, 使用 master 分支以保证稳定性)
src-git openclash https://github.com/vernesong/OpenClash.git;master

# HomeProxy (sing-box 前端)
src-git homeproxy https://github.com/immortalwrt/homeproxy.git;master

# Mihomo (Clash Meta 内核)
src-git mihomo https://github.com/morytyann/OpenWrt-mihomo.git;main

# ----- DNS 工具 -----

# SmartDNS
src-git smartdns https://github.com/pymumu/openwrt-smartdns.git;master
src-git luci_smartdns https://github.com/pymumu/luci-app-smartdns.git;master

# MosDNS
src-git mosdns https://github.com/sbwml/luci-app-mosdns.git;v5

# ----- 主题 (最后, 最高优先级) -----

# Argon 主题
src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master

# Argon 主题配置
src-git argon_config https://github.com/jerrykuku/luci-app-argon-config.git;master
FEEDS

echo "=========================================="
echo " 软件源配置更新完成"
echo "=========================================="

echo ""
echo "当前 feeds 配置:"
echo "------------------------------------------"
cat "$FEEDS_CONF"
echo "------------------------------------------"
