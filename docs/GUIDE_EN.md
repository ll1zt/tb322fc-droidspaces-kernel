# Y700 Gen 4 (TB322FC) Guide

> 🌐 English | [简体中文](GUIDE.md)

> Based on: XDA thread 4743906 (all 5 pages, Wayback 2026-04-25) + the LTBox
> project / note.com hands-on guides + mirror-site checks
> Current device: ZUXOS **1.1.11.120** (ST_250727), BL locked

---

# LTBox no-unlock root — no downgrade, no data wipe

> ✅ **Verified on this device 2026-09-04** (TB322FC, see the run log below)

## Run log (verified order)

### Final verification results (2026-09-04, all passing)

```text
ro.build.display.id : TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.117_ST_260212 ✅
uname -r            : 6.6.89-android15-8-g14220ae4ce65-ab13680582-4k (stock kernel, LKM keeps the core) ✅
su -c id            : uid=0(root) context=u:r:ksu:s0 ✅
/data/adb/          : ksu  ksud  modules ✅
wlan0               : UP,LOWER_UP ✅
fastboot device-info: Device unlocked: false ✅✅ (locked BL + root coexist)
```

**Conclusion: the Lenovo testkey chain works end to end** — with the device
locked, rebuilding vbmeta via EDL + testkey yields persistent root
(KSU-Next v3.3.0 LKM), no unlock warning, no FRP, OTA disabled.

### Execution order

1. **Flash Firmware**: LTBox full-flashes **ZUXOS 1.5.10.117** (Android 16)
   — automatic EDL, wipes frp/metadata/userdata, flashes 6 rawprogram+patch sets,
   sets the bootable LUN, reboots. No QFIL/Windows needed at any point.
2. **System Updates → Disable OTA**: automatically uninstalls com.lenovo.ota /
   com.tblenovo.lenovowhatsnew / com.lenovo.tbengine ✅
3. **Root Device → KernelSU Next → LKM**:
   - auto-downloads KSU-Next v3.3.0 (spoofed manager APK +
     `android15-6.6_kernelsu.ko` + ksuinit)
   - EDL dumps the stock init_boot/vbmeta → **backed up at**
     `~/Library/Application Support/ltbox/backups/backup_init_boot`
   - magiskboot unpacks init_boot → cpio replaces init + stashes kernelsu.ko →
     repacks
   - **vbmeta rebuild**: stock public key `2597c218aae470a130f61162feaae70afd97f011`
     = **AOSP testkey_rsa4096** (confirms Lenovo signs AVB with the test key)
   - EDL flashes the patched init_boot_a + rebuilt vbmeta_a → root on first boot,
     **BL stays locked the whole time**

## How it works

Lenovo firmware uses the **AOSP public test key** for AVB signatures (the
"Lenovo testkey loophole"; polygraphene/LTBox are both built on it). LTBox
rebuilds vbmeta with the same testkey and writes the patched images over
**EDL (works on a locked device)** → root without unlocking the BL, and no
unlock warning at boot.

## Capabilities

- Root options: **KernelSU / KernelSU Next / SukiSU Ultra / ReSukiSU / APatch /
  FolkPatch / Magisk**
- Install mode: **LKM** (verified on newer firmware like 263; works on GKI 2.0
  devices generally)
- System Updates: **disable/restore OTA** (blocks forced upgrades to
  Android 16 1.5.x!)
- Advanced: EDL read/write of any partition, vbmeta rebuild, cross-partition
  conversion, rollback bypass
