#!/bin/bash
# ============================================================
# 整理编译产物为 opkg 仓库结构
# 用法: organize-repo.sh <BUILD_DIR> <REPO_DIR> <VERSION> <TARGET> <SUBTARGET> <ARCH> <OWNER> <REPO_NAME>
# ============================================================

set -e

BUILD_DIR="${1:?缺少参数: BUILD_DIR}"
REPO_DIR="${2:?缺少参数: REPO_DIR}"
VERSION="${3:?缺少参数: VERSION}"
TARGET="${4:?缺少参数: TARGET}"
SUBTARGET="${5:?缺少参数: SUBTARGET}"
ARCH="${6:?缺少参数: ARCH}"
OWNER="${7:?缺少参数: OWNER}"
REPO_NAME="${8:?缺少参数: REPO_NAME}"

PAGES_URL="https://${OWNER}.github.io/${REPO_NAME}"

echo "=========================================="
echo " 整理软件仓库"
echo "=========================================="
echo " 源目录: $BUILD_DIR"
echo " 目标目录: $REPO_DIR"
echo " 版本: $VERSION"
echo " 平台: $TARGET/$SUBTARGET"
echo " 架构: $ARCH"
echo "=========================================="

# 清理目标目录
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"

# 禁用 Jekyll 处理
touch "$REPO_DIR/.nojekyll"

# ===== 复制软件包 =====

# 1. 复制目标平台包 (内核模块等)
if [ -d "$BUILD_DIR/bin/targets/$TARGET/$SUBTARGET/packages" ]; then
    echo "复制目标平台软件包..."
    mkdir -p "$REPO_DIR/targets/$TARGET/$SUBTARGET"
    cp -r "$BUILD_DIR/bin/targets/$TARGET/$SUBTARGET/packages" \
        "$REPO_DIR/targets/$TARGET/$SUBTARGET/"
    KMOD_COUNT=$(find "$REPO_DIR/targets/$TARGET/$SUBTARGET/packages" -name "*.ipk" | wc -l)
    echo "  内核模块: $KMOD_COUNT 个"
fi

# 2. 复制各软件源包
if [ -d "$BUILD_DIR/bin/packages/$ARCH" ]; then
    echo "复制用户态软件包..."
    mkdir -p "$REPO_DIR/packages/$ARCH"
    for feed_dir in "$BUILD_DIR/bin/packages/$ARCH"/*/; do
        if [ -d "$feed_dir" ]; then
            feed_name=$(basename "$feed_dir")
            cp -r "$feed_dir" "$REPO_DIR/packages/$ARCH/"
            PKG_COUNT=$(find "$REPO_DIR/packages/$ARCH/$feed_name" -name "*.ipk" | wc -l)
            echo "  $feed_name: $PKG_COUNT 个"
        fi
    done
fi

# 3. 复制 SDK 和 ImageBuilder (如果存在)
mkdir -p "$REPO_DIR/supplementary"
for pattern in "openwrt-sdk-*.tar.zst" "openwrt-imagebuilder-*.tar.zst" "sha256sums"; do
    for f in "$BUILD_DIR/bin/targets/$TARGET/$SUBTARGET"/$pattern; do
        if [ -f "$f" ]; then
            cp "$f" "$REPO_DIR/supplementary/"
            echo "复制: $(basename "$f")"
        fi
    done
done

# ===== 生成统计信息 =====
TOTAL_IPK=$(find "$REPO_DIR" -name "*.ipk" | wc -l)
TOTAL_SIZE=$(du -sh "$REPO_DIR" | cut -f1)

# ===== 生成 opkg 配置文件 =====
cat > "$REPO_DIR/opkg-config.conf" << EOF
# OpenWrt 自定义云源配置
# 版本: $VERSION | 平台: $TARGET/$SUBTARGET | 架构: $ARCH
# 生成日期: $(date '+%Y-%m-%d %H:%M:%S')
#
# 使用方法:
#   1. 备份原配置: cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.bak
#   2. 替换配置: 将以下内容写入 /etc/opkg/distfeeds.conf
#   3. 禁用签名检查: sed -i 's/option check_signature/# option check_signature/' /etc/opkg.conf
#   4. 更新列表: opkg update

src/gz custom_core ${PAGES_URL}/targets/${TARGET}/${SUBTARGET}/packages
src/gz custom_base ${PAGES_URL}/packages/${ARCH}/base
src/gz custom_luci ${PAGES_URL}/packages/${ARCH}/luci
src/gz custom_packages ${PAGES_URL}/packages/${ARCH}/packages
src/gz custom_routing ${PAGES_URL}/packages/${ARCH}/routing
src/gz custom_telephony ${PAGES_URL}/packages/${ARCH}/telephony
EOF

# 添加第三方软件源配置
for feed_dir in "$REPO_DIR/packages/$ARCH"/*/; do
    if [ -d "$feed_dir" ]; then
        feed_name=$(basename "$feed_dir")
        case "$feed_name" in
            base|luci|packages|routing|telephony)
                # 已在上面添加，跳过
                ;;
            *)
                echo "src/gz custom_${feed_name} ${PAGES_URL}/packages/${ARCH}/${feed_name}" \
                    >> "$REPO_DIR/opkg-config.conf"
                ;;
        esac
    fi
