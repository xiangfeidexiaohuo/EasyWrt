#!/bin/bash
#
# 红米 AX6000（MT7986）定制
# 用法: ax6000.sh <openwrt 源码目录>
#
set -euo pipefail

SRC="${1:?用法: ax6000.sh <openwrt 源码目录>}"
. "$(dirname "$0")/lib.sh"

# 管理地址由表单指定，留空保持主路由的 192.168.6.1。
apply_lan_ip "$SRC" "${LAN_IP:-192.168.6.1}"

# WiFi 的表单值由 diy/files/ax6000/etc/config/wireless 渲染进 rootfs；
# 这里保留生成器兜底，和 AX3000T 一样避免缺少内置配置时出现开放热点。
apply_ssid "$SRC" "ASUS" "ASUS_5G"
apply_wifi_key "$SRC"

# 5G 固定 80MHz：生成器默认 HE160，占 36-64 整块，其中 52-64 属 DFS，
# 开机要做约 60 秒 CAC 才会出 SSID，遇到雷达还会整块切走。80MHz 只占
# 36-48，全程非 DFS，和 AX3000T 的 149 也不重叠。
f="$SRC/package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
_require_file "$f"
grep -q 'htmode="HE160"' "$f" || \
	die "mtwifi.sh 里找不到 htmode=\"HE160\"，上游 5G 默认已变化，请更新本脚本"
sed -i 's/htmode="HE160"/htmode="HE80"/g' "$f"
grep -q 'htmode="HE80"' "$f" || die "5G htmode 未改成 HE80"
if grep -q 'HE160' "$f"; then
	die "mtwifi.sh 里仍存在 HE160"
fi
info "5G htmode -> HE80（信道保持 36）"

info "ax6000 定制完成"
