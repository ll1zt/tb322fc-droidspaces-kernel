# Lenovo 拯救者 Y700 四代 (TB322FC) — 解锁 BL + KernelSU-Next Root 调研

> 调研日期：2026-09-04 · 多轮中英文搜索整理
> ⚠️ 一切操作有风险：解锁会清空数据、可能失去保修。操作前备份（尤其字库/EDL 通道确认）。

---

## 〇、设备速览（已核实）

| 项目 | 值 |
|---|---|
| 型号 | **TB322FC**（国行 Legion Y700 2025 / 四代） |
| 平台 | 高通 **SM8750**（骁龙 8 至尊版 / 8 Elite，XDA 标题"8G4"） |
| 系统 | ZUI 17（Android 15，OTA 后可到 16） |
| 内核 | **GKI 6.6.111**（GKI 2.0，KMI = `6.6-android15-x`） |
| 分区 | A/B，boot header v4，**有独立 init_boot** |
| 存储 | UFS，**支持 9008/EDL 救砖，端口未加密** |
| TWRP | ✅ 已有社区移植（polygraphene，基于 twrp-16.0） |

先确认自己的内核版本（决定一切镜像选择）：

```bash
adb shell uname -r
# 形如 6.6.111-android15-xxxx-gxxxxxxxx-xxxx
# KMI = 前两段+android代际+generation，即 6.6-android15-x
```

---

## 一、解锁 Bootloader

### ⚡ 固件版本决定一切（先看这里！）

XDA 一手报告（thread 4743906，多用户交叉验证）：

| ZUXOS/ZUI 版本 | 解锁状态 |
|---|---|
| **1.1.11.073** | ✅ 可解（需 QFIL 降级到达） |
| **1.1.11.076** | ✅ 可解（73 升上来后仍有效；有人直接在此版本解锁+KSU-Next root 成功） |
| **1.1.11.120 / 121** | ❌ **已修复**：解锁"看似成功实则会回退"，root 不可行；121 连 OEM 解锁开关都会崩溃 |

**已验证的完整路径**（XDA 用户，耗时约 6 小时）：
```
QFIL 降级到 73 → OTA 升到 76 → 免申请解锁 → 提取 init_boot → KernelSU-Next root ✅
```

降级工具（XDA 实测细节）：
- **QFIL V3** + loader `xbl_s_devprg_ns.melf`，勾选全部 rawprogram + patch 文件
- 固件 73 镜像：`mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC/TB322FC_S200001_2506121310_250612_PRC.7z`
  （只需刷 73，76 可 OTA 升上去）
- 需正确安装 Qualcomm 9008 驱动；**所有路径不能含空格**（否则 fh_loader/QSaharaServer 报错）
- 另有用户（ZUXOS_1.1.11.076）在 XDA #13 楼分享了原版 init_boot.img / boot.img / recovery.img 附件

### 方法 A：免申请（sn 签名漏洞）—— XDA 确认可行

**原理**：Y700 四代的 abl 存在 **sn 签名漏洞**（gitee topaz 工具 README 原话：
"本设备暂时没有类似拯救者 Y700 第四代的 sn 签名漏洞" —— 反证四代有）。
sn.img 的"解锁文件"**并不依赖联想服务器签发**：任意官方 sn.img 模板 +
**自己设备的 64 位 Bootloader_SN** = 有效解锁文件。

**步骤**（XDA 原帖完整流程）：

```bash
# 1. 获取自己的 64 位 Bootloader_SN（二选一）
#    方法 1：fastboot 下取两半拼接（各 32 hex）
adb reboot bootloader
fastboot getvar all    # 找 Bootloader_SN_Part1 和 Bootloader_SN_Part2
#    例：Part1=d2a746c23a410256b1f4a94a299880f8
#        Part2=f34a8bbc2dbc6d298d4d322e093a997c
#        SN = d2a746c23a410256b1f4a94a299880f8f34a8bbc2dbc6d298d4d322e093a997c

#    方法 2（更简单）：系统内直接读完整 64 位
adb shell getprop ro.boot.bootload_sn

# 2. 生成自己的 sn.img（三选一）
#    a) 网页生成器（XDA rurie 制作，免 hex 编辑）：https://jsfiddle.net/2uvz1fwn/
#    b) 十六进制编辑器：打开任意官方 sn.img 模板，把内部 64 位 hex 替换为自己的 SN
#    c) NekoYuzu 工具（闭源 Windows）：https://lenovobl.neko.ink（XDA 多人确认好用）

# 3. 刷入解锁
fastboot flash unlock sn.img
fastboot oem unlock          # 或 fastboot oem unlock-go（两教程都见过，任选）
# 进确认界面：音量下 ×2 选 UNLOCK → 电源键确认 → 清数据解锁
```

