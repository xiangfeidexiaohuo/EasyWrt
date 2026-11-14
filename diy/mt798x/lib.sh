#!/bin/bash
#
# 设备定制的公共函数库。只被 diy/mt798x/<device>.sh source，不单独执行。
#
# 设计原则：
#   1. 每处改动都带断言——上游一旦改了被 sed 的锚点，构建立刻失败，
#      而不是静默产出一个和预期不一样的固件（例如无密码开放热点）。
#   2. 路径全部由调用方传入，脚本不假设 cwd。
#

set -euo pipefail

# 由 workflow 的 env 注入；为空时在 apply_wifi_key 里直接失败
WIFI_PASS="${WIFI_PASS:-}"

die() { echo "::error::$*" >&2; exit 1; }
info() { echo "[customize] $*"; }

_require_file() {
	[ -f "$1" ] || die "找不到 $1（上游目录结构变了？）"
}

# apply_lan_ip <openwrt-src> <新的 LAN IP>
# padavanonly 树默认 192.168.6.1，改动前先确认锚点还在。
apply_lan_ip() {
	local src="$1" ip="$2" f
	f="$src/package/base-files/files/bin/config_generate"
	_require_file "$f"

	grep -q '192\.168\.6\.1' "$f" || \
		die "config_generate 里找不到 192.168.6.1，上游默认 IP 已变化，请更新本脚本"

	sed -i "s/192\.168\.6\.1/$ip/g" "$f"

	grep -q "$ip" "$f" || die "LAN IP 未写入"
	if grep -q '192\.168\.6\.1' "$f"; then
		die "旧 LAN IP 仍然存在"
	fi
	info "LAN IP -> $ip"
}

# apply_ssid <openwrt-src> <2.4G SSID> <5G SSID>
# 传空字符串表示保持上游默认。
apply_ssid() {
	local src="$1" ssid_2g="${2:-}" ssid_5g="${3:-}" f
	f="$src/package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
	_require_file "$f"

	if [ -n "$ssid_2g" ]; then
		grep -q 'ImmortalWrt-2\.4G' "$f" || die "mtwifi.sh 里找不到默认 2.4G SSID"
		sed -i "s/ImmortalWrt-2\.4G/${ssid_2g}/g" "$f"
		grep -qF "$ssid_2g" "$f" || die "2.4G SSID 未写入"
	fi

	if [ -n "$ssid_5g" ]; then
		grep -q 'ImmortalWrt-5G' "$f" || die "mtwifi.sh 里找不到默认 5G SSID"
		sed -i "s/ImmortalWrt-5G/${ssid_5g}/g" "$f"
		grep -qF "$ssid_5g" "$f" || die "5G SSID 未写入"
	fi

	info "SSID -> ${ssid_2g:-<默认>} / ${ssid_5g:-<默认>}"
}

# apply_wifi_key <openwrt-src>
# 把默认的无密码 AP 改成 sae-mixed + 指定口令，并在写完后断言。
# 这一步是安全关键路径：改不动就必须让构建红掉，绝不能出厂成开放热点。
apply_wifi_key() {
	local src="$1" f escaped
	f="$src/package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
	_require_file "$f"

	[ -n "$WIFI_PASS" ] || die "环境变量 WIFI_PASS 为空，拒绝生成无密码固件"
	[ "${#WIFI_PASS}" -ge 8 ] || die "WIFI_PASS 至少 8 位（WPA2/WPA3 要求）"

	# sed 替换串里的元字符需要转义（口令可能含 & \ |）
	escaped="$(printf '%s' "$WIFI_PASS" | sed -e 's/[\\&|]/\\&/g')"

	grep -q 'set wireless\.default_\${dev}\.encryption=none' "$f" || \
		die "mtwifi.sh 里找不到 encryption=none 锚点，上游模板已变化，请更新本脚本"

	sed -i \
		-e "s|^\([[:space:]]*\)set wireless\.default_\${dev}\.encryption=none$|\1set wireless.default_\${dev}.encryption=sae-mixed\n\1set wireless.default_\${dev}.key=${escaped}|" \
		"$f"

	grep -q 'encryption=sae-mixed' "$f" || die "加密方式没有改成 sae-mixed"
	grep -qF ".key=${WIFI_PASS}" "$f" || die "口令没有写入"
	if grep -q 'encryption=none' "$f"; then
		die "仍然存在 encryption=none，拒绝继续"
	fi

	info "WiFi 加密 -> sae-mixed（口令来自 WIFI_PASS，长度 ${#WIFI_PASS}）"
}
