# Lenovo Legion Y700 Gen 4 (TB322FC) — Droidspaces Kernel

> 🌐 English | [简体中文](README.md)

A custom GKI kernel + KernelSU-Next root setup that runs
[Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) containers on the
Y700 Gen 4 **with the bootloader kept locked**.

Lenovo ships this device's boot chain signed with the **public AOSP testkey**,
so a custom kernel re-signed with that key passes AVB on a **locked** bootloader;
combined with Qualcomm **EDL (9008)** writes (via
[LTBox](https://github.com/miner7222/LTBox)), you get kernel-level root +
Droidspaces **without unlocking** — no data wipe, no unlock warning. The kernel
must be built with the **exact AOSP clang (r510928)** pinned by the branch, or
vendor modules break (KMI contract).

| Item | Value |
|---|---|
| Device | Lenovo Legion Y700 2025 / **TB322FC** (Snapdragon 8 Elite, SM8750) |
| ROM | ZUXOS 1.5.10.117 (Android 16), verified |
| Kernel | `6.6.89-android15-8-g14220ae4ce65-ab13680582-4k` |
| Root | KernelSU-Next v3.3.0 (**LKM**, patched into init_boot) |
| BL | **locked** ✅ |
| WiFi/BT | ✅ working (Qualcomm cnss2/cfg80211 stack) |
| GPU | ✅ Turnip hardware acceleration (Mesa 26.3.0-devel, glmark2 2714) |
| Droidspaces | ✅ check passes (v6.5.0, all green) |

---

## Quick start (already-rooted devices)

```bash
# 1) Download the prebuilt boot image
curl -LO https://github.com/ll1zt/tb322fc-droidspaces-kernel/raw/main/images/boot-tb322fc-droidspaces-v4.img
sha256sum boot-tb322fc-droidspaces-v4.img
# bf337d09908ca477ed16dd6e322c45085485685681f72763bd6d02f84596670b

# 2) LTBox → Advanced → Partition write → boot_a ← this file (auto-enters EDL) → reboot
```

Unrooted devices: follow [docs/GUIDE_EN.md](docs/GUIDE_EN.md) for the LTBox
no-unlock root first.

## Building from scratch

```bash
./scripts/get-toolchain.sh ./toolchain      # AOSP clang r510928 (branch-pinned, KMI contract, mandatory)
# Grab the stock config from the device (after root):
adb shell su -c "cat /proc/config.gz" > work/stock-config.gz && gunzip work/stock-config.gz
./scripts/build-kernel.sh ./work ./toolchain/clang18
./scripts/package-boot.sh work/kernel-6.6/arch/arm64/boot/Image out/boot-ds.img
```

Build essentials:

1. The config base is the device's stock `/proc/config.gz` overlaid with
   `patches/droidspaces.config.fragment`, not `gki_defconfig`.
2. `CONFIG_SYSVIPC=y` must come with the kABI patch
   (`patches/0001-kabi-sysvipc-6.6.patch`, hand-adapted RESERVE 6/7/8 for 6.6),
   otherwise vendor modules crash-loop.
3. The toolchain must be the branch-pinned `clang-r510928` from
   `build.config.constants`; kernels built with any other clang are incompatible
   with the prebuilt vendor modules.
4. vermagic is passed through with `make KERNELRELEASE=<full string>` (6.6's new
   setlocalversion removed `.scmversion`), matching the device character-for-character.
5. `CONFIG_MODULE_SIG=y` with `MODULE_SIG_KEY` pointing at the testkey certificate.
   Do not simply disable `MODULE_SIG`: that cascades off `SYSTEM_DATA_VERIFICATION`,
   `verify_pkcs7_signature` is no longer exported, and cfg80211 fails to load.
6. The boot AVB footer must carry the stock 3 prop descriptors
   (`com.android.build.boot.fingerprint` / `os_version` / `security_patch`);
   `package-boot.sh` already includes them.

## Directory layout

```
README_EN.md                             this file (English)
images/boot-tb322fc-droidspaces-v4.img   prebuilt image + sha256sums.txt
patches/0001-kabi-sysvipc-6.6.patch      SYSVIPC kABI patch (6.6 adaptation)
patches/droidspaces.config.fragment      config delta (on top of stock config.gz)
scripts/get-toolchain.sh                 download AOSP clang r510928
scripts/build-kernel.sh                  one-shot build
scripts/package-boot.sh                  packaging + testkey signing
docs/GUIDE.md                            no-unlock root guide (LTBox/EDL, Chinese)
docs/GUIDE_EN.md                         no-unlock root guide (English)
docs/kernel-config-v4                    final kernel config (7766 lines)
```

## Upgrading firmware

1. LTBox full flash of the new firmware (keep-data option)
2. LTBox Root Device → re-root (the new init_boot overwrites the old one)
3. LTBox System Updates → disable OTA (**from build 263 onward, unlocked/modified
   devices no longer receive OTA**)
4. Re-flash this repo's boot image (if the new firmware changed the kernel
   version, rebuild: new `KERNELRELEASE` string + new stock config)

## Rollback

Write the stock `boot_a` dump back with LTBox partition write (or full-flash the
official firmware). The EDL channel is always available (the 9008 port is not
encrypted).

## Risks

- Modifying the boot chain can brick the device (EDL rescue possible);
  unlocking/modifying images voids the warranty
- **Never re-lock with `fastboot flashing lock`** (documented hard-brick cases on XDA)
- This repository has not been audited by Droidspaces/Lenovo. Proceed at your own risk.

## Credits & sources

- [LTBox](https://github.com/miner7222/LTBox) (miner7222 et al.) — no-unlock BL toolchain
- [XDA thread 4743906](https://xdaforums.com/t/lenovo-legion-y700-4th-generation-tb322fc-8g4-unlock-bootloader.4743906/) — unlock & testkey intel
- [qdykernel/Build_Lenovo_sm8750](https://github.com/qdykernel/Build_Lenovo_sm8750) — toolchain & the AOSP public-key signing route
- [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) — kABI patch & kernel config guide
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)

## License

Kernel patches and scripts: GPL-2.0 WITH Linux-syscall-note (same as the Linux
kernel). See [LICENSE](LICENSE).