**已知失败案例**：有用户在锁机状态刷 unlock 分区报
`FAILED (remote: 'Download is not allowed on locked devices')` ——
部分版本锁机下 fastboot 禁写；polygraphene 也证实锁机时 `fastboot flash` 不可用，
需走 **EDL/9008**（ZUI 1.5.10.138 及更早还有 testkey 漏洞可直写分区）。
若遇此报错：先确认固件在 73/76 可解区间，仍不行则用 QFIL/EDL 通道。

### 方法 B：官方申请（zui.com/iunlock）

适用于：不想碰 EDL/降级的用户。
（注意：120+ 即使申请到官方文件也可能被修复无效，先查版本。）

**入口**：`zui.com/iunlock`（官网"刷机/解锁"页，为 Y700 四代单独新增了入口）

**限制（重要）**：
- 需登录联想账号，**一个账号每年限 3 台设备**
- 新上市设备需上市一段时间后才能申请
- **解锁文件每天限量发放 —— 夜里 12 点（00:00）提交申请成功率最高**
- **Gmail 可能收不到解锁文件，用 QQ 邮箱**
- 解锁会清空全部数据

**步骤**：

```bash
# 1. 收集两个号
#    SERIAL NUMBER：进 fastboot 看（或 fastboot getvar all）
#    例：SERIAL NUMBER - 4311664a
adb reboot bootloader
fastboot getvar all          # 记下 SERIAL NUMBER

#    Bootloader_SN：开机状态下
adb shell getprop ro.boot.bootload_sn   # 若为空再试 ro.boot.bootloader_sn

# 2. 到 zui.com/iunlock 填表申请 → 邮件收到 unlock_bootloader.img（即 sn.img）

# 3. 解锁
adb reboot bootloader
fastboot flash unlock sn.img            # 邮件附件改名/即官方解锁文件
fastboot oem unlock-go                  # 进入确认界面
# 音量键选第二行 UNLOCK → 电源键确认 → 自动清数据并解锁重启

# 4. 验证
fastboot getvar unlocked   # 或 fastboot oem device-info → Device unlocked: true
```

### 方法 C：XDA 一键工具

`Lenovo Bootloader Unlocker (One Click)`（XDA thread 4746935）：
内置 ADB+fastboot 全自动流程，**支持多数联想平板含 Y700 Gen4**（不含摩托罗拉）。
本质仍是 sn.img 流程的自动化封装。

### 救砖通道与重锁警告

- 全系列支持 **9008/EDL 线刷救砖与降级**，端口未加密
- ZUI 1.5.10.138 及更早版本存在 **Lenovo testkey 漏洞**：锁 BL 状态也能通过 EDL 直写分区
  （polygraphene 的 TWRP README 记载，用 qdlrs + xbl_s_devprg_ns.melf 可写 recovery_a/b）
- ⚠️ **重锁（relock）风险矛盾，强烈建议不要重锁**：
  XDA 有人声称 `fastboot flashing lock` 重锁测试成功（rurie），
  但另一用户（#11 楼）重锁后**变砖**：卡死 fastboot、recovery 失效、
  无法再解锁、找不到 prog_firehose_ddr.elf。两说并存，宁可信其危。

---

## 二、KernelSU-Next Root

Y700 四代是 GKI 2.0（6.6）设备，KSU-Next 兼容表明确支持
「5.10+ (GKI 2.0)：可运行预置镜像和 **LKM/KMI**」。两条路线：

### 路线 1：LKM 模式（推荐首选，不动内核）

KSU-Next 以**可加载内核模块**注入，**不替换原厂内核**：

- 改的是 **init_boot** 分区（Android 13+ 出厂设备的 LKM 修补对象）
- 优点：OTA 友好（管理器可直接装到另一槽）、可临时卸载 root、不触发 AVB 变砖风险低
- 前提：解锁 BL ✅

**步骤**：

