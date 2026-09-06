# Lenovo Legion Y700 Gen 4 (TB322FC) — Droidspaces Kernel

在 **bootloader 保持锁定** 的 Y700 四代上运行 [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 容器的自定义 GKI 内核 + KernelSU-Next root 完整方案。

English TL;DR: Lenovo ships this device's boot chain signed with the **public AOSP testkey**, so a custom kernel re-signed with that key passes AVB on a **locked** bootloader; combined with Qualcomm **EDL (9008)** writes (via [LTBox](https://github.com/miner7222/LTBox)), you get kernel-level root + Droidspaces **without unlocking** — no data wipe, no unlock warning. The kernel must be built with the **exact AOSP clang (r510928)** pinned by the branch, or vendor modules break (KMI contract).

| 项 | 值 |
|---|---|
| 设备 | Lenovo Legion Y700 2025 / **TB322FC**（骁龙 8 Elite, SM8750） |
| 系统 | ZUXOS 1.5.10.117（Android 16）实测；1.1.11.073/076 亦可 |
| 内核 | `6.6.89-android15-8-g14220ae4ce65-ab13680582-4k`（= 设备精确 commit） |
| root | KernelSU-Next v3.3.0（**LKM**，在 init_boot，不随 boot 丢失） |
| BL | **locked** ✅（Play Integrity 友好） |
| WiFi/BT | ✅ 正常（bcmdhd→实为高通 cnss2/cfg80211 栈） |
| Droidspaces | ✅ check 通过 |

---

## 快速开始（已解锁/已 root 的设备）

```bash
# 1) 下载预编译 boot 镜像
curl -LO https://github.com/<you>/tb322fc-droidspaces-kernel/raw/main/images/boot-tb322fc-droidspaces-v4.img
sha256sum boot-tb322fc-droidspaces-v4.img
# bf337d09908ca477ed16dd6e322c45085485685681f72763bd6d02f84596670b

# 2) LTBox → Advanced → 分区写入 → boot_a ← 该文件（自动进 EDL）→ 重启
```

未 root 的设备：先按 [docs/GUIDE-macOS.md](docs/GUIDE-macOS.md) / LTBox 完成免解 BL root。

## 从零构建

```bash
./scripts/get-toolchain.sh ./toolchain      # AOSP clang r510928（必须！见下文坑#2）
# 从设备抓原厂配置（root 后）：
adb shell su -c "cat /proc/config.gz" > work/stock-config.gz && gunzip work/stock-config.gz
./scripts/build-kernel.sh ./work ./toolchain/clang18
./scripts/package-boot.sh work/kernel-6.6/arch/arm64/boot/Image out/boot-ds.img
```

## 工作原理（为什么免解锁也能刷内核）

```
联想固件 AVB 全链 = AOSP testkey 签名（公钥 sha1 2597c218...，私钥在 AOSP 源码公开）
vbmeta 中 boot = Chain Partition 描述符 → 只认"boot footer 由 testkey 签名"
  → 自定义内核 + testkey 重签 footer = 锁机可刷
写入通道 = 高通 EDL/9008（锁机可用；LTBox/qdlrs 均支持）
```

## 四个关键坑（全部实测踩中）

1. **AVB footer 必须带原厂 Prop 描述符**（`com.android.build.boot.fingerprint/os_version/security_patch`）—— 缺了它们 ABL 报"系统损坏"。`package-boot.sh` 已内置。
2. **工具链版本是 KMI 契约的一部分**：必须用分支钉死的 `clang-r510928`（`build.config.constants`）。用上游 clang 21 编译 → 与预编译 vendor 模块不兼容 → **logo bootloop**（配置完全原样也 loop，对照实验证实）。
3. **不能简单关 `CONFIG_MODULE_SIG`**：它会级联关掉 `SYSTEM_DATA_VERIFICATION` → `verify_pkcs7_signature` 不再导出 → cfg80211 加载失败 → cnd 崩溃 → **WiFi 挂**。正解：`MODULE_SIG=y` + `MODULE_SIG_KEY` 指向 testkey（自签证书）。
4. **vermagic 伪装**：6.6 新 setlocalversion 废除了 `.scmversion` → 用 `make KERNELRELEASE=<完整字符串>` 直通（Kleaf 同款）。注：MODVERSIONS 下 vermagic 版本部分其实不严格比对（原厂模块 vermagic 是 `maybe-dirty` 也能加载），但伪装无害且推荐。

## 目录结构

```
images/boot-tb322fc-droidspaces-v4.img   预编译镜像 + sha256sums.txt
patches/0001-kabi-sysvipc-6.6.patch      SYSVIPC kABI 补丁（6.6 适配版）
patches/droidspaces.config.fragment      配置增量（叠加在原厂 config.gz 上）
scripts/get-toolchain.sh                 下载 AOSP clang r510928
scripts/build-kernel.sh                  一键构建
scripts/package-boot.sh                  打包 + testkey 签名
docs/TASK.md                             工程任务书（根因全记录）
docs/RESEARCH.md                         解锁/root 调研（XDA/官方核实）
docs/GUIDE-macOS.md                      免解 BL root 操作指南
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
