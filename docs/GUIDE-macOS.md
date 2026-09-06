# Y700 四代 (TB322FC) 解锁 + KernelSU-Next 完整指南（macOS 操作机版）

> 依据：XDA thread 4743906 全 5 页（Wayback 2026-04-25）+ LTBox 项目/note.com 实测教程 + 镜像站核实
> 当前设备：ZUXOS **1.1.11.120**（ST_250727），BL 锁定
> 官方申请结果（2026-09）：**120 被拒**，要求邮寄服务站 → 官方路死心

---

# ⭐ 路线 0（新推荐）：LTBox 免解锁 root —— 不降级、不清数据

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

## 能力（LTBox v3.2.8，有 macOS universal 版）

- Root 方案：**KernelSU / KernelSU Next / SukiSU Ultra / ReSukiSU / APatch / FolkPatch / Magisk**
- 安装方式：**LKM**（新版固件如 263 已验证支持；GKI 2.0 设备通用）
- System Updates：**禁用/恢复 OTA**（防强制升 Android 16 1.5.x！）
- Advanced：EDL 读写任意分区、重建 vbmeta、跨区转换、回滚绕过

## 步骤（macOS）

```bash
# 1) 下载 LTBox（macOS universal）
mkdir -p ~/y700 && cd ~/y700
curl -LO "https://github.com/miner7222/LTBox/releases/download/v3.2.8/LTBox-macos_universal-v3.2.8.tar.gz"
curl -LO "https://github.com/miner7222/LTBox/releases/download/v3.2.8/LTBox-macos_universal-v3.2.8.tar.gz.sha256"
shasum -a 256 -c LTBox-macos_universal-v3.2.8.tar.gz.sha256
tar xzf LTBox-macos_universal-v3.2.8.tar.gz

# 2) 下载与你平板同版本的固件（120 已核实存在，~6.6GB，建议用 Gopeed 等下载器）
curl -C - -O "https://mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/TB322FC_CN_OPEN_USER_Q00041.1_V_ZUXOS_1.1.11.120_ST_250727.7z"
# 解压（需 7z：brew install sevenzip）：得到 firmware/image/ 目录
7z x TB322FC_CN_OPEN_USER_Q00041.1_V_ZUXOS_1.1.11.120_ST_250727.7z -o./fw120

# 3) 【关键】用固件的 image 内容覆盖 LTBox 的 image 目录
#    （note.com 实测：不替换会报错；替换后全自动流程才顺）
cp -R ./fw120/image/. <LTBox目录>/image/

# 4) 启动 LTBox → 菜单选 Root Device（菜单 5）
#    - Root 方案：KernelSU Next
#    - 安装方式：LKM
#    - 工具自动重启平板进 EDL → 传输 → 修补 → 重建 vbmeta → 刷回 → 重启
#    - 看到 Successfully 即完成

# 5) 开机后：装 KernelSU-Next 管理器 APK → 应显示"未安装"→ 刷入后变"已安装"
#    adb install KernelSU-Next-*-release.apk

# 6) 【必做】LTBox → System Updates → 禁用 OTA
#    （XDA 血泪：平板会强制自动升 Android 16 1.5.x，升上去解锁/降级窗口全关）
```

## 路线 0 的边界

| 需求 | 路线 0 够吗 |
|---|---|
| KernelSU-Next root（Magisk 级需求） | ✅ 完全够 |
| 自定义内核（**Droidspaces**、调度优化） | ❌ 需解锁 BL → 走路线 1/2 |
| TWRP / 任意 fastboot 刷写 | ❌ 需解锁 |

---

# 路线 1（备选）：降级 + 解锁（要自定义内核/Droidspaces 才需要）

官方申请在 120 已被拒（需邮寄服务站），DIY 解锁在 120 已修复（假解锁回退）。
解锁仅对 **≤1.1.11.076** 有效 → 必须降级。

# 第一部分：降级（120 → 73 → 76）

120 修复了 sn 签名漏洞（XDA 实测：DIY sn.img = 假解锁会回退），
所以需要先降级到 abl 未修复的版本。

## 1.0 环境选择（macOS 用户三选一）

| 方案 | 可靠性 | 说明 |
|---|---|---|
| ① 真 Windows PC / Intel Mac Boot Camp | ⭐ XDA 全部成功案例 | 首选 |
| ② Parallels/UTM + Win11 ARM | ⚠️ 有坑 | QFIL 可跑（Prism 转译），但 **ARM Windows 的高通 9008 驱动签名**是常见拦路虎 |
| ③ macOS 原生 qdl-rs | 🧪 本机型未验证 | polygraphene 维护的 Rust EDL 工具，跨平台；适合"只换 abl"轻方案（1.6 节） |

