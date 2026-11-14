#!/bin/bash
#
# 小米 AX3000T（MT7981）定制
# 用法: ax3000t.sh <openwrt 源码目录>
#
set -euo pipefail

SRC="${1:?用法: ax3000t.sh <openwrt 源码目录>}"
. "$(dirname "$0")/lib.sh"

# 原 t7op2.sh 的行为：管理地址改为 192.168.5.1，SSID 保持上游默认
apply_lan_ip "$SRC" "192.168.5.1"
apply_wifi_key "$SRC"

info "ax3000t 定制完成"
