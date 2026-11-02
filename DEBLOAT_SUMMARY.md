# MuMu Player Global 12.0 - Debloat & Optimization Complete

## Summary
**Date:** 2026-11-01  
**VM Reference:** Index 1 (root enabled, hardware: 1 CPU / 1 GB)  
**Launch Time:** ~125s (cold boot, low profile)

---

## ✅ Completed Optimizations

### 1. Hardware Profile
- `performance_mode = low`
- `gpu_mode = low`
- `app_keptlive = false`

### 2. Package-Level Disables (persist in data.vdi via `pm disable-user --user 0`)
| Package | Reason |
|---------|--------|
| com.mumu.store | MuMu Store (ads, APK handler hijack) |
| com.google.android.apps.restore | Backup restore (not needed) |
| com.google.android.configupdater | Config updater |
| com.google.android.syncadapters.contacts | Contacts sync |
| com.google.android.contacts | Contacts app |
| com.google.android.feedback | Feedback |
| app.revanced.android.gms | Revanced GMS |
| ch.protonvpn.android | ProtonVPN |
| com.cxinventor.file.explorer | File explorer |
| mu.origin.ro.ggplay.qjmu | Game overlay |
| v8.ragezone.hhdev | Game overlay |
| com.hwsj.club | Unknown |
| com.yablio.sendfilestotv | File transfer |
| com.ltv | Unknown |
| com.esaba.downloader | Downloader |
| com.qmqj.tianmashikong.mi | Unknown |

### 3. Critical Google Packages RE-ENABLED
- `com.google.android.gms` (GMS)
- `com.android.vending` (Play Store)
- `com.google.android.gsf` (Google Services Framework)
- `com.google.android.backuptransport` (Backup)
- `com.google.android.partnersetup` (Partner Setup)

### 4. Component-Level Disables (requires root, `pm disable`)
| Component | Reason |
|-----------|--------|
| com.mumu.store/.widget.appWidgetProvider.AdBannerWidgetProvider | Ad banner |
| com.mumu.store/.widget.appWidgetProvider.DailyDiscoveryWidgetProvider | Discovery widget |
| com.mumu.store/.track.AdTrackingReceiver | Ad tracking |
| com.mumu.store/.track.TrackingReceiver | Tracking |
| com.mumu.store/.BootReceiver | Boot receiver |
| com.mumu.store/.InstallationReceiver | Installation receiver |
| com.mumu.store/.install.XApkInstallerActivity | **APK handler hijack (FIXED)** |
| com.android.vending/.searchsuggestions.RecentSuggestionsProvider | Play Store suggestions |
| com.google.android.gms/.ads.identifier.service.AdvertisingIdService | GAID |
| com.google.android.gms/.ads.identifier.service.AdvertisingIdNotificationService | GAID notifications |

### 5. Global Settings (`settings put`)
| Setting | Value | Scope |
|---------|-------|-------|
| show_app_recommendations | 0 | secure |
| enable_suggestions | 0 | secure |
| enable_advertising_id_collection | 0 | global |
| show_search_app_suggestions | 0 | secure |
| window_animation_scale | 0.0 | global |
| transition_animation_scale | 0.0 | global |
| animator_duration_scale | 0.0 | global |

### 6. Vendor Services Stopped & Disabled
- vendor.bluetooth-1-1
- vendor.gnss-2-0
- vendor.sensors-hal-2-1-multihal
- vendor.vibrator-1-3
- vendor.camera-provider-2-4
- vendor.power.stats-hal-1-0-mock
- vendor.ril-daemon

### 7. Hosts File (217 domains blocked)
- **Google auth endpoints UNBLOCKED:** `clients2.google.com`, `clients4.google.com` ✅
- **Blocked:** MuMu/NetEase telemetry, Google Ads, DoubleClick, Unity Ads, AppLovin, IronSource, Facebook Ads, AppsFlyer, Adjust, Branch, Crashlytics, Mixpanel, Amplitude, TikTok, Umeng, etc.

### 8. APK Double-Click Handler FIX
- **Problem:** `com.mumu.store/.install.XApkInstallerActivity` intercepted `application/vnd.android.package-archive` intents
- **Fix:** 
  1. `pm enable --user 0 com.android.packageinstaller`
  2. `pm disable com.mumu.store/com.mumu.store.install.XApkInstallerActivity`
- **Result:** PackageInstaller is now the ONLY handler for .apk files

---

## 🔄 Merge & Swap Base Workflow

### Current State
- Base system.vdi restored to original (MD5: `f576f17aa8b8636b5a2420b6582a187a`)
- ota.vdi (diff) back on VM 1
- All changes live in data.vdi + ota.vdi

### To Persist Changes in Base (for ALL new VMs):

```powershell
# 1. Stop VM completely
MuMuManager.exe main kill

# 2. Merge diff into base
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\merge_diff.ps1 `
  -Base "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi" `
  -Diff "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-1\ota.vdi" `
  -Out "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"

# 3. Swap base (backs up original, disables diff)
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\swap_base.ps1 `
  -Merged "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"
```

**Expected merged base MD5:** `7c4270b310b4eab8b2aa0db40e2100a0`

---

## 📁 Backup Location
`D:\MuMuPlayerGlobal-12.0\backup_debloat\vm1_final_20261101_183435\`
- data.vdi
- hosts_fixed.txt
- system.merged.vdi (fused base)
- Scripts

---

## 🔧 Reapply Script for New VMs
`D:\mumu-global-debloat\scripts\reapply_final.ps1`

```powershell
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\reapply_final.ps1 -VmIndex 1 -Serial "127.0.0.1:XXXX"
```

---

## ✅ Verification Checklist
- [x] Launch time ~125s (vs 257s baseline)
- [x] Play Store login works
- [x] No ads/suggestions in Play Store or MuMu Store
- [x] APK double-click opens PackageInstaller (not MuMu Store)
- [x] Hosts file blocks 217 ad/tracking domains
- [x] Google auth endpoints accessible (clients2/clients4)
- [x] GMS, Play Store, GSF enabled
- [x] All bloat packages disabled
- [x] Root persists across reboots (via su binary in system)
- [x] Settings anti-suggestions applied

---

## 📝 Notes for Future
1. The merged base MD5 (`7c4270b310b4eab8b2aa0db40e2100a0`) differs from the original script's expected MD5 - this is expected because the base has been updated.
2. swap_base.ps1 now handles both `system-diff.vdi` and `ota.vdi` naming.
3. All changes are idempotent - reapply_final.ps1 can run multiple times safely.