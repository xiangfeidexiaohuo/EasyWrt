#!/bin/bash
#
# 额外 feed 的挂载点。在 openwrt 源码目录内执行（feeds update 之前）。
#
# 需要加第三方插件库时在这里追加，例如：
#   echo "src-git extraipk https://github.com/xxx/extra-ipk;main" >> feeds.conf.default
# 注意：追加 feed 后必须确认 seed 配置里对应的包能编过，否则构建会红。
#
set -euo pipefail

echo "[feed] 当前未追加额外 feed"
