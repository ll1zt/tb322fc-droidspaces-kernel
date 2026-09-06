# Lenovo Legion Y700 Gen 4 (TB322FC) — Droidspaces Kernel

> 🌐 [English](README_EN.md) | 简体中文

在 **bootloader 保持锁定** 的 Y700 四代上运行 [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 容器的自定义 GKI 内核 + KernelSU-Next root 方案。

联想出厂时使用**公共 AOSP testkey** 对这台设备的启动链进行签名，因此用该密钥重新签名的自定义内核可以在**锁定**的引导加载程序上通过 AVB 验证；结合高通 **EDL (9008)** 写入（通过 [LTBox](https://github.com/miner7222/LTBox)），即可获得内核级 root + Droidspaces，**无需解锁**——不会清除数据，也没有解锁警告。内核必须使用分支固定的**精确 AOSP clang (r510928)** 构建，否则厂商模块会因 KMI 契约而损坏。

| 项 | 值 |
|---|---|
| 设备 | Lenovo Legion Y700 2025 / **TB322FC**（骁龙 8 Elite, SM8750） |
| 系统 | ZUXOS 1.5.10.117（Android 16）实测 |
| 内核 | `6.6.89-android15-8-g14220ae4ce65-ab13680582-4k` |
| root | KernelSU-Next v3.3.0（**LKM**，修补 init_boot） |
| BL | **locked** ✅ |
| WiFi/BT | ✅ 正常（高通 cnss2/cfg80211 栈） |
| GPU | ✅ Turnip 硬件加速（Mesa 26.3.0-devel，glmark2 2714） |
| Droidspaces | ✅ check 通过（v6.5.0 全绿） |

---

## 快速开始（已解锁/已 root 的设备）

```bash
# 1) 下载预编译 boot 镜像
curl -LO https://github.com/ll1zt/tb322fc-droidspaces-kernel/releases/download/tb322fc-v4/boot-tb322fc-droidspaces-v4.img
sha256sum boot-tb322fc-droidspaces-v4.img
# bf337d09908ca477ed16dd6e322c45085485685681f72763bd6d02f84596670b

# 2) LTBox → Advanced → 分区写入 → boot_a ← 该文件（自动进 EDL）→ 重启
```

未 root 的设备：先按 [docs/GUIDE.md](docs/GUIDE.md) 完成 LTBox 免解锁 root。

## 从零构建

```bash
./scripts/get-toolchain.sh ./toolchain      # AOSP clang r510928（分支钉死版本，KMI 契约，必须）
# 从设备抓原厂配置（root 后）：
adb shell su -c "cat /proc/config.gz" > work/stock-config.gz && gunzip work/stock-config.gz
./scripts/build-kernel.sh ./work ./toolchain/clang18
./scripts/package-boot.sh work/kernel-6.6/arch/arm64/boot/Image out/boot-ds.img
```

构建要点：

1. 配置基底是设备原厂 `/proc/config.gz` 叠加 `patches/droidspaces.config.fragment`，不是 `gki_defconfig`。
2. `CONFIG_SYSVIPC=y` 必须搭配 kABI 补丁（`patches/0001-kabi-sysvipc-6.6.patch`，6.6 上手动适配 RESERVE 6/7/8），否则 vendor 模块崩溃 bootloop。
3. 工具链必须用分支 `build.config.constants` 钉死的 `clang-r510928`，其他 clang 产出的内核与预编译 vendor 模块不兼容。
4. vermagic 用 `make KERNELRELEASE=<完整字符串>` 直通（6.6 的新 setlocalversion 已废除 `.scmversion`），与设备逐字符一致。
5. `CONFIG_MODULE_SIG=y` 且 `MODULE_SIG_KEY` 指向 testkey 证书。不能直接关闭 `MODULE_SIG`：那会级联关闭 `SYSTEM_DATA_VERIFICATION`，`verify_pkcs7_signature` 不再导出，cfg80211 加载失败。
6. boot 的 AVB footer 必须带原厂 3 个 Prop 描述符（`com.android.build.boot.fingerprint` / `os_version` / `security_patch`），`package-boot.sh` 已内置。


## 目录结构

```
README_EN.md                             English documentation
images/boot-tb322fc-droidspaces-v4.img   预编译镜像 + sha256sums.txt
patches/0001-kabi-sysvipc-6.6.patch      SYSVIPC kABI 补丁（6.6 适配版）
patches/droidspaces.config.fragment      配置增量（叠加在原厂 config.gz 上）
scripts/get-toolchain.sh                 下载 AOSP clang r510928
scripts/build-kernel.sh                  一键构建
scripts/package-boot.sh                  打包 + testkey 签名
docs/GUIDE.md                            免解 BL root 操作指南（LTBox/EDL 实测）
docs/GUIDE_EN.md                         免解 BL root 操作指南（英文）
docs/kernel-config-v4                    最终内核配置（7766 行）
```

## 升级固件的正确姿势

1. LTBox 全量刷新版固件（保留数据选项）
2. LTBox Root Device 重新打 root（新 init_boot 会覆盖旧的）
3. LTBox System Updates → 禁用 OTA（**263 起解锁/改镜像设备收不到 OTA**）
4. 重新刷本仓库 boot 镜像（若新固件内核版本变了需重编：换 `KERNELRELEASE` 字符串 + 新 stock-config）

## 回滚

LTBox 分区写回原厂 `boot_a` dump（或全量刷官方固件）。EDL 通道永远可用（9008 端口未加密）。

## 风险声明

- 修改 boot 链有变砖风险（EDL 可救）；解锁/改镜像失去保修
- **切勿 `fastboot flashing lock` 重锁**（XDA 有变砖先例）
- 本仓库未经 Droidspaces/联想审计，自担风险

## 致谢与来源

- [LTBox](https://github.com/miner7222/LTBox)（miner7222 等）— 免解 BL 工具链
- [XDA thread 4743906](https://xdaforums.com/t/lenovo-legion-y700-4th-generation-tb322fc-8g4-unlock-bootloader.4743906/) — 解锁与 testkey 情报
- [qdykernel/Build_Lenovo_sm8750](https://github.com/qdykernel/Build_Lenovo_sm8750) — 工具链与 AOSP 公钥签名路线
- [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) — kABI 补丁与内核配置指南
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)

## License

内核补丁与脚本：GPL-2.0 WITH Linux-syscall-note（与 Linux 内核一致）。详见 [LICENSE](LICENSE)。
