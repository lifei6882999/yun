# OpenWrt 云源 (Package Repository)

[![构建 OpenWrt 云源](https://github.com/lifei6882999/yun/actions/workflows/build-repo.yml/badge.svg)](https://github.com/lifei6882999/yun/actions/workflows/build-repo.yml)

## 📖 项目说明

本仓库为 OpenWrt 自定义云源（opkg 软件包仓库），自动编译 OpenWrt **全量软件包**（含内核模块和用户态应用），并通过 GitHub Pages / Releases 提供在线安装服务。

### ✨ 特性

- **全量编译** - 启用 `CONFIG_ALL_KMODS` 和 `CONFIG_ALL_NONSHARED`，编译所有内核模块和用户态软件包
- **100% 兼容** - 支持同步固件编译配置，确保内核模块 vermagic 完全一致
- **第三方插件** - 集成 Passwall、Passwall2、SSR Plus+、OpenClash、Mihomo、HomeProxy、SmartDNS、MosDNS、Argon 主题等热门第三方插件
- **完美替代** - 可直接替代 OpenWrt 官方 `downloads.openwrt.org` 软件源
- **自动构建** - GitHub Actions 每周自动编译，支持固件仓库触发同步构建
- **智能配置** - 设备端脚本自动检测架构、内核版本并验证兼容性
- **安全加固** - 关闭 `CONFIG_KERNEL_MAGIC_SYSRQ` 和 `CONFIG_KERNEL_DEBUG_FS`，与固件安全设置一致

### 📋 支持平台

| 项目 | 值 |
|------|-----|
| OpenWrt 版本 | v24.10.6 |
| 目标平台 | MediaTek Filogic (MT7981/MT7986/MT7988) |
| 架构 | aarch64_cortex-a53 |
| 适用设备 | CMCC RAX3000M, 红米 AX6000 等 MT7981/MT7986 设备 |

### 📦 包含的第三方插件

| 分类 | 插件 | 说明 |
|------|------|------|
| 代理 | Passwall | 多协议代理客户端 |
| 代理 | Passwall 2 | Passwall 升级版 |
| 代理 | SSR Plus+ | ShadowSocksR Plus+ |
| 代理 | OpenClash | Clash 客户端 |
| 代理 | Mihomo | Clash Meta 内核 |
| 代理 | HomeProxy | sing-box 前端 |
| DNS | SmartDNS | 智能 DNS 解析 |
| DNS | MosDNS | DNS 转发/分流 |
| 主题 | Argon | 热门 LuCI 主题 |
| 综合 | kenzok8 合集 | alist, adguardhome, ddns-go, filebrowser 等大量插件 |

---

## 🚀 使用方法

### 方法一：一键配置（推荐）

在路由器终端（SSH）中执行：

```bash
wget -O /tmp/setup-opkg.sh https://lifei6882999.github.io/yun/setup-opkg.sh && sh /tmp/setup-opkg.sh
```

脚本会自动：
- ✅ 检测设备架构和平台
- ✅ 验证内核版本兼容性
- ✅ 备份原始配置
- ✅ 下载并应用云源配置
- ✅ 更新软件包列表

### 方法二：手动配置

```bash
# 1. 备份原配置
cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.bak

# 2. 下载云源配置
wget -O /etc/opkg/distfeeds.conf https://lifei6882999.github.io/yun/opkg-config.conf

# 3. 禁用签名检查 (自定义云源未签名)
sed -i 's/option check_signature/# option check_signature/' /etc/opkg.conf

# 4. 更新软件包列表
opkg update

# 5. 安装软件包示例
opkg install luci-app-passwall
opkg install luci-theme-argon
opkg install luci-app-openclash
```

### 方法三：从 Release 下载离线包

1. 前往 [Releases](https://github.com/lifei6882999/yun/releases) 页面
2. 下载所需的 `.tar.gz` 包
3. 解压后使用 `opkg install` 安装

---

## 🔗 100% 兼容模式

**默认模式（独立构建）** 使用标准 OpenWrt 配置编译，用户态软件包完全兼容，但内核模块 (kmod-*) 的 vermagic 可能与固件不一致。

**100% 兼容模式** 通过同步固件编译仓库的私有配置（diy 脚本和设备配置），确保云源编译的内核与固件完全一致，所有 kmod 包可直接安装。

### 配置步骤

1. **设置 Secrets**（在本仓库的 Settings → Secrets and variables → Actions）：

   | Secret 名称 | 值 | 说明 |
   |-------------|-----|------|
   | `GH_TOKEN` | Personal Access Token | 需要有私有仓库读取权限 |
   | `CONFIG_REPO` | `mzwrt/config` | 私有配置仓库地址 |

2. **手动触发构建**（Actions → 构建 OpenWrt 云源 → Run workflow）：
   - 填入 OpenWrt 版本 (与固件一致, 如 `v24.10.6`)
   - 填入私有配置仓库地址
   - 填入配置仓库分支 (默认 `main`)

3. **自动触发**（推荐）：在固件编译仓库的 workflow 末尾添加：
   ```yaml
   - name: 触发云源同步构建
     uses: peter-evans/repository-dispatch@v3
     with:
       token: ${{ secrets.GH_TOKEN }}
       repository: lifei6882999/yun
       event-type: trigger-build
   ```

### 验证兼容性

在设备上执行：
```bash
opkg info kernel | grep Version
```
对比输出的版本号与 [Release](https://github.com/lifei6882999/yun/releases) 中标注的 `内核 vermagic` 是否一致。

---

## 🔧 恢复官方源

```bash
# 恢复备份的配置
cp /etc/opkg/distfeeds.conf.bak /etc/opkg/distfeeds.conf

# 重新启用签名检查
sed -i 's/^# option check_signature/option check_signature/' /etc/opkg.conf

# 更新列表
opkg update
```

---

## 🏗️ 仓库结构

```
.
├── .github/
│   └── workflows/
│       └── build-repo.yml          # CI/CD 工作流
├── config/
│   └── seed.config                 # 编译配置种子文件
├── scripts/
│   ├── add-feeds.sh                # 第三方软件源配置脚本
│   ├── organize-repo.sh            # 编译产物整理脚本
│   ├── setup-opkg.sh               # 设备端 opkg 配置脚本
│   ├── diy1.sh                     # [可选] 自定义脚本 (feeds 更新前)
│   └── diy2.sh                     # [可选] 自定义脚本 (feeds 安装后)
└── README.md                       # 本文档
```

### GitHub Pages 部署结构

```
https://lifei6882999.github.io/yun/
├── targets/mediatek/filogic/packages/   # 内核模块 (kmod-*)
├── packages/aarch64_cortex-a53/
│   ├── base/                            # 基础软件包
│   ├── luci/                            # LuCI 界面相关
│   ├── packages/                        # 通用软件包
│   ├── routing/                         # 路由相关
│   ├── telephony/                       # 通信相关
│   ├── passwall_luci/                   # Passwall
│   ├── helloworld/                      # SSR Plus+
│   ├── openclash/                       # OpenClash
│   ├── mihomo/                          # Mihomo (Clash Meta)
│   └── ...                              # 更多第三方软件源
├── opkg-config.conf                     # opkg 配置文件
├── version-info.json                    # 版本和兼容性信息
├── sha256sums.txt                       # 完整性校验
├── setup-opkg.sh                        # 一键配置脚本
└── index.html                           # 浏览首页
```

---

## ⚙️ 自定义构建

### 修改 OpenWrt 版本

在 [Actions](https://github.com/lifei6882999/yun/actions/workflows/build-repo.yml) 页面手动触发构建时，可指定 OpenWrt 版本号。

### 添加更多第三方插件

编辑 `scripts/add-feeds.sh`，按以下格式添加新的软件源：

```bash
src-git <名称> https://github.com/<用户>/<仓库>.git;<分支>
```

> **注意**: 综合集合 (kenzok8) 应列在前面，独立维护的源列在后面。`feeds install -a -f` 按顺序处理，后列出的源优先级更高。

### 使用自定义脚本

将自定义脚本放入 `scripts/` 目录：

- `scripts/diy1.sh` - 在 feeds 更新**之前**执行（用于修改源码）
- `scripts/diy2.sh` - 在 feeds 安装**之后**执行（用于修改配置）

> 100% 兼容模式下，私有配置仓库的 diy 脚本优先级更高。

### 修改编译配置

编辑 `config/seed.config`，修改编译选项。运行 `make defconfig` 后生效。

---

## ⚠️ 注意事项

1. **内核模块兼容性**: 云源中的内核模块 (kmod-*) 需与固件的内核 vermagic 完全一致。使用 [100% 兼容模式](#-100-兼容模式) 可确保一致。

2. **签名验证**: 自定义云源的软件包未使用官方密钥签名，需禁用 opkg 签名检查才能安装。

3. **GitHub Pages 限制**: GitHub Pages 免费版有 1GB 大小限制。如果软件包总量超过此限制，部分包可能无法通过 Pages 访问，但可通过 Releases 下载。

4. **编译时间**: 全量编译所有软件包需要 3-5 小时。GitHub Actions 免费额度有每月限制，建议合理安排构建频率。

5. **首次使用**: 请先在仓库 **Settings → Pages** 中将 Source 设置为 **GitHub Actions**，以启用 Pages 部署。

6. **安全加固**: 云源编译配置已关闭 `CONFIG_KERNEL_MAGIC_SYSRQ` 和 `CONFIG_KERNEL_DEBUG_FS`，与固件安全设置保持一致。

---

## 📊 构建状态

构建日志和详细信息可在 [Actions](https://github.com/lifei6882999/yun/actions) 页面查看。

每次构建完成后：
- 📦 软件包自动部署到 GitHub Pages
- 📥 打包文件（packages, kmods, SDK, ImageBuilder, COMPATIBILITY.txt）上传到 Releases
- 📋 编译日志保存为 Artifacts（保留 7 天）
- 🔍 内核 vermagic 提取并显示在 Release 说明中

---

## 📜 许可证

本项目基于 [MIT License](LICENSE) 开源。
OpenWrt 相关代码遵循其原始许可证。