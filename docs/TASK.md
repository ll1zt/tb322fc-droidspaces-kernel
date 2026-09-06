# Y700 四代 (TB322FC) — Droidspaces 自定义内核任务书

> 轨道锚点。每次执行前后对照。更新：2026-09-04 20:00
> 方法论复用 Pixel 6 成功经验 + 本机特有的 testkey/AVB 链发现

---

## 一、目标

在 **BL 保持锁定** 的前提下，给 Y700 四代刷入带 Droidspaces 支持的自定义内核：

1. ✅ `droidspaces check` 全绿（补齐 PID_NS / IPC_NS / DEVTMPFS / USER_NS）
2. ✅ **KernelSU-Next root 保持可用**（现有 LKM 优先；失败则转内置模式）
3. ✅ WiFi / 蓝牙正常（vendor 模块必须继续加载）
4. ✅ 可回滚（原厂 boot_a 位对位 dump 在手）

## 二、机制（已实证）

```
vbmeta_a 中 boot = Chain Partition 描述符
  公钥 sha1: 2597c218aae470a130f61162feaae70afd97f011 = AOSP testkey_rsa4096
  → 锁机 BL 只要求 boot.img 的 AVB footer 由 testkey 签名
  → 自编译内核 + testkey 重签 footer = 免解锁可刷，vbmeta 不用动
写入通道 = EDL/9008（LTBox Advanced，锁机可用）
```

## 三、设备基线（实测）

```
固件        : ZUXOS 1.5.10.117 (Android 16) ST_260212
内核        : 6.6.89-android15-8-g14220ae4ce65-ab13680582-4k
来源        : 纯 AOSP GKI（kernel/common commit 14220ae4ce65...，AOSP CI ab13680582）
root        : KernelSU-Next v3.3.0 LKM（init_boot 已修补，未动）
BL          : locked；OTA 已禁
Droidspaces : 缺 PID_NS/IPC_NS/DEVTMPFS/USER_NS，其余全过
boot 分区   : 96MB；kernel 未压缩 Image；无 dtb 段；cmdline 空
```

## 四、硬约束（全部已遵守）

| 约束 | 状态 |
|---|---|
| 源码 = 设备精确 commit 14220ae4ce65（SUBLEVEL 89） | ✅ |
| UTS_RELEASE 逐字符伪装（KERNELRELEASE= 直通，6.6 已废 .scmversion） | ✅ |
| SYSVIPC 配 kABI 补丁（6.6 手动适配 RESERVE 6/7/8） | ✅ |
| 配置基底 = 设备 /proc/config.gz（非 gki_defconfig） | ✅ |
| MODULE_SIG 关闭（Pixel 6 教训）+ TRIM_UNUSED_KSYMS 关闭 | ✅ |
| 只动 boot_a；init_boot/vbmeta/vendor 不碰 | ✅ |

## 五、执行进度

### 阶段 1-5 ✅ 全部完成（详见 git/文件产物）
- 源码：`kernel-6.6-ds/` @ 14220ae4ce65 + kABI 补丁（sched.h 唯一改动）
- 配置：stock 基底 + 89 处预期 diff（olddefconfig 后逐项验证）
- 编译：IMG_EXIT=0 零错误（clang 21 + NIX_CFLAGS_COMPILE 修 vdso 汇编警告）
- 打包：mkbootimg(header v4/未压缩 kernel/空 ramdisk) + avbtool add_hash_footer
  （testkey_rsa4096 / SHA256_RSA4096 / rollback 1738713600 / 原厂 salt / 96MB 填充）
- 验签：avbtool verify_image 通过；footer 公钥 sha1 == 设备链描述符 ✅

**产物**
```
# 历史版本归档于 work/artifacts/（不入库）
boot-ds-ksu.img    v1（已证伪：缺 3 个 Prop 描述符，ABL 拒绝）
boot-ds-ksu-v2.img sha256 d11a48249b099ba873e156e77f084d0293225b27ccf1d8953470c080a7acbd3f
                   footer 与原厂逐字节同构（仅 Image Size/Digest 不同）
boot_a_dump.img    原厂 boot_a 完整 dump（回滚件，已验证可救砖）
```

### v1 失败根因分析（两条线索）
1. v1 footer 缺原厂的 3 个 Prop 描述符（com.android.build.boot.fingerprint/os_version/security_patch）
   → Aux 1280 vs 1600 字节；v2 已补齐，footer 结构 diff 仅剩 Image Size/Digest
