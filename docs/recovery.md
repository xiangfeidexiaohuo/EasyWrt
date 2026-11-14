# 刷机与救砖

两台都是**不死 U-Boot**（bl-mt798x 系）：断电，按住 reset 上电保持 5 秒，
浏览器打开对应地址直接上传固件。

## 现状（2026-11-14）

| 设备 | bootloader | Web failsafe | DHCP |
|---|---|---|---|
| AX3000T | `Yuzhii0718/bl-mt798x-dhcpd`，U-Boot 2025.07.1（2026-10-30 构建，`e4cf4dc`） | `192.168.10.1` | 正常，插上就能拿到 `192.168.10.x` |
| AX6000 | 旧版 bl-mt798x，U-Boot 2022.07（2023-11-30 构建） | `192.168.1.1` | 坏的（服务器标识/掩码全发 `0.0.0.0`），需静态 IP |

AX3000T 升级前的原厂 FIP 已备份（714,025 字节，sha256 `e0a6e3bc6975…`）；
升级后的 FIP 为 971,672 字节，sha256 `4c26abf1a25b…`。

## 页面功能

- AX3000T 新版：`/env.html` 改环境变量、`/console.html` Web 终端、`/backup.html` 备份整片 flash、
  `/flash.html` 直接读写分区、`/initramfs.html` 内存启动。
- AX6000 旧版：只有 `/`、`/uboot.html`、`/bl2.html`。DHCP 拿不到地址时，
  给电脑设静态 `192.168.1.200/24` 即可。

## 分区布局

两台都是 stock 尺寸：AX3000T `ubi_kernel 0x2200000` + `ubi 0x4e00000`，
AX6000 `0x1e00000` + `0x5000000`。

`/getmtdlayout` 返回 `default;default;immortalwrt-112m;qwrt;`，当前是 `default`，
所以本仓库的 stock 镜像适用。以后若切到 `immortalwrt-112m`，必须换 ubootmod 固件。

## 不要用 fw_printenv 判断或修改 bootloader

`/etc/fw_env.config` 指向 `Nvram` 分区，里面是**原厂残留的环境变量**
（`bootcmd=bootxq`、`bootmenu_N=mtkupgrade…`、`ipaddr=192.168.10.1`）。这些值不驱动现在的 bootloader：

- 用 `fw_printenv` 判断 bootloader 类型会得出错误结论（这几行已经骗过一次）
- 用 `fw_setenv` 改参数对 bootloader 无效，只是写进一块没人读的空间
- AX6000 的 `192.168.1.1` 是 bootloader 自己的默认值，不是 Nvram 里那个 `192.168.31.1`

## 确认 FIP 有没有被换过

```sh
dd if=/dev/mtd4 of=/tmp/fip.bin bs=4096 count=200
head -c <fip-multi.bin 的字节数> /tmp/fip.bin | sha256sum
```

与官方 `*-fip-multi.bin` 的 sha256 比对，一致就说明跑的是 bl-mt798x 的 multi 变体。