```bash
# 1. 从官方固件包提取当前版本的 init_boot.img（版本必须与系统一致！）
#    线刷包直接有；卡刷包用 payload-dumper-go 提取

# 2. 手机安装 KernelSU-Next 管理器（GitHub Releases: KernelSU-Next/KernelSU-Next）
#    打开显示"未安装" = 设备受支持

# 3. 管理器 → 右上角安装 → "选择并修补一个文件" → 选 init_boot.img
#    （首次安装无 root 时走这条；修补产物在 Download 目录）

# 4. 刷入修补后的 init_boot
adb reboot bootloader
fastboot flash init_boot patched_init_boot.img    # 或 init_boot_a
fastboot reboot

# 5. 打开管理器确认"已安装"，su 授权生效
```

> 替代：`ksud boot-patch -b init_boot.img`（PC 端命令行，支持 Win/Linux/macOS）。
> 若设备支持 `fastboot boot`，可先临时启动试验，失败重启即恢复。

**XDA 实跑验证**（与本路线一致）：
- 原帖 OP 建议：9008 工具提取 **init_boot.img** → 修补 → 刷回
- 用户报告：降级 73→升 76 → 解锁 → 提取 init_boot → **KernelSU Next root 成功**
- 用户 rekesons："Rooting successful via KernelSU method"

**LKM 模式的局限**：内核还是原厂 → **没有自定义 CONFIG**。
如果你的目标是 Droidspaces（需要 SYSVIPC/IPC_NS/PID_NS 等），LKM 模式**不够**，走路线 2。

### 路线 2：GKI 模式（自定义内核，功能全）

替换 boot.img 里的内核 Image，可集成 KSU + SUSFS + 调度补丁 + 自定义 CONFIG。

**现成资源（社区 CI，主要面向 TB322FC/SM8750）**：

| 仓库 | 内容 | 备注 |
|---|---|---|
| `qdykernel/Build_Lenovo_sm8750` | GitHub Actions 云编译 Lenovo SM8750 内核，**(Re)SukiSU + SUSFS + ADIOS**，自动出 AnyKernel3 包 | ⭐ 用 **AOSP 公共测试密钥签名**（见下方"签名坑"）；fork 后 Run workflow 即可，首编约 12 分钟 |
| `zzh20188/GKI_KernelSU_SUSFS`（镜像：`qianmingzi7-coder/tb322fc-r2-kernel-public-build`） | 通用 GKI 内核 CI，**明确支持 6.6**，含 **Droidspaces 容器选项**（6_7_8/1_2_3/3_4_5 槽位 kABI 补丁） | 对跑容器最有价值；有 stock_defconfig 伪装 /proc/config.gz 功能 |

**注意**：这两个 CI 默认集成的是 **SukiSU / ReSukiSU / 原版 KernelSU**，不是 KernelSU-Next。
要 **KSU-Next 内核**，在 CI 里换 KSU 源（其 setup.sh 机制）：

```bash
# 内核源码根目录集成 KernelSU-Next（stable/next/指定tag）
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s v3.3.0
# 然后 CONFIG_KSU=y 编译，出 Image → AnyKernel3 或 magiskboot 修补 boot.img
```

**GKI 模式刷入（任选）**：

```bash
# a) 有 TWRP（polygraphene 移植已可用）：
adb push AnyKernel3-*.zip /sdcard/ && adb reboot recovery   # TWRP 里安装
# b) fastboot 直刷 boot（需内核压缩格式与原厂一致，见下）
# c) 管理器"直接安装"（需已有临时 root，如 fastboot boot 法）
```

### ⚠️ 关键坑：模块签名（与 Pixel 6 那次完全同源的问题）

自定义内核若用**新生成的随机密钥**，而 vendor 模块**带原厂签名**，
`init_module` 会 EPERM → WiFi/蓝牙等 GKI 模块加载失败。

Y700 四代的缓解因素：
- 联想（多数国产 OEM）用 **AOSP 公共测试密钥**签模块 ——
  `qdykernel` 仓库标题即"Using AOSP public key signing"，把 AOSP testkey 公钥编进内核即可通过验证
- 或者干脆 **关闭 CONFIG_MODULE_SIG**（Pixel 6 方案，简单粗暴）
- 或者 **LKM 模式**（不替换内核，天然无此问题）

### 内核压缩格式

刷 GKI boot.img 前确认原厂 kernel 的压缩格式（`magiskboot unpack boot.img` 查看），
国行高通平板常见 **lz4**；格式不对刷入不开机。

