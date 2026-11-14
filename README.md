# EasyWrt

基于 [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) 的云编译固件。
当前指向 `iscelor/immortalwrt-mt798x-6.6` 的 `fix/80211v` 分支（lyimoexiao 基座 + 802.11v 漫游引导修复，
详见该仓库 `docs/80211v-steering.md`）。

## 支持设备

| 设备 | 配置 | 产物 | 管理地址 |
|---|---|---|---|
| 小米 AX3000T（MT7981） | `configs/ARM/mt798x/mt7981_ax3000t.config` | `immortalwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin` | `192.168.6.2`（AP 模式） |
| 红米 AX6000（MT7986） | `configs/ARM/mt798x/mt7986_ax6000.config` | `immortalwrt-mediatek-filogic-xiaomi_redmi-router-ax6000-stock-squashfs-sysupgrade.bin` | `192.168.6.1` |

- 分区布局：**stock layout**
- U-Boot 恢复地址（`mtkupgrade fw`，TFTP）：AX3000T 设备 `192.168.10.1` / 电脑 `192.168.10.100`；
  AX6000 设备 `192.168.31.1` / 电脑 `192.168.31.100`。这两组是从各自 U-Boot 环境
  （`fw_printenv` 的 `ipaddr` / `serverip`）读出来的，不是 OpenWrt 的 LAN 地址——别混。
- 登录：`root`，密码为空

## AX3000T 出厂状态（配置已烤进固件）

| 项 | 值 |
|---|---|
| 角色 | **桥接 AP**（不做 NAT、不拨号） |
| 管理地址 | `192.168.6.2/24`，网关指向 `192.168.6.1` |
| 端口 | `lan2 lan3 lan4 wan` 全部桥进 `br-lan`（插哪个口都能进后台） |
| DHCP / IPv6 RA | **关闭**（`ignore 1` + `ra disabled` + `dhcpv6 disabled`） |
| 2.4G / 5G | `ASUS` / `ASUS_5G`，`sae-mixed`，2.4G 信道 auto、5G 固定 149 |
| WiFi 口令 | **`Dsa78963`**（定义在 `build.yml` 的 `env.WIFI_PASS`；表单填写或仓库 Secret 可覆盖） |
| 802.11k / r | 均开启（`ieee80211k=1` / `ieee80211r=1`，FT-SAE 实测可用） |
| 802.11v | **默认关闭**（`steeringthresold` 不写），需要时手动开，验证方法见下 |
| WAN MAC | 由固件从 Bdata 分区 `ethaddr_wan` 读取，**每台机器各不相同** |

⚠️ 恢复出厂 = 回到 AP 模式：IP 是 `192.168.6.2` 且不发 DHCP，电脑要先设静态地址才能进后台。

**为什么 network 没有直接烤**：`/bin/config_generate` 只要发现 `/etc/config/network` 已存在就整段
`exit 0`，而 WAN 的出厂 MAC 正是它从 Bdata 读出来写进去的。所以 `network` 交给固件生成，
`diy/files/ax3000t/etc/uci-defaults/99-ax3000t-ap-mode` 在首启之后把它改成 AP 模式。

### 验证 802.11v（刷完后）

```sh
# 1. 配置：阈值 + 对端 AP 的 5G BSSID
uci set wireless.default_MT7981_1_2.steeringthresold='-45'
uci -q delete wireless.default_MT7981_1_2.steeringbssid
uci add_list wireless.default_MT7981_1_2.steeringbssid='46:df:65:93:58:ce'
uci commit wireless && wifi reload

# 2. 落地检查（阈值走 iwpriv，不在 dat 里，别去 grep dat）
logread | grep 'iwpriv cmd' | grep -i steer        # iwpriv rax0 set Steeringthresold=-45
ps w | grep -E 'wapp|bs20'                         # 两个进程都在
logread -t wapp-setbssid | tail                    # 候选 BSSID 下发成功

# 3. 触发（不需要调 Debug 级别，脚本自己写 syslog）
logread -f -t wapp-steering                        # steer request sent ...

# 4. 客户端是否真的移动：看频率。5745=AX3000T(149)，5180=主路由(36)
adb shell cmd wifi status | grep -o 'Frequency: [0-9]*'
iwinfo rax0 assoclist                              # AP 侧交叉核对 RSSI
```

只想验 wapp 这一段（绕开 RSSI 判定）：`/sbin/setbssid rax0 <对端BSSID>` 后
`/sbin/steeringsta rax0 <客户端MAC>`，返回 0 即链路通。

## 其他设备的默认无线

| 设备 | 2.4G SSID | 5G SSID | 加密 |
|---|---|---|---|
| AX6000 | `ASUS` | `ASUS_5G` | WPA2/WPA3 混合（`sae-mixed`） |

AX3000T 的 SSID 直接来自 `diy/files/ax3000t/etc/config/wireless`，不走 `WIFI_PASS`。
其余设备的口令取自构建时的 `WIFI_PASS` 环境变量，默认值写在 `build.yml` 的 `env` 里。

**建议改用仓库 Secret**：Settings → Secrets and variables → Actions → New repository secret，
名字 `WIFI_PASS`。不设置则使用公开的默认口令，等于固件出厂口令人人皆知。

## 改配置：不用改文件

按改动频率分三档，别再为了改个 SSID 去改文件、提交、等两小时：

