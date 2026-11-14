# EasyWrt

小米 AX3000T / 红米 AX6000 的 ImmortalWrt 云编译固件。
源码：`iscelor/immortalwrt-mt798x-6.6` 的 `fix/80211v` 分支（lyimoexiao 基座 + 802.11v 漫游引导修复）。

## 支持设备

| 设备 | seed 配置 | 产物 |
|---|---|---|
| 小米 AX3000T（MT7981） | `configs/ARM/mt798x/mt7981_ax3000t.config` | `…xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin` |
| 红米 AX6000（MT7986） | `configs/ARM/mt798x/mt7986_ax6000.config` | `…xiaomi_redmi-router-ax6000-stock-squashfs-sysupgrade.bin` |

均为 **stock 分区布局**；登录 `root`，密码为空。

## 出厂默认

AX3000T 出厂即桥接 AP（配置已烤进固件）：

| 项 | 值 |
|---|---|
| 管理地址 | `192.168.6.2/24`，网关 `192.168.6.1` |
| 端口 | `lan2 lan3 lan4 wan` 全部桥进 `br-lan` |
| DHCP / IPv6 RA | 关闭 |
| 2.4G / 5G | `ASUS` / `ASUS_5G`，`sae-mixed`，2.4G auto、5G 固定 149 |
| WiFi 口令 | `Dsa78963`（表单或仓库 Secret 可覆盖） |
| 802.11k / r | 开启；802.11v 默认关闭，见 [`docs/80211v.md`](docs/80211v.md) |
| WAN MAC | 从 Bdata 的 `ethaddr_wan` 读取，每台不同 |

AX6000 保持上游默认（路由 + DHCP，`192.168.6.1`），只改 SSID、加密方式和口令。

> 恢复出厂 = 回到 AP 模式：`192.168.6.2` 且不发 DHCP，电脑要先设静态地址才能进后台。

## 构建

Actions → **build** → Run workflow：

- `device`：`ax3000t`（默认）/ `ax6000` / `all`
- 可填 `ssid_2g`、`ssid_5g`、`wifi_pass`、`lan_ip`，留空取默认

产出 `.bin` + `.sha256` + `build-info.txt`，Release 名为 `EasyWrt-<设备>-<日期>-<短 SHA>`。
首次约 2~3 小时，命中 ccache 后 30~60 分钟。

改设置不用改文件：已刷好的机器 SSH 上去 `uci set …; uci commit …; wifi reload` 即可；
要改出厂值就重跑一次构建。builder 镜像、换分支、加设备的细节见 [`docs/build.md`](docs/build.md)。

## 刷机与救砖

两台都是不死 U-Boot。断电，按住 reset 上电保持 5 秒，浏览器打开：

| 设备 | 地址 | DHCP |
|---|---|---|
| AX3000T | `192.168.10.1` | 正常 |
| AX6000 | `192.168.1.1` | 坏的，电脑设 `192.168.1.200/24` |

分区布局、FIP 备份、`fw_printenv` 的坑见 [`docs/recovery.md`](docs/recovery.md)。

## 目录

```
.github/workflows/  build.yml（唯一构建入口）/ builder-image.yml / cleanup.yml
configs/ARM/mt798x/ ax3000t、ax6000 的 seed 配置（完整 .config）
diy/files/ax3000t/  直接进 rootfs 的 /etc/config（含 @占位符@）
diy/mt798x/         定制脚本：lib.sh / render.py / ax3000t.sh / ax6000.sh
docker/             编译环境镜像
docs/               802.11v 验证、刷机救砖、构建细节
```

`diy/files/<device>/` 在 `prepare_rootfs` 阶段覆盖 rootfs，优先于包默认值；占位符由
`render.py` 纯字面替换，前后都有断言，任何一步不对构建直接失败。

## 注意

- 默认 WiFi 口令是公开的，建议配仓库 Secret `WIFI_PASS`（表单留空即用它）。
- stock layout 直刷有风险，先确认 U-Boot 与分区布局；跨仓库 sysupgrade 不保证兼容。
- `fix/80211v` 基于 lyimoexiao，AX3000T 首刷若 WiFi 异常，把 `REPO_BRANCH` 切到 `fix/80211v-pdv`。
- fork 自 [xiangfeidexiaohuo/EasyWrt](https://github.com/xiangfeidexiaohuo/EasyWrt)。
