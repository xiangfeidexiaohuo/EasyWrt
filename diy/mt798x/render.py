#!/usr/bin/env python3
"""把 diy/files/<device> 里的 @占位符@ 替换成构建参数。

用法：render.py <目录>
环境变量：SSID_2G / SSID_5G / WIFI_PASS / LAN_IP

为什么不用 sed：SSID 和口令里可能出现 & | / \\ 这类 sed 元字符，用 str.replace
做纯字面替换不需要任何转义，也就不会出现"看着编译成功、实际口令被吃掉一半"。

替换前先校验，替换后断言没有残留占位符——宁可让构建红，也不产出半成品配置。
"""

import os
import re
import sys

PLACEHOLDERS = ("SSID_2G", "SSID_5G", "WIFI_KEY", "LAN_IP")

IP_RE = re.compile(r"^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$")
LEFTOVER_RE = re.compile(r"@(" + "|".join(PLACEHOLDERS) + r")@")


def fail(msg: str) -> None:
    print(f"::error::{msg}")
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: render.py <dir>")
    root = sys.argv[1]
    if not os.path.isdir(root):
        fail(f"{root} 不存在")

    values = {
        "SSID_2G": os.environ.get("SSID_2G", "").strip(),
        "SSID_5G": os.environ.get("SSID_5G", "").strip(),
        "WIFI_KEY": os.environ.get("WIFI_PASS", ""),
        "LAN_IP": os.environ.get("LAN_IP", "").strip(),
    }

    for name in ("SSID_2G", "SSID_5G"):
        v = values[name]
        if not 1 <= len(v) <= 32:
            fail(f"{name} 长度必须是 1~32（当前 {len(v)}）")
    key = values["WIFI_KEY"]
    if not 8 <= len(key) <= 63:
        fail(f"WiFi 口令长度必须是 8~63（当前 {len(key)}）")

    # 写入的是单引号包裹的 uci 配置：单引号和换行会破坏语法，
    # 双引号与反斜杠在单引号内是字面量，可以放行
    for name in ("SSID_2G", "SSID_5G", "WIFI_KEY"):
        if any(ch in values[name] for ch in "'\n\r"):
            fail(f"{name} 含有非法字符（单引号或换行）")

    ip = values["LAN_IP"]
    m = IP_RE.match(ip)
    if not m or any(int(g) > 255 for g in m.groups()):
        fail(f"LAN_IP 不是合法 IPv4：{ip!r}")

    replaced = 0
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            path = os.path.join(dirpath, fn)
            try:
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
            except (UnicodeDecodeError, IsADirectoryError):
                continue

            new = text
            for name in PLACEHOLDERS:
                new = new.replace(f"@{name}@", values[name])
            if new == text:
                continue

            # 直接覆写内容，文件的权限位（如 uci-defaults 的 755）保持不变
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(new)
            replaced += 1
            print(f"rendered {os.path.relpath(path, root)}")

    # 断言：不允许有漏替换的占位符
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            path = os.path.join(dirpath, fn)
            try:
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
            except (UnicodeDecodeError, IsADirectoryError):
                continue
            hit = LEFTOVER_RE.search(text)
            if hit:
                fail(f"{path} 仍有未替换的占位符 {hit.group(0)}")

    print(f"rendered {replaced} file(s) under {root}")


if __name__ == "__main__":
    main()