| 想改什么 | 怎么做 | 要重新编译吗 |
|---|---|---|
| SSID / 口令 / 管理地址 | Actions → **build** → Run workflow，表单里填 `ssid_2g`、`ssid_5g`、`wifi_pass`、`lan_ip` | 要，但**不用改文件、不用提交** |
| 已经刷好的机器上的任何设置 | SSH 上去 `uci set …; uci commit …; wifi reload` | 不要，立刻生效 |
| 结构性改动（端口归属、加密方式、11v 默认值、加设备） | 改 `diy/files/…` 或 `diy/mt798x/*.sh` 并提交 | 要 |

表单四项都可以留空，留空即取默认值：`ASUS` / `ASUS_5G` / 仓库 Secret（再没有就 `Dsa78963`）/ `192.168.6.2`。

实现方式：`diy/files/<device>/` 里放的是 `@SSID_2G@`、`@WIFI_KEY@`、`@LAN_IP@` 这类占位符，
构建时由 `diy/mt798x/render.py` 做**纯字面替换**——不走 sed，所以口令里带 `& | \ /` 也不会被吃掉；
替换前校验长度（SSID 1~32、口令 8~63）与字符（禁止单引号和换行），替换后断言没有残留占位符，
任何一步不对就让构建红掉。

⚠️ `wifi_pass` 填在表单里会出现在 Actions 运行的输入记录中（公开仓库可见）。想保密就配仓库
Secret，表单留空即可。

## 构建

Actions → **build** → Run workflow，设备可选 `ax3000t`（默认）/ `all` / `ax6000`。
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
  builder-image.yml      # 构建编译环境镜像并推到 ghcr
  cleanup.yml            # 清理历史运行记录（7 天 / 保留 3 次）
docker/builder.Dockerfile  # 编译环境镜像（OpenWrt 依赖全部预装）
configs/ARM/mt798x/      # 各机型的 seed 配置（完整 .config）
diy/files/<device>/      # 直接进 rootfs 的设备配置（含 @占位符@，构建时渲染）
diy/mt798x/
  feed.sh                # 额外 feed 挂载点（当前为空）
  lib.sh                 # 公共函数：改 IP / SSID / WiFi 口令，均带断言
  render.py              # 把 @SSID_2G@ 等占位符换成本次构建参数（纯字面替换）
  ax3000t.sh             # AX3000T 定制：兜底 IP 与无线口令
  ax6000.sh              # AX6000 定制：SSID 改为 ASUS / ASUS_5G
diy/aliupload.py         # 未接线，预留给网盘上传
```

`diy/files/<device>/` 会被拷进 `openwrt/files/`，由 `include/image.mk` 在 `prepare_rootfs`
阶段覆盖到 rootfs（晚于包安装），所以放在这里的 `/etc/config/*` 优先于包默认值。

定制脚本的行为约定：**任何一处 sed 锚点没命中就直接让构建失败**，不允许静默产出一个
"看起来正常、实际是开放热点"的固件。

## 构建环境

`build` job 跑在 `ghcr.io/<owner>/openwrt-builder:24.04` 容器里，OpenWrt 需要的 apt 依赖全部预装在里面，
所以构建时不再执行 `apt-get install`（原来每次 8 分钟）也不需要清理 runner 的预装 SDK。

- 改依赖：编辑 `docker/builder.Dockerfile`，push 后 `builder-image` 自动重建（约 2 分钟）
- 定时：每月 1 日自动重建一次，顺带吃 Ubuntu 的安全更新
- 手动：Actions → **builder-image** → Run workflow
- 容器里 `run` 的默认 shell 是 `sh`，workflow 已经用 `defaults.run.shell: bash` 统一成 bash

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

## 救砖（TFTP）

两台机器的 bootloader 都没动过（stock layout），引导菜单里有
`Upgrade firmware = mtkupgrade fw`：它通过网络用 TFTP 从电脑拉固件直接写 flash，
**不依赖路由器上的系统**，所以系统刷坏了也还能用。

| 设备 | 设备自身地址 | 电脑（TFTP 服务器）地址 |
|---|---|---|
| AX3000T | `192.168.10.1` | `192.168.10.100` |
| AX6000 | `192.168.31.1` | `192.168.31.100` |

流程：电脑设成上表右侧的固定 IP、起一个 TFTP 服务器、把固件放进它的根目录；路由器上电时进
bootmenu（`bootdelay=2`，进入方式随机型，常见是上电时按住复位；不确定就接串口）选
「Upgrade firmware」。

另外两条更稳的路线：

1. 先用小米官方恢复方式刷回**原厂固件**，再按本文档重新装一遍——stock layout 下这条路一定通。
2. `mtkload` 可以用 TFTP 把 `-initramfs-kernel.bin` 直接加载到内存启动（**不写 flash**），
   进系统后再 `sysupgrade`。这也是 initramfs 镜像唯一的用途。

## 注意

- stock layout 直接刷写有风险，先确认 U-Boot 与分区布局；跨仓库 sysupgrade 不保证兼容。
- `fix/80211v` 基于 lyimoexiao，他把 MT7981 的 `INDEX0_EEPROM_size` 从 `0x5000` 改成了 `0x200000`。
  已核对 AX3000T 的 `Factory` 分区正好是 `0x200000`（DTS `partition@180000`），不会越界，
  但首刷仍要确认 WiFi 能正常起来；异常就切 `fix/80211v-pdv`。
- 仓库里其余 7 份 `configs/ARM/mt798x/*.config`（a31、ct3003、nx30pro、q30、rax3000m×2、t7、wr30u）
  目前没有对应的构建条目，需要时按上面第 3 步接进去。
- 本仓库为 [xiangfeidexiaohuo/EasyWrt](https://github.com/xiangfeidexiaohuo/EasyWrt) 的 fork。