## 1.1 下载固件 73（~6.6GB，链接已核实有效）

```
https://mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/TB322FC_S200001_2506121310_250612_PRC.7z
```

Mac 上下载（可断点续传）：
```bash
mkdir -p ~/y700 && cd ~/y700
curl -C - -O "https://mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/TB322FC_S200001_2506121310_250612_PRC.7z"
# 校验完整性（下载完记录 sha256，跨机传输后比对）
shasum -a 256 TB322FC_S200001_2506121310_250612_PRC.7z
```

用 7-Zip 解压。**解压目标路径绝对不能有空格/中文**
（XDA 实锤：`C:\Users\x\LENOVO Y700\...` 这类路径 = fh_loader/QSaharaServer 报错元凶），
例如 `D:\y700\73` 或 `C:\y700_73`。

包内典型内容：`rawprogram*.xml`、`patch*.xml`、`xbl_s_devprg_ns.melf`（EDL loader）、
各分区 img、以及**自带的 .bat 刷写工具**（QFIL 失败时的备选）。

把解压后的文件夹传给 Windows（移动硬盘 / 局域网共享 / VM 挂载）。

## 1.2 装驱动（Windows）

安装 **Qualcomm HS-USB QDLoader 9008 驱动**（固件包常附 `QUDS`/`Qualcomm_Drivers`，
或搜 "Qualcomm USB Drivers" 下载）。装完重启电脑。

## 1.3 进 EDL（XDA #79 实测手法）

1. 平板**完全关机**（等屏幕全黑）
2. **按住音量上键不放，同时把 USB 线插入平板长边那个口**
3. 屏幕可能只闪电池图标 —— 正常
4. Windows 设备管理器出现 **`Qualcomm HS-USB QDLoader 9008 (COMx)`** = 成功，记下 COM 号
5. 若出现的是 "Qualcomm Diagnostics"（诊断模式）而非 9008 → 换线/换 USB 口/重装驱动重试

## 1.4 QFIL 刷入（XDA #30 实测参数）

1. 打开 **QFIL V3** → 上方选 **Flat Build**
2. `Browse` 选 Programmer/Loader：解压目录里的 `xbl_s_devprg_ns.melf`
3. `XML` 添加：**勾选全部** `rawprogram*.xml` + 全部 `patch*.xml`
4. 右侧 `Available Options` 勾选 `Erasing All Before Download`（降级必须擦干净）
   —— 若报 Sahara 错误，进 Settings 调整 reset/timeout 项，或换 USB 口
5. `Start Download` → 进度条走完 → 平板自动重启 → 开机即为 73
6. **备选（rekesons 三台笔记本 QFIL 全失败后的成功路）**：
   直接运行**固件包自带的 .bat 刷写脚本**，按提示填 COM 口号

## 1.5 升到 76

73 开机走完引导（联网；可能要求登录原 Google/联想账号 = FRP，见 1.8）后：
设置 → 系统更新 → OTA 到 **1.1.11.076**。
（XDA：76 无需另下包，OTA 可达；若推不到 76 就从镜像站下 076 全量包重复 1.4）

## 1.6 轻方案：只换 abl（不降级系统 —— 验证较少，但快）

原理（hitin911，XDA #49/#66）：120 只是**新 abl** 修了签名校验 →
把 `abl_a`/`abl_b` 刷成 076 版，系统其余保持 120，即可恢复 DIY 解锁。

- Windows：QFIL 里只勾 abl 两行（编辑 rawprogram 或手动选择）+ EDL 刷入
- macOS 原生（qdl-rs，polygraphene 用法改编，未在本机型验证）：
  ```bash
  brew install rust   # 或下载 polygraphene/qdlrs 预编译
  # 从 73 包提取 abl.img；平板按 1.3 进 EDL 后：
  qdl --loader xbl_s_devprg_ns.melf --storage-type ufs write abl_a abl.img
  qdl --loader xbl_s_devprg_ns.melf --storage-type ufs write abl_b abl.img
  qdl reset
  ```
- ⚠️ abl 混版兼容性无多人背书；失败仍可回到 1.4 全量刷（EDL 永远在）

## 1.7 降级后主线