done

# ===== 生成首页 index.html =====
# 收集各 feed 信息
FEED_ROWS=""
for feed_dir in "$REPO_DIR/packages/$ARCH"/*/; do
    if [ -d "$feed_dir" ]; then
        feed_name=$(basename "$feed_dir")
        pkg_count=$(find "$feed_dir" -name "*.ipk" | wc -l)
        FEED_ROWS="${FEED_ROWS}<tr><td><a href=\"packages/${ARCH}/${feed_name}/\">${feed_name}</a></td><td>${pkg_count}</td></tr>"
    fi
done

KMOD_ROW=""
if [ -d "$REPO_DIR/targets/$TARGET/$SUBTARGET/packages" ]; then
    kmod_count=$(find "$REPO_DIR/targets/$TARGET/$SUBTARGET/packages" -name "*.ipk" | wc -l)
    KMOD_ROW="<tr><td><a href=\"targets/${TARGET}/${SUBTARGET}/packages/\">kernel modules</a></td><td>${kmod_count}</td></tr>"
fi

cat > "$REPO_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenWrt 云源 - ${VERSION}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; color: #333; background: #f5f5f5; }
        .container { background: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 25px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px 15px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #3498db; color: white; }
        tr:hover { background: #f0f8ff; }
        a { color: #3498db; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .info { background: #e8f4f8; border-left: 4px solid #3498db; padding: 15px; margin: 15px 0; border-radius: 0 4px 4px 0; }
        .code { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 4px; overflow-x: auto; font-family: 'Courier New', monospace; font-size: 14px; white-space: pre; }
        .stats { display: flex; gap: 20px; flex-wrap: wrap; margin: 15px 0; }
        .stat-card { background: #3498db; color: white; padding: 15px 20px; border-radius: 8px; flex: 1; min-width: 150px; text-align: center; }
        .stat-card .number { font-size: 28px; font-weight: bold; }
        .stat-card .label { font-size: 14px; opacity: 0.9; }
        footer { text-align: center; margin-top: 20px; color: #999; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📦 OpenWrt 云源</h1>

        <div class="stats">
            <div class="stat-card">
                <div class="number">${TOTAL_IPK}</div>
                <div class="label">软件包总数</div>
            </div>
            <div class="stat-card">
                <div class="number">${VERSION}</div>
                <div class="label">OpenWrt 版本</div>
            </div>
            <div class="stat-card">
                <div class="number">${TARGET}/${SUBTARGET}</div>
                <div class="label">目标平台</div>
            </div>
        </div>

        <div class="info">
            <strong>📋 平台信息:</strong> ${TARGET}/${SUBTARGET} (${ARCH})<br>
            <strong>📅 构建日期:</strong> $(date '+%Y-%m-%d %H:%M:%S')<br>
            <strong>📊 总大小:</strong> ${TOTAL_SIZE}
        </div>

        <h2>📂 软件源列表</h2>
        <table>
            <tr><th>软件源</th><th>包数量</th></tr>
            ${KMOD_ROW}
            ${FEED_ROWS}
        </table>

        <h2>⚙️ 快速配置</h2>
        <p>在路由器上执行以下命令配置此云源:</p>
        <div class="code">
# 备份原配置
cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.bak

# 下载新配置
wget -O /etc/opkg/distfeeds.conf ${PAGES_URL}/opkg-config.conf

# 禁用签名检查
sed -i 's/option check_signature/# option check_signature/' /etc/opkg.conf

# 更新软件包列表
opkg update</div>

        <h2>📁 目录结构</h2>
        <table>
            <tr><th>路径</th><th>说明</th></tr>
            <tr><td><a href="targets/">targets/</a></td><td>目标平台软件包 (内核模块)</td></tr>
            <tr><td><a href="packages/">packages/</a></td><td>用户态软件包 (按架构分类)</td></tr>
            <tr><td><a href="supplementary/">supplementary/</a></td><td>SDK / ImageBuilder</td></tr>
            <tr><td><a href="opkg-config.conf">opkg-config.conf</a></td><td>opkg 配置文件</td></tr>
        </table>
    </div>
    <footer>
        自动构建于 $(date '+%Y-%m-%d %H:%M:%S') | Powered by GitHub Actions
    </footer>
</body>
</html>
HTMLEOF

# ===== 复制设备端配置脚本 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/setup-opkg.sh" ]; then
    # 替换脚本中的默认 URL 为实际地址 (使用 awk 避免 sed 特殊字符问题)
    awk -v url="$PAGES_URL" '{gsub(/DEFAULT_REPO_URL="[^"]*"/, "DEFAULT_REPO_URL=\"" url "\""); print}' \
        "$SCRIPT_DIR/setup-opkg.sh" > "$REPO_DIR/setup-opkg.sh"
    chmod +x "$REPO_DIR/setup-opkg.sh"
    echo "已复制设备端配置脚本"
fi

echo "=========================================="
echo " 仓库整理完成"
echo " 总计: $TOTAL_IPK 个软件包 ($TOTAL_SIZE)"
echo " 输出目录: $REPO_DIR"
echo "=========================================="
