#!/usr/bin/env bash
# 下载并解压 AOSP clang-r510928（android15-6.6 官方钉死的工具链）+ build-tools
# 用法: ./get-toolchain.sh [目标目录，默认 ./toolchain]
#
# 为什么必须这个版本：GKI KMI 契约要求"仅允许分支指定的 Clang 工具链"，
# 用其它 clang 编出的内核与预编译 vendor 模块不兼容（logo bootloop）。
# 版本来源：内核源码 build.config.constants -> CLANG_VERSION=r510928
set -euo pipefail
DIR="${1:-./toolchain}"
mkdir -p "$DIR"
cd "$DIR"

BASE="https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang18-r510928"

[[ -d clang18/bin ]] || {
  echo "[*] 下载 clang-r510928 (~880MB)..."
  curl -L -C - -o clang.zip "$BASE/clang-r510928.zip"
  unzip -q clang.zip -d clang18 && rm clang.zip
}
[[ -d bt/build-tools ]] || {
  echo "[*] 下载 build-tools (dtc 等)..."
  curl -L -C - -o build-tools.zip "$BASE/build-tools.zip"
  unzip -q build-tools.zip -d bt && rm build-tools.zip
}

echo "[✓] 工具链就绪: $DIR/clang18/bin"
"$DIR/clang18/bin/clang" --version | head -1
# NixOS 提示：AOSP clang 是 glibc 动态二进制，需 nix-ld 或 FHS 环境运行
