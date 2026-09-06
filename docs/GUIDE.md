# Y700 四代 (TB322FC) 指南

> 🌐 [English](GUIDE_EN.md) | 简体中文

> 依据：XDA thread 4743906 全 5 页（Wayback 2026-04-25）+ LTBox 项目/note.com 实测教程 + 镜像站核实
> 当前设备：ZUXOS **1.1.11.120**（ST_250727），BL 锁定

---

# LTBox 免解锁 root —— 不降级、不清数据

> ✅ **2026-09-04 本机实测成功**（TB322FC，见下方「实跑记录」）

## 实跑记录（已验证顺序）

### 最终验证结果（2026-09-04，全部通过）

```text
ro.build.display.id : TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.117_ST_260212 ✅
uname -r            : 6.6.89-android15-8-g14220ae4ce65-ab13680582-4k（原厂内核，LKM 不换核）✅
su -c id            : uid=0(root) context=u:r:ksu:s0 ✅
/data/adb/          : ksu  ksud  modules ✅
wlan0               : UP,LOWER_UP ✅
fastboot device-info: Device unlocked: false ✅✅（BL 保持锁定 + root 共存）
```

**结论：联想 testkey 漏洞链完整成立** —— 锁机状态下经 EDL+testkey 重建 vbmeta
即可持久 root（KSU-Next v3.3.0 LKM），无解锁警告、无 FRP、OTA 已禁。

### 执行顺序

1. **Flash Firmware**：LTBox 直接全量刷 **ZUXOS 1.5.10.117**（Android 16）
   —— 自动 EDL、擦 frp/metadata/userdata、刷 6 套 rawprogram+patch、
   设可启动 LUN、重启。全程无需 QFIL/Windows。
2. **System Updates → 禁用 OTA**：自动卸载 com.lenovo.ota /
   com.tblenovo.lenovowhatsnew / com.lenovo.tbengine ✅
3. **Root Device → KernelSU Next → LKM**：
   - 自动下载 KSU-Next v3.3.0（spoofed 管理器 APK + `android15-6.6_kernelsu.ko` + ksuinit）
   - EDL 转储原厂 init_boot/vbmeta → **备份在** `~/Library/Application Support/ltbox/backups/backup_init_boot`
   - magiskboot 拆 init_boot → cpio 替换 init + 暂存 kernelsu.ko → 重打包
   - **vbmeta 重建**：原厂公钥 `2597c218aae470a130f61162feaae70afd97f011`
     = **AOSP testkey_rsa4096**（实锤联想用测试密钥做 AVB）
   - EDL 刷回修补 init_boot_a + 重建 vbmeta_a → 开机即 root，**BL 全程保持锁定**

## 原理

联想固件用 **AOSP 公共测试密钥**做 AVB 签名（"Lenovo testkey 漏洞"，
polygraphene/LTBox 均基于此）。LTBox 用同一把 testkey 重建 vbmeta，
经 **EDL（锁机也可用）**写入修补后的镜像 → 不需要解锁 BL 即可 root，
且无开机解锁警告。

## 能力

- Root 方案：**KernelSU / KernelSU Next / SukiSU Ultra / ReSukiSU / APatch / FolkPatch / Magisk**
- 安装方式：**LKM**（新版固件如 263 已验证支持；GKI 2.0 设备通用）
- System Updates：**禁用/恢复 OTA**（防强制升 Android 16 1.5.x！）
- Advanced：EDL 读写任意分区、重建 vbmeta、跨区转换、回滚绕过

