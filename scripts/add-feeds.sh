#!/bin/bash
# ============================================================
# 添加第三方软件源到 OpenWrt 编译系统
# 此脚本应在 OpenWrt 源码根目录下执行
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
# ===================================================================

# ----- 代理 / VPN -----

# Passwall 共享依赖包 (v2ray-core, xray-core, sing-box, etc.)
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

# ----- DNS 工具 -----

# SmartDNS
src-git smartdns https://github.com/pymumu/openwrt-smartdns.git;master
src-git luci_smartdns https://github.com/pymumu/luci-app-smartdns.git;master

# MosDNS
src-git mosdns https://github.com/sbwml/luci-app-mosdns.git;v5

# ----- 主题 -----

# Argon 主题
src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master

# Argon 主题配置
src-git argon_config https://github.com/jerrykuku/luci-app-argon-config.git;master

# ----- 综合软件包集合 -----

# kenzok8 软件包集合 (包含大量常用插件)
src-git kenzok8_packages https://github.com/kenzok8/openwrt-packages.git;master
src-git kenzok8_small https://github.com/kenzok8/small.git;master
FEEDS

echo "=========================================="
echo " 软件源配置更新完成"
echo "=========================================="

echo ""
echo "当前 feeds 配置:"
echo "------------------------------------------"
cat "$FEEDS_CONF"
echo "------------------------------------------"
