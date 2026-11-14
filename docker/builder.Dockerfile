# 云编译用的宿主环境
#
# 目的：把这套 apt 依赖固化进镜像。原来每次构建都要在 runner 上
# apt-get install 六十来个包，占 8 分钟；用预装镜像后只剩拉取时间。
#
# 镜像由 .github/workflows/builder-image.yml 构建并推送到
# ghcr.io/<owner>/openwrt-builder:24.04，build.yml 里用 container: 引用。
#
# 什么时候需要改这里：
#   - 升级 OpenWrt 大版本，编译报 "command not found" / 缺头文件
#   - 官方 runner 基础镜像换代（改第一行 FROM 与 tag）
# 改完 push 到 main 会自动重建镜像。

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8

# 与原先 build.yml 里那条 apt-get install 完全一致，去掉 --no-install-recommends
# 之外的多余推荐包；额外补 sudo（容器里默认 root，脚本里若用 sudo 不至于找不到命令）、
# jq（打包脚本用）、python3（render.py 用）
RUN apt-get update && apt-get install -y --no-install-recommends \
        ack antlr3 aria2 asciidoc autoconf automake autopoint \
        binutils bison build-essential bzip2 ccache cpio curl device-tree-compiler fastjar flex \
        gawk gettext gcc-multilib g++-multilib git gperf haveged help2man intltool libc6-dev-i386 \
        libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev \
        libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp nano ninja-build \
        p7zip p7zip-full patch pkgconf g++ file clang genisoimage python3-pip libpython3-dev \
        qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim \
        wget xmlto xxd zlib1g-dev libfuse-dev python3-setuptools \
        sudo ca-certificates tzdata jq python3 zstd xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 构建过程全部在 $GITHUB_WORKSPACE 里，容器内不保留任何状态
WORKDIR /work