76（或 abl 换好的 120）→ 回到本指南第二部分 DIY 解锁 → 第三部分 root。

## 1.8 降级专属警告

- 全量刷 = **全部数据清空**（super 重写），提前备份
- 首次开机可能触发 **FRP**：需当初登录过的 Google/联想账号密码
  （rekesons 反面案例：重锁变砖→送修→121+FRP，基本报废 —— 所以别重锁）
- 反回滚保护：EDL 在 PBL 层，**不受** Android 侧 anti-rollback 限制（XDA 有 202→120 降级成功报告）

---

# 第二部分：解锁（76 或换过 abl 的系统上）

## 2.1 读 SN（已做过，存档）

```bash
adb shell getprop ro.boot.bootload_sn
# 9C3A181E501917A98B1EA0ABBEF64FCCD014FC42F3A00011DDC8BBB7B78CF9C4
```

## 2.2 生成自己的 sn.img

浏览器打开 XDA 生成器：**https://jsfiddle.net/2uvz1fwn/**
→ 粘贴 64 位 SN → 下载 `sn.img` → 放到无空格路径

```bash
cd ~/y700
xxd sn.img | grep -i "9c3a181e" | head -2   # 验证 SN 已嵌入
```

（备选：NekoYuzu 工具 https://lenovobl.neko.ink，Windows 闭源）

## 2.3 解锁 —— ⚠️ 必须真 fastboot，不是 fastbootd

`adb reboot fastboot` 进的是 **fastbootd**，刷 unlock 会报
`Download is not allowed on locked devices`（XDA #63 多人踩坑）。

```bash
adb reboot bootloader            # ← 正确！或关机后 音量下+电源
fastboot getvar product          # 自检：能读到变量 = 真 fastboot
fastboot flash unlock sn.img     # 期望 OKAY
fastboot oem unlock              # 或 fastboot oem unlock-go
```

平板界面：**音量下 ×2** 选 UNLOCK → **电源键**确认 → 清数据重启（3-5 分钟）

## 2.4 验证真解锁（120 混版时尤其重要）

```bash
adb shell getprop ro.boot.verifiedbootstate   # 期望 orange
adb reboot bootloader; fastboot getvar unlocked
```
重启两次仍 unlocked = 真解锁；若回退 locked = abl 还是新版（回 1.6/1.4）。

---

# 第三部分：KernelSU-Next root（LKM，不动内核）

## 3.1 装管理器

https://github.com/KernelSU-Next/KernelSU-Next/releases/latest → `*-release.apk`
```bash
adb install KernelSU-Next-*-release.apk
```
打开显示"**未安装**" = 支持 ✅

## 3.2 取与系统同版本的 init_boot.img

```bash
adb shell getprop ro.build.display.id   # 记下确切版本
```

- 在 76：XDA #13 楼有 076 版 init_boot/boot/recovery 附件（需 XDA 账号）；
  或从 076 全量包提取
- 在 120：下载 120 包提取（链接见第一部分 1.1 同目录）：
  ```bash
  curl -C - -O "https://mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/TB322FC_CN_OPEN_USER_Q00041.1_V_ZUXOS_1.1.11.120_ST_250727.7z"
  7z x TB322FC_CN_*120*.7z init_boot.img
  ```

## 3.3 修补 + 刷入

```bash
adb push init_boot.img /sdcard/Download/
# 管理器 → 右上安装 → 选择并修补一个文件 → 选它 → 等完成
adb pull /sdcard/Download/*_patched*.img

adb reboot bootloader
fastboot getvar current-slot              # 假设 a
fastboot flash init_boot_a <patched文件>
fastboot reboot
```

## 3.4 验证

- 管理器"已安装"；`adb shell su -c id` → `uid=0(root)`
- WiFi/蓝牙正常（LKM 不换内核，无签名坑）
- 要 Droidspaces → 需自定义内核路线（见 RESEARCH.md 路线 2，
  `zzh20188/GKI_KernelSU_SUSFS` CI 有 Droidspaces 选项）

---

# 附：日常维护铁律

1. **永不重锁**（`fastboot flashing lock` 有变砖先例）
2. **OTA 姿势**：root 状态下先刷回 stock init_boot → OTA → 重新修补新 init_boot 刷入；
   **263 起解锁设备收不到 OTA**，只能手动全量刷
3. 不刷与系统版本不匹配的 init_boot/boot
4. 全程不断 USB、电量 >50%
5. 所有工具路径不含空格/中文