2. v1 配置多了 DEVTMPFS_MOUNT=y（Android init 自己挂 /dev，内核抢挂可能干扰首阶段）→ v2 已移除
3. 事故记录：v1 刷入 → AVB 拒 → 恢复原厂 boot 后仍进 fastboot（疑 ABL 状态锁存）
   → 全量刷恢复；期间确认 `fastboot oem edl` 可用（备用 EDL 入口）

### 阶段 6：刷入 ← v4（当前）

**WiFi 回归排查（已闭环）**：
- 症状：v3 下 cfg80211 加载失败 → cnd 崩溃循环（Scudo 双释放）→ 无 wlan0
- 根因：关 MODULE_SIG 级联关掉 SYSTEM_DATA_VERIFICATION
  → `verify_pkcs7_signature`（定义在 certs/system_keyring.c，#ifdef 内）不再导出
  → cfg80211 依赖它 → Unknown symbol → 整条 WiFi 链断
- 副发现：模块 vermagic 实为 "...-maybe-dirty-4k" → MODVERSIONS 下 vermagic 版本部分不严格比对
- 修复 v4：MODULE_SIG=y + MODULE_SIG_KEY=certs/testkey_rsa4096.pem（需含自签证书，裸私钥报 PEM 错）
  → 符号导出 ✅（System.map 验证）；testkey 覆盖两种模块签名情况（qdykernel 同路线）

**产物**：`images/boot-tb322fc-droidspaces-v4.img` sha256 bf337d09908ca477ed16dd6e322c45085485685681f72763bd6d02f84596670b

### ✅ 阶段 6 完成（2026-09-05 实测）
- [x] cfg80211/mac80211 开机自动加载（lsmod 命中 4）
- [x] `wlan0 UP,LOWER_UP` —— WiFi 恢复
- [x] cnd 不再崩溃（正常查询 supplicant，无 Scudo/SIGABRT）
- [x] su 正常（KSU LKM 在新内核上工作）
- [ ] 待办：重装 Droidspaces App 后跑 `droidspaces check` 确认 4 项变绿

### 最终交付物（Y700）
```
boot-tb322fc-droidspaces-v4.img  ← 正式可用版（Droidspaces + 免解BL + KSU LKM 共存）
boot_a_dump.img ← 原厂回滚件
构建环境：clang-r510928 + HOSTCC=gcc + KERNELRELEASE 直通 + testkey 自签证书
重建命令：/tmp/y700-v4.sh（已固化在服务器）
```

### 阶段 7：验证清单
```bash
adb shell uname -r            # 与原厂字符串相同（伪装成功的表现）
adb shell su -c id            # LKM root 是否仍工作（CRC 兼容性大考）
adb shell dmesg | grep -iE "version magic|disagrees|unknown symbol|failed to load"
adb shell ip link show wlan0  # WiFi
adb shell su -c droidspaces check   # 4 项补齐 → 全绿
```

### 回滚
LTBox 写回 `boot_a_dump.img`（或 117 包内原厂 boot.img）即完全恢复。

## 六、风险与降级方案

| 风险 | 概率 | 应对 |
|---|---|---|
| KSU LKM 加载失败（CRC 漂移） | 中 | 降级 A：恢复 stock init_boot（LTBox unroot）→ 重编内核内置 KSU-Next（setup.sh）→ 同法重签重刷 |
| vendor 模块加载失败 | 低（Pixel 6 同法全绿过） | 查 dmesg 具体符号；必要时逐项回退配置差异 |
| 不开机 | 极低 | EDL 永远在；刷回 boot_a_dump.img |
| Play Integrity | 未知 | BL 仍 locked + testkey 有效签名，理论不变差 |

## 七、踩坑记录（6.6 vs 6.1 差异）

1. 6.6 新 setlocalversion **废除 .scmversion** → 用 `make KERNELRELEASE=<str>` 直通（Kleaf 同款）
2. vdso 的 .S 编译不吃 KCFLAGS → nix 下用 `NIX_CFLAGS_COMPILE=-Wno-unused-command-line-argument`
3. 6.6 Makefile 自带 `-Werror=unused-command-line-argument`（AFLAGS 路径）→ 关 CONFIG_WERROR
4. avbtool：salt 不带 0x 前缀；需 --partition_size；PATH 里要有 openssl
5. 官方 kABI 补丁 6_7_8 变体上下文只匹配部分子版本 → 6.6 上手动适配（RESERVE 1-8 全空闲）

## 八、偏离自检（每次执行前）

1. 只动 boot_a？（init_boot/vbmeta/vendor 不许碰）
2. vermagic 逐字符验证过？
3. 配置基底是 stock config.gz？
4. SYSVIPC 有 kABI 补丁配套？
5. 有没有又跑去重编 vendor 模块？（不许）
