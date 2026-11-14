# 构建细节

## 运行环境

`build` job 跑在 `ghcr.io/<owner>/openwrt-builder:24.04` 容器里，OpenWrt 需要的 apt 依赖全部预装，
所以构建时不再 `apt-get install`（原来每次 8 分钟），也不用清理 runner 预装的 SDK。

- 改依赖：编辑 `docker/builder.Dockerfile`，push 后 `builder-image` 自动重建（约 2 分钟）
- 定时：每月 1 日自动重建，顺带吃 Ubuntu 的安全更新
- 手动：Actions → **builder-image** → Run workflow
- 容器里 `run` 的默认 shell 是 `sh`，workflow 已用 `defaults.run.shell: bash` 统一

runner 固定 `ubuntu-24.04`：GitHub 在 2026-10 把 `ubuntu-latest` 切到 26.04，而 Ubuntu 25.10 起
coreutils 默认换成 uutils，`install --version` 不再输出 GNU，OpenWrt 的 prereq 会判定
"Please install GNU 'install'" 并让 `make defconfig` 退出 2。

## 换源码分支

改 `.github/workflows/build.yml` 顶部的 `REPO_BRANCH`：

| 分支 | 说明 |
|---|---|
| `fix/80211v` | 默认。lyimoexiao 基座 + 802.11v 修复 |
| `fix/80211v-pdv` | padavanonly 基座 + 同样的修复。AX3000T 若出现 WiFi 异常（ly 的 MT7981 EEPROM 改动）切这个 |

## 改动落在哪

| 想改什么 | 怎么做 | 要重新编译吗 |
|---|---|---|
| SSID / 口令 / 管理地址 | Actions 表单填 `ssid_2g`、`ssid_5g`、`wifi_pass`、`lan_ip` | 要，但不用改文件 |
| 已刷好的机器上的设置 | SSH `uci set …; uci commit …; wifi reload` | 不要 |
| 端口归属、加密方式、11v 默认值、加设备 | 改 `diy/files/…` 或 `diy/mt798x/*.sh` 并提交 | 要 |

表单四项留空即取默认：`ASUS` / `ASUS_5G` / 仓库 Secret（再没有就 `Dsa78963`）/ `192.168.6.2`。

`wifi_pass` 填在表单里会出现在 Actions 的输入记录中（公开仓库可见）。想保密就配仓库 Secret，
表单留空。

## 占位符渲染

`diy/files/<device>/` 里放 `@SSID_2G@`、`@WIFI_KEY@`、`@LAN_IP@` 这类占位符，构建时由
`diy/mt798x/render.py` 做**纯字面替换**——不走 sed，所以口令里带 `& | \ /` 也不会被吃掉。

替换前校验长度（SSID 1~32、口令 8~63）与字符（禁止单引号和换行），替换后断言没有残留占位符，
任何一步不对就让构建红掉。

定制脚本同样：任何一处 sed 锚点没命中就直接失败，不允许静默产出"看起来正常、实际是开放热点"的固件。
`diy/files/<device>/` 会被拷进 `openwrt/files/`，由 `include/image.mk` 在 `prepare_rootfs` 阶段
覆盖到 rootfs（晚于包安装），所以这里的 `/etc/config/*` 优先于包默认值。

## 增加一台新设备

1. 放 seed 配置：`configs/ARM/mt798x/<name>.config`（`make menuconfig` 后 `cp .config` 得到）
2. 写定制脚本：`diy/mt798x/<name>.sh`，`source` 同目录的 `lib.sh`，按需调用
   `apply_lan_ip` / `apply_ssid` / `apply_wifi_key`
3. 在 `build.yml` 的 `setup` 步骤里给 `all` JSON 加一条
   （`device` / `label` / `config` / `rom` 四个字段，`device` 必须与脚本同名）

## ccache

构建前在 `.config` 里打开 `CONFIG_CCACHE` 并指向 `${CCACHE_DIR}`。缓存 key 用
`ccache-<device>-<run_id>` 加前缀恢复，保证每次构建都能把新对象写回去；上限 3G。
