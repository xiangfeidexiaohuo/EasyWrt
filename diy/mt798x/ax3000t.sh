#!/bin/bash
#
# 小米 AX3000T（MT7981）定制
# 用法: ax3000t.sh <openwrt 源码目录>
#
# 出厂即「桥接 AP」：管理地址 192.168.6.2、DHCP 与 IPv6 RA 关闭、
# SSID 固定为 ASUS / ASUS_5G。具体配置见 diy/files/ax3000t/：
#   etc/config/wireless     直接进 rootfs
#   etc/config/dhcp         直接进 rootfs（AP 模式关键）
#   etc/config/turboacc     AP 标记
#   etc/uci-defaults/99-*   首启把生成的 network 改成 AP 模式
#
# 这里的两步是兜底：万一 files/ 没被带上，默认配置也不会是开放热点、
# 也不会回到 192.168.6.1。
set -euo pipefail

SRC="${1:?用法: ax3000t.sh <openwrt 源码目录>}"
. "$(dirname "$0")/lib.sh"

apply_lan_ip "$SRC" "192.168.6.2"
apply_wifi_key "$SRC"

info "ax3000t 定制完成"
