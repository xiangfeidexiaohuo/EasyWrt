# EasyWrt

基于 [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) 的云编译固件。
当前指向 `iscelor/immortalwrt-mt798x-6.6` 的 `fix/80211v` 分支（lyimoexiao 基座 + 802.11v 漫游引导修复，
详见该仓库 `docs/80211v-steering.md`）。

## 支持设备

| 设备 | 配置 | 产物 | 管理地址 |
|---|---|---|---|
| 小米 AX3000T（MT7981） | `configs/ARM/mt798x/mt7981_ax3000t.config` | `immortalwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin` | `192.168.5.1` |
| 红米 AX6000（MT7986） | `configs/ARM/mt798x/mt7986_ax6000.config` | `immortalwrt-mediatek-filogic-xiaomi_redmi-router-ax6000-stock-squashfs-sysupgrade.bin` | `192.168.6.1` |

- 分区布局：**stock layout**
- U-Boot 地址：AX3000T `192.168.1.1` / AX6000 `192.168.31.1`
- 登录：`root`，密码为空

## 默认无线

| 设备 | 2.4G SSID | 5G SSID | 加密 |
|---|---|---|---|
| AX3000T | `ImmortalWrt-2.4G` | `ImmortalWrt-5G` | WPA2/WPA3 混合（`sae-mixed`） |
| AX6000 | `ASUS` | `ASUS_5G` | 同上 |

口令取自构建时的 `WIFI_PASS` 环境变量，默认值写在 `build.yml` 的 `env` 里。

**建议改用仓库 Secret**：Settings → Secrets and variables → Actions → New repository secret，
名字 `WIFI_PASS`。不设置则使用公开的默认口令，等于固件出厂口令人人皆知。

## 构建

Actions → **build** → Run workflow，设备可选 `all` / `ax3000t` / `ax6000`。
也可以用 `repository_dispatch` 触发全部设备。

每次构建产出三个文件：

| 文件 | 内容 |
|---|---|
| `*.bin` | 固件 |
| `*.sha256` | 校验和 |
| `build-info.txt` | 源码仓库/分支/提交 SHA、配置路径、构建时间、镜像大小 |

Release 名称格式：`EasyWrt-<设备>-<日期>-<源码短 SHA>`，每个固件都能溯源到确切的源码提交。

首次构建约 2~3 小时；命中 ccache 后通常 30~60 分钟（缓存按设备 + 配置哈希区分）。

## 目录结构

```
.github/workflows/
  build.yml              # 唯一构建入口，matrix 展开设备
  cleanup.yml            # 清理历史运行记录（7 天 / 保留 3 次）
configs/ARM/mt798x/      # 各机型的 seed 配置（完整 .config）
diy/mt798x/
  feed.sh                # 额外 feed 挂载点（当前为空）
  lib.sh                 # 公共函数：改 IP / SSID / WiFi 口令，均带断言
  ax3000t.sh             # AX3000T 定制：LAN 192.168.5.1
  ax6000.sh              # AX6000 定制：SSID 改为 ASUS / ASUS_5G
diy/aliupload.py         # 未接线，预留给网盘上传
```

定制脚本的行为约定：**任何一处 sed 锚点没命中就直接让构建失败**，不允许静默产出一个
"看起来正常、实际是开放热点"的固件。

## 换源码分支

改 `.github/workflows/build.yml` 顶部的 `REPO_BRANCH`：

| 分支 | 说明 |
|---|---|
| `fix/80211v` | 默认。lyimoexiao 基座 + 802.11v 修复 |
| `fix/80211v-pdv` | padavanonly 基座 + 同样的修复。AX3000T 若出现 WiFi 异常（ly 的 MT7981 EEPROM 改动）切这个 |

## 增加一台新设备

1. 放 seed 配置：`configs/ARM/mt798x/<name>.config`（`make menuconfig` 后 `cp .config` 得到）
2. 写定制脚本：`diy/mt798x/<name>.sh`，`source` 同目录的 `lib.sh`，按需调用
   `apply_lan_ip` / `apply_ssid` / `apply_wifi_key`
3. 在 `build.yml` 的 `setup` 步骤里给 `all` JSON 加一条
   （`device` / `label` / `config` / `rom` 四个字段，`device` 必须与脚本同名）

## 注意

- stock layout 直接刷写有风险，先确认 U-Boot 与分区布局；跨仓库 sysupgrade 不保证兼容。
- 仓库里其余 7 份 `configs/ARM/mt798x/*.config`（a31、ct3003、nx30pro、q30、rax3000m×2、t7、wr30u）
  目前没有对应的构建条目，需要时按上面第 3 步接进去。
- 本仓库为 [xiangfeidexiaohuo/EasyWrt](https://github.com/xiangfeidexiaohuo/EasyWrt) 的 fork。
