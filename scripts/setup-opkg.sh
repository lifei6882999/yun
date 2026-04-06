#!/bin/sh
# ============================================================
# OpenWrt 云源配置脚本
# 在路由器上运行此脚本以配置自定义 opkg 软件源
#
# 用法:
#   wget -O /tmp/setup-opkg.sh <PAGES_URL>/setup-opkg.sh && sh /tmp/setup-opkg.sh
#
# 或手动指定云源地址:
#   sh setup-opkg.sh https://your-username.github.io/yun
# ============================================================

# ===== 默认配置 (请根据实际情况修改) =====
DEFAULT_REPO_URL="https://lifei6882999.github.io/yun"
TARGET="mediatek"
SUBTARGET="filogic"
ARCH="aarch64_cortex-a53"
# ==========================================

REPO_URL="${1:-$DEFAULT_REPO_URL}"
DISTFEEDS="/etc/opkg/distfeeds.conf"
OPKG_CONF="/etc/opkg.conf"

echo "=========================================="
echo " OpenWrt 云源配置工具"
echo "=========================================="
echo " 云源地址: $REPO_URL"
echo "=========================================="

# 检查是否在 OpenWrt 系统上运行
if [ ! -f "$OPKG_CONF" ]; then
    echo "错误: 未找到 $OPKG_CONF，请确保在 OpenWrt 系统上运行此脚本"
    exit 1
fi

# ===== 自动检测设备信息 =====
echo ""
echo "正在检测设备信息..."

# 检测架构
DETECTED_ARCH=""
if command -v opkg >/dev/null 2>&1; then
    DETECTED_ARCH=$(opkg print-architecture 2>/dev/null | awk '/arch/{print $2}' | grep -v "all\|noarch" | tail -1)
fi
if [ -z "$DETECTED_ARCH" ] && [ -f "/etc/openwrt_release" ]; then
    DETECTED_ARCH=$(. /etc/openwrt_release && echo "$DISTRIB_ARCH")
fi

# 检测目标平台
DETECTED_TARGET=""
DETECTED_SUBTARGET=""
if [ -f "/etc/openwrt_release" ]; then
    DETECTED_TARGET=$(. /etc/openwrt_release && echo "$DISTRIB_TARGET" | cut -d/ -f1)
    DETECTED_SUBTARGET=$(. /etc/openwrt_release && echo "$DISTRIB_TARGET" | cut -d/ -f2)
fi

# 检测内核版本
DEVICE_KERNEL=""
if command -v opkg >/dev/null 2>&1; then
    DEVICE_KERNEL=$(opkg info kernel 2>/dev/null | grep "^Version:" | awk '{print $2}')
fi

echo "  架构: ${DETECTED_ARCH:-未检测到}"
echo "  平台: ${DETECTED_TARGET:-未检测到}/${DETECTED_SUBTARGET:-未检测到}"
echo "  内核: ${DEVICE_KERNEL:-未检测到}"

# 架构兼容性检查
if [ -n "$DETECTED_ARCH" ] && [ "$DETECTED_ARCH" != "$ARCH" ]; then
    echo ""
    echo "❌ 错误: 架构不匹配!"
    echo "   设备架构: $DETECTED_ARCH"
    echo "   云源架构: $ARCH"
    echo "   此云源不适用于您的设备。"
    exit 1
fi

# 平台兼容性检查
if [ -n "$DETECTED_TARGET" ] && [ "$DETECTED_TARGET" != "$TARGET" ]; then
    echo ""
    echo "⚠️ 警告: 目标平台不完全匹配"
    echo "   设备平台: $DETECTED_TARGET/$DETECTED_SUBTARGET"
    echo "   云源平台: $TARGET/$SUBTARGET"
    echo "   用户态软件包可正常安装，但内核模块 (kmod-*) 可能不兼容"
fi

# 内核版本兼容性检查
echo ""
echo "正在检查内核兼容性..."
CLOUD_VERMAGIC=""
if wget -q -O /tmp/version-info.json "${REPO_URL}/version-info.json" 2>/dev/null; then
    # 简单的 JSON 解析 (OpenWrt 上可能没有 jq)
    CLOUD_VERMAGIC=$(grep '"vermagic"' /tmp/version-info.json 2>/dev/null | sed 's/.*"vermagic"[^"]*"\([^"]*\)".*/\1/')
    rm -f /tmp/version-info.json
