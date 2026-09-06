#!/usr/bin/env bash
# TB322FC Droidspaces 内核完整构建流程
# 用法: ./build-kernel.sh <工作目录> <clang18目录>
#   例: ./build-kernel.sh ../work ../work/clang18-dist
#
# 前提（脚本自动完成大部分）：
#   1. 工作目录里有 stock-config.txt（从设备 zcat /proc/config.gz 抓取）
#   2. 工具链已下载（get-toolchain.sh）
#   3. Linux 主机或 NixOS(nix-ld)；HOSTCC=gcc 用于 host 工具
set -euo pipefail
WORK="${1:?用法: $0 <工作目录> <clang18目录>}"
TC="${2:?缺少 clang18 目录}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KERNEL_TAG="android15-6.6-2025-06_r1"
# 设备实际构建 commit（uname -r 里的 g14220ae4ce65）；tag 与它同 SUBLEVEL=89
SRC="$WORK/kernel-6.6"
export ARCH=arm64 SUBARCH=arm64
export PATH="$TC/bin:$PATH"
export KCFLAGS="-D__ANDROID_COMMON_KERNEL__"
# vermagic 伪装：与设备逐字符一致（6.6 已废 .scmversion，用 KERNELRELEASE 直通）
export KERNELRELEASE="6.6.89-android15-8-g14220ae4ce65-ab13680582-4k"

# 1) 源码
if [[ ! -d $SRC/.git ]]; then
  mkdir -p "$SRC" && cd "$SRC"
  git init -q && git remote add origin https://android.googlesource.com/kernel/common
  git fetch --depth 1 origin refs/tags/$KERNEL_TAG && git checkout -q FETCH_HEAD
fi
cd "$SRC"

# 2) kABI 补丁（SYSVIPC 必需，否则 vendor 模块 bootloop）
if ! grep -q "ANDROID_KABI_USE(6" include/linux/sched.h; then
  git apply "$HERE/patches/0001-kabi-sysvipc-6.6.patch"
  echo "[+] kABI 补丁已应用"
fi

# 3) 配置 = 原厂 config.gz + fragment
cp "$WORK/stock-config.txt" .config
scripts/kconfig/merge_config.sh -m .config "$HERE/patches/droidspaces.config.fragment"
# testkey 证书（模块签名 + PKCS7 导出链，见 README 的"MODULE_SIG 级联"一节）
[[ -f certs/testkey_rsa4096.pem ]] || {
  curl -s "https://android.googlesource.com/platform/external/avb/+/refs/heads/main/test/data/testkey_rsa4096.pem?format=TEXT" \
    | base64 -d > /tmp/tk.pem
  openssl req -new -x509 -nodes -sha256 -days 36500 -key /tmp/tk.pem \
    -subj "/CN=Android Test Key" -out /tmp/tk.crt
  cat /tmp/tk.crt /tmp/tk.pem > certs/testkey_rsa4096.pem
}
sed -i 's|^CONFIG_MODULE_SIG_KEY=.*|CONFIG_MODULE_SIG_KEY="certs/testkey_rsa4096.pem"|' .config
yes "" | make olddefconfig HOSTCC=gcc >/dev/null

# 4) 编译
make -j"$(nproc)" Image HOSTCC=gcc HOSTLD=gcc LLVM=1

# 5) 验证
grep -m1 " verify_pkcs7_signature" System.map || { echo "❌ PKCS7 符号缺失"; exit 1; }
grep -a -o -m1 "6\.6\.89-android15-8[^ ]*" arch/arm64/boot/Image | head -1
echo "[✓] Image 就绪: $SRC/arch/arm64/boot/Image  （下一步 package-boot.sh）"