---

## 三、验证清单

```bash
adb shell uname -r                    # GKI 模式：应显示带 kernelsu/自定义后缀；LKM：保持原厂
adb shell su -c id                    # KernelSU-Next 授权后 uid=0
# 管理器显示"已安装"、版本号匹配
# WiFi/蓝牙正常（重点！签名坑的试金石）
adb shell su -c "lsmod | grep -iE 'wlan|bcmdhd|bluetooth|cfg80211'"
# 若跑容器：
adb shell su -c "droidspaces check"
```

## 四、回滚

```bash
# 刷回原厂 boot/init_boot 即恢复（BL 保持解锁状态）
fastboot flash boot       stock_boot.img
fastboot flash init_boot  stock_init_boot.img
# 彻底变砖：9008/EDL 线刷官方固件（端口未加密，可降级）
```

---

## 五、给 Droidspaces 场景的建议（结合本项目上下文）

1. 先解锁 BL → **路线 2** 用 `zzh20188/GKI_KernelSU_SUSFS` CI（选 **Droidspaces=678** 槽位补丁 + KSU 类型）
2. 其 stock_defconfig 伪装功能可让 `/proc/config.gz` 与官方一致（过检测）
3. 6.6 内核的 SYSVIPC kABI 补丁与 6.1 同理（该 CI 已内置三槽位变体，bootloop 就换 123/345）
4. 注意 SPL 防回滚：内核安全补丁级别不能低于当前系统（刷旧内核可能不开机）

## 六、风险汇总

| 风险 | 说明 | 缓解 |
|---|---|---|
| 解锁清数据 | 强制 | 提前备份 |
| **固件版本坑** | 120/121 已修复解锁漏洞（假解锁/回退） | 降级 73 → OTA 76 后再解 |
| 重锁变砖 | XDA 有重锁后永久变砖报告（与"重锁成功"并存） | **不要重锁** |
| 锁机禁写 | 部分版本 `fastboot flash unlock` 报 Download not allowed | 走 EDL/9008（testkey 漏洞） |
| 官方申请额度 | 若走官方：日限量 00:00 抢；账号年限 3 台；Gmail 收不到 | 用 QQ/大陆邮箱 |
| 版本不匹配 | 内核/固件/init_boot 必须同版本 | 提取当前版本固件 |
| 模块签名 | GKI 模式 WiFi/BT 可能挂 | AOSP testkey / 关 MODULE_SIG / LKM |
| bootloop | 压缩格式错 / SPL 回滚 | magiskboot 修补；备份原厂 boot |
| 保修 | 解锁即失保 | 已知晓 |

---

## 参考来源

**XDA 一手（本文解锁部分以此为准）**：
- 主帖（sn 签名漏洞免申请解锁 + 固件版本报告）：xdaforums.com/t/...4743906
  - 直连 403 时用 Wayback 快照：`web.archive.org/web/20260425165122/https://xdaforums.com/t/lenovo-legion-y700-4th-generation-tb322fc-8g4-unlock-bootloader.4743906/`
- sn.img 网页生成器：https://jsfiddle.net/2uvz1fwn/ （XDA rurie）
- NekoYuzu 解锁工具：https://lenovobl.neko.ink （闭源）
- 一键解锁工具：xdaforums thread 4746935
- 固件 73 镜像：mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC/
- "sn 签名漏洞"旁证（小新 Pad Pro GT 无此漏洞的声明）：gitee.com/WASDDestroy/topaz-ubl-cli

**中文教程（官方申请流程）**：
- ROM乐园实测：romleyuan.com/lec/read?id=1427；ROM基地：romjd.com/jiaocheng/content/29817
- 联想官方入口：zui.com/iunlock

**Root / 内核 / TWRP**：
- TWRP for TB322FC：github.com/polygraphene/android_device_lenovo_TB322FC
- SM8750 内核 CI（AOSP testkey 签名）：github.com/qdykernel/Build_Lenovo_sm8750
- GKI KernelSU+SUSFS CI（含 Droidspaces 选项）：github.com/zzh20188/GKI_KernelSU_SUSFS
- KernelSU 安装文档（LKM/GKI/KMI/SPL）：kernelsu.org/zh_CN/guide/installation.html
- KernelSU-Next：github.com/KernelSU-Next/KernelSU-Next（GKI 2.0 支持 LKM）
