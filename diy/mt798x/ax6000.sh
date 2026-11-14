#!/bin/bash
#
# 红米 AX6000（MT7986）定制
# 用法: ax6000.sh <openwrt 源码目录>
#
set -euo pipefail

SRC="${1:?用法: ax6000.sh <openwrt 源码目录>}"
. "$(dirname "$0")/lib.sh"

# 原 op2.sh 的行为：管理地址保持 192.168.6.1，SSID 改为 ASUS / ASUS_5G
apply_ssid "$SRC" "ASUS" "ASUS_5G"
apply_wifi_key "$SRC"

info "ax6000 定制完成"