fi

if [ -n "$DEVICE_KERNEL" ] && [ -n "$CLOUD_VERMAGIC" ] && [ "$CLOUD_VERMAGIC" != "null" ] && [ -n "$CLOUD_VERMAGIC" ]; then
    if [ "$DEVICE_KERNEL" = "$CLOUD_VERMAGIC" ]; then
        echo "  ✅ 内核版本完全匹配: $DEVICE_KERNEL"
        echo "     内核模块 (kmod-*) 可正常安装"
    else
        echo "  ⚠️ 内核版本不匹配!"
        echo "     设备: $DEVICE_KERNEL"
        echo "     云源: $CLOUD_VERMAGIC"
        echo ""
        echo "  内核模块 (kmod-*) 可能无法安装。"
        echo "  用户态软件包 (luci-*, 其他工具) 不受影响。"
        echo ""
        echo "  如需 100% 兼容, 请使用与固件相同的配置编译云源。"
        echo "  详见: https://github.com/lifei6882999/yun#100-兼容模式"
    fi
else
    echo "  ℹ️ 无法自动验证内核兼容性"
    echo "  请手动对比: opkg info kernel | grep Version"
fi

echo ""

# 备份原配置
if [ -f "$DISTFEEDS" ]; then
    cp "$DISTFEEDS" "${DISTFEEDS}.bak.$(date +%Y%m%d%H%M%S)"
    echo "已备份原配置到 ${DISTFEEDS}.bak.*"
fi

# 尝试从云源下载预生成的配置
echo "正在下载云源配置..."
if wget -q -O /tmp/opkg-config.conf "${REPO_URL}/opkg-config.conf" 2>/dev/null; then
    cp /tmp/opkg-config.conf "$DISTFEEDS"
    rm -f /tmp/opkg-config.conf
    echo "已从云源下载并应用配置"
else
    echo "无法下载预生成配置，使用默认配置..."
    # 生成默认配置
    cat > "$DISTFEEDS" << EOF
# OpenWrt 自定义云源 - 自动生成
# 生成日期: $(date '+%Y-%m-%d %H:%M:%S')

src/gz custom_core ${REPO_URL}/targets/${TARGET}/${SUBTARGET}/packages
src/gz custom_base ${REPO_URL}/packages/${ARCH}/base
src/gz custom_luci ${REPO_URL}/packages/${ARCH}/luci
src/gz custom_packages ${REPO_URL}/packages/${ARCH}/packages
src/gz custom_routing ${REPO_URL}/packages/${ARCH}/routing
src/gz custom_telephony ${REPO_URL}/packages/${ARCH}/telephony
EOF
    echo "已生成默认配置"
fi

# 禁用签名检查
if grep -q "^option check_signature" "$OPKG_CONF" 2>/dev/null; then
    echo ""
    echo "⚠️  安全提示: 即将禁用软件包签名验证"
    echo "   自定义云源的软件包未使用官方密钥签名。"
    echo "   禁用签名检查后，opkg 将不会验证软件包来源。"
    echo "   请确保您信任此云源: $REPO_URL"
    echo ""
    sed -i 's/^option check_signature/# option check_signature/' "$OPKG_CONF"
    echo "已禁用签名检查"
fi

echo ""
echo "当前 opkg 软件源配置:"
echo "------------------------------------------"
cat "$DISTFEEDS"
echo "------------------------------------------"

# 更新软件包列表
echo ""
echo "正在更新软件包列表..."
if opkg update; then
    AVAILABLE=$(opkg list 2>/dev/null | wc -l)
    echo ""
    echo "=========================================="
    echo " ✅ 配置完成!"
    echo " 可用软件包: $AVAILABLE 个"
    echo "=========================================="
    echo ""
    echo "常用命令:"
    echo "  opkg update            - 更新软件包列表"
    echo "  opkg list              - 列出所有可用软件包"
    echo "  opkg install <包名>    - 安装软件包"
    echo "  opkg list-installed    - 列出已安装软件包"
    echo ""
    echo "恢复官方源:"
    echo "  cp ${DISTFEEDS}.bak.* $DISTFEEDS"
    echo "  sed -i 's/^# option check_signature/option check_signature/' $OPKG_CONF"
else
    echo ""
    echo "警告: 软件包列表更新失败，请检查网络连接和云源地址"
    echo "云源地址: $REPO_URL"
    exit 1
fi
