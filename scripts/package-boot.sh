#!/usr/bin/env bash
# 打包 boot.img 并用 AOSP testkey 完成 AVB 签名（免解 BL 刷入的关键）
# 用法: ./package-boot.sh <Image路径> <输出img>
#
# 依赖: android-tools (mkbootimg/avbtool) + openssl
# 原理: vbmeta 中 boot 是 Chain Partition 描述符，公钥=AOSP testkey
#       → 只要 boot.img 的 AVB footer 用 testkey 签名即可，vbmeta 不用动
set -euo pipefail
IMG="${1:?用法: $0 <Image> <输出boot.img>}"
OUT="${2:?缺少输出路径}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 原厂 boot 参数（从设备 dump 分析所得）：header v4 / 未压缩 kernel / 空 ramdisk / cmdline 空
: > /tmp/empty-ramdisk.img
mkbootimg --header_version 4 --kernel "$IMG" --ramdisk /tmp/empty-ramdisk.img \
  --cmdline '' --output "$OUT"

# testkey 私钥（AOSP 公开）
TK=/tmp/testkey_rsa4096.pem
[[ -f $TK ]] || curl -s "https://android.googlesource.com/platform/external/avb/+/refs/heads/main/test/data/testkey_rsa4096.pem?format=TEXT" | base64 -d > "$TK"

# rollback index 与 salt 取自原厂 boot footer（不得回退）
avbtool add_hash_footer --image "$OUT" \
  --partition_name boot --partition_size 100663296 \
  --algorithm SHA256_RSA4096 --key "$TK" \
  --rollback_index 1738713600 \
  --salt d30c103948f302cbb5aec58c33ef9ec1aac16d692ecafff8a3346f0c8145b3ad \
  --prop 'com.android.build.boot.os_version:15' \
  --prop 'com.android.build.boot.fingerprint:Lenovo/TB322FC_PRC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.117_260212_PRC:user/release-keys' \
  --prop 'com.android.build.boot.security_patch:2025-02-05'

echo "[✓] $OUT"
sha256sum "$OUT"
echo
echo "刷入: LTBox → Advanced → 分区写入 → boot_a ← $OUT"
echo "回滚: 同法写回原厂 boot_a dump"
