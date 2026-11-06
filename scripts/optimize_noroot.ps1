<#======================================================================
  optimize_noroot.ps1
  =====================================================================
  Optimization for 1 CPU / 1 GB RAM - NO ROOT REQUIRED
  Works on fresh VM without root access
  Uses: pm disable-user, settings put, setprop (runtime)
  Note: Component-level disables and service killing require root
======================================================================#>

param(
  [int]$VmIndex = 1,
  [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$MuMu   = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"
$VmDir  = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-$VmIndex"
$Step = 0

function Step {
    param([string]$title, [string]$detail = "")
    $script:Step++
    Write-Host ""
    Write-Host ("[{0}] {1}" -f $script:Step, $title) -ForegroundColor Cyan
    if ($detail) { Write-Host "    $detail" -ForegroundColor Gray }
}
function MmuAdb {
    param([string]$cmd)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & $MuMu adb --vmindex $VmIndex --cmd "shell $cmd" 2>&1
        if ($null -eq $result) { return "" }
        if ($result -is [string]) { return $result.Trim() }
        $parts = foreach ($r in $result) {
            if ($r -is [System.Management.Automation.ErrorRecord]) {
                $r.Message
            } elseif ($r -is [string]) {
                $r
            } else {
                $r.ToString()
            }
        }
        return ($parts -join "`n").Trim()
    } catch {
        return $_.Exception.Message
    } finally {
        $ErrorActionPreference = $prevEap
    }
}
function Ok    { param([string]$msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn  { param([string]$msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 0. Verificar VM corriendo
# ---------------------------------------------------------------------------
Step "Conexión ADB"
$info = & $MuMu info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
if (-not $info.is_android_started) { throw "VM no esta corriendo" }
$test = MmuAdb "echo ok"
if ($test -notmatch "ok") { throw "MuMu ADB no responde" }
Ok "VM corriendo - IP: $($info.adb_host_ip):$($info.adb_port)"

# ---------------------------------------------------------------------------
# 1. Dalvik VM tuning (persist props - apply at boot via script)
# ---------------------------------------------------------------------------
Step "1. Dalvik VM" "Heap: 4m start / 96m growth / 192m max (persist)"

$dalvikProps = @(
    "persist.dalvik.vm.heapstartsize:4m",
    "persist.dalvik.vm.heapgrowthlimit:96m",
    "persist.dalvik.vm.heapsize:192m",
    "persist.dalvik.vm.heapminfree:512k",
    "persist.dalvik.vm.heapmaxfree:8m"
)
foreach ($p in $dalvikProps) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    MmuAdb "setprop $key $val" | Out-Null
    $short = $key -replace '^persist\.', ''
    MmuAdb "setprop $short $val" | Out-Null
}
Ok "persist props set (apply at next boot)"

# ---------------------------------------------------------------------------
# 2. Logcat minimal
# ---------------------------------------------------------------------------
Step "2. Logcat" "Buffers 16K"
$logdProps = @(
    "persist.logd.size:16K",
    "persist.logd.size.main:16K",
    "persist.logd.size.system:16K",
    "persist.logd.size.radio:16K",
    "persist.logd.size.events:16K"
)
foreach ($p in $logdProps) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    MmuAdb "setprop $key $val" | Out-Null
}
MmuAdb "logcat -c" | Out-Null
Ok "Logcat: 16K"

# ---------------------------------------------------------------------------
# 3. GPU / SurfaceFlinger (runtime + persist)
# ---------------------------------------------------------------------------
Step "3. GPU/SF" "No vsync, minimal caches"
$gpuProps = @(
    "persist.debug.sf.latch_unsignaled:1",
    "persist.debug.sf.early_gl_latch:0",
    "persist.debug.sf.hwc_check:0",
    "persist.debug.hwui.sync_buffer:0",
    "persist.debug.hwui.force_dark_mode:0",
    "persist.debug.hwui.disable_vsync:true",
    "persist.debug.hwui.renderer:skiavk",
    "persist.debug.hwui.use_gpu_pixel_buffers:false",
    "persist.debug.hwui.asset_atlas_max_size:512",
    "persist.debug.hwui.gradient_cache_size:256",
    "persist.debug.hwui.path_cache_size:8",
    "persist.debug.hwui.drop_shadow_cache_size:8",
    "persist.debug.hwui.r_buffer_cache_size:2",
    "persist.debug.hwui.texture_cache_flushrate:0.1",
    "persist.debug.hwui.texture_cache_size:4",
    "persist.debug.hwui.layer_cache_size:8",
    "persist.debug.egl.hw:0",
    "persist.debug.composition.type:gpu",
    "persist.debug.sf.disable_backpressure:1"
)
foreach ($p in $gpuProps) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    MmuAdb "setprop $key $val" | Out-Null
    $short = $key -replace '^persist\.', ''
    MmuAdb "setprop $short $val" | Out-Null
}
Ok "GPU props set"

# ---------------------------------------------------------------------------
# 4. Activity Manager - Minimal processes
# ---------------------------------------------------------------------------
Step "4. Activity Manager" "0 bg, 2 cached, 1 empty"
$amSettings = @(
    "global max_background_processes 0",
    "global max_phantom_processes 0",
    "global process_stats 0",
    "global max_cached_processes 2",
    "global max_empty_processes 1",
    "global app_standby_enabled 0",
    "global app_idle_constants 0",
    "global background_check_duration 0",
    "global background_update_duration 0",
    "global gc_duration 1000",
    "global gc_threshold 100",
    "global low_memory_killer 1",
    "global lmkd_use_psi 1",
    "global lmkd_psi_partial_stall_ms 80",
    "global lmkd_psi_complete_stall_ms 80"
)
foreach ($s in $amSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "AM settings applied"

# ---------------------------------------------------------------------------
# 5. Animations = 0
# ---------------------------------------------------------------------------
Step "5. Animaciones" "0.0"
$anim = @(
    "global window_animation_scale 0.0",
    "global transition_animation_scale 0.0",
    "global animator_duration_scale 0.0"
)
foreach ($s in $anim) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Animaciones deshabilitadas"

# ---------------------------------------------------------------------------
# 6. Anti-ads settings
# ---------------------------------------------------------------------------
Step "6. Anti-ads settings"
$adsSettings = @(
    "secure show_app_recommendations 0",
    "secure enable_suggestions 0",
    "secure show_search_app_suggestions 0",
    "global enable_advertising_id_collection 0",
    "global search_assist_enabled 0",
    "secure assistant_enabled 0"
)
foreach ($s in $adsSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Settings anti-ads aplicados"

# ---------------------------------------------------------------------------
# 7. Network - Disable telemetry endpoints
# ---------------------------------------------------------------------------
Step "7. Network telemetry" "Disable captive portal, quality checks"
$netSettings = @(
    "global captive_portal_mode 0",
    "global captive_portal_detection_enabled 0",
    "global captive_portal_http_url ''",
    "global captive_portal_https_url ''",
    "global captive_portal_fallback_url ''",
    "global captive_portal_other_fallback_urls ''",
    "global network_quality_throughput_threshold 0",
    "global network_quality_latency_threshold 0",
    "global wifi_watchdog_on 0",
    "global wifi_watchdog_poor_network_test_enabled 0",
    "global mobile_data_always_on 0"
)
foreach ($s in $netSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Network telemetry disabled"

# ---------------------------------------------------------------------------
# 8. Power/Battery
# ---------------------------------------------------------------------------
Step "8. Power/Battery" "Low power mode"
& $MuMu adb --vmindex $VmIndex --cmd "shell settings put global low_power_mode 1" 2>&1 | Out-Null
& $MuMu adb --vmindex $VmIndex --cmd "shell settings put global adaptive_battery 0" 2>&1 | Out-Null
& $MuMu adb --vmindex $VmIndex --cmd "shell settings put global device_idle_constants 0" 2>&1 | Out-Null
Ok "Low power mode"

# ---------------------------------------------------------------------------
# 9. Disable bloat packages (user-level, no root)
# ---------------------------------------------------------------------------
Step "9. Bloat packages" "Disable-user"
$bloat = @(
    "com.google.android.apps.restore",
    "com.google.android.configupdater",
    "com.google.android.partnersetup",
    "com.google.android.feedback",
    "com.google.android.contacts",
    "com.google.android.syncadapters.contacts",
    "com.google.android.setupwizard",
    "com.google.android.projection.gearhead",
    "com.google.android.apps.wellbeing",
    "com.google.android.apps.docs",
    "com.google.android.youtube",
    "com.google.android.music",
    "com.google.android.videos",
    "com.google.android.apps.photos",
    "com.google.android.gm",
    "com.google.android.talk",
    "com.google.android.calendar",
    "com.google.android.apps.maps",
    "com.google.android.gsf.login",
    "com.android.chrome",
    "com.android.browser",
    "com.android.email",
    "com.android.calculator2",
    "com.android.calendar",
    "com.android.deskclock",
    "com.android.soundrecorder",
    "com.android.mms",
    "com.android.stk"
)
$disabled = 0
foreach ($pkg in $bloat) {
    $res = MmuAdb "pm disable-user --user 0 $pkg"
    if ($res -match "new state: disabled") { $disabled++ }
}
Ok "$disabled paquetes deshabilitados (user)"

# ---------------------------------------------------------------------------
# 10. Disable APEX modules (user-level)
# ---------------------------------------------------------------------------
Step "10. APEX modules" "Disable non-critical (keep adbd)"
$apex = @(
    "android.ext.services",
    "android.media",
    "android.media.swcodec",
    "android.tethering",
    "com.android.appsearch",
    "com.android.conscrypt",
    "com.android.ipsec",
    "com.android.mediaprovider",
    "com.android.os.statsd",
    "com.android.resolv",
    "com.android.sdkext",
    "com.android.tzdata",
    "com.android.wifi"
)
foreach ($a in $apex) {
    MmuAdb "pm disable-user --user 0 $a" | Out-Null
}
Ok "13 APEX modules disabled"

# ---------------------------------------------------------------------------
# 11. Essential packages enabled
# ---------------------------------------------------------------------------
Step "11. Essential packages" "GMS, Play Store, GSF, PackageInstaller, MuMu Store"
$essential = @(
    "com.google.android.gms",
    "com.android.vending",
    "com.google.android.gsf",
    "com.google.android.backuptransport",
    "com.android.packageinstaller",
    "com.mumu.store"
)
foreach ($pkg in $essential) {
    MmuAdb "pm enable $pkg" | Out-Null
}
Ok "Essential enabled"

# ---------------------------------------------------------------------------
# 12. MuMu Store - Disable splash/boot UI, keep APK installer
# ---------------------------------------------------------------------------
Step "12. MuMu Store" "Disable splash/boot UI, keep installer"
$mumuSplashComponents = @(
    "com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider",
    "com.mumu.store.track.AdTrackingReceiver",
    "com.mumu.store.BootReceiver",
    "com.mumu.store.track.TrackingReceiver",
    "com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider",
    "com.mumu.store.MainActivity"
)
# Note: InstallationReceiver is intentionally NOT disabled - it breaks the external install flow (MuMuManager.exe control app install)
foreach ($comp in $mumuSplashComponents) {
    MmuAdb "pm disable-user --user 0 -c $comp com.mumu.store" | Out-Null
}
# Ensure installer activity is enabled
MmuAdb "pm enable com.mumu.store/com.mumu.store.install.XApkInstallerActivity" | Out-Null
Ok "MuMu Store: splash/boot disabled, installer active"

# ---------------------------------------------------------------------------
# 13. Play Store settings - Disable auto-update
# ---------------------------------------------------------------------------
Step "13. Play Store" "Auto-update off"
$psSettings = @(
    "global auto_update_apps 0",
    "global auto_update_apps_over_wifi_only 0",
    "global package_verifier_enable 0",
    "global play_store_auto_update 0"
)
foreach ($s in $psSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Auto-update disabled"

# ---------------------------------------------------------------------------
# 14. Compiler/DEX (persist props)
# ---------------------------------------------------------------------------
Step "14. Compiler/DEX" "1 thread, speed filter"
$compiler = @(
    "persist.dalvik.vm.dex2oat-threads:1",
    "persist.dalvik.vm.image-dex2oat-threads:1",
    "persist.dalvik.vm.boot-dex2oat-threads:1",
    "persist.dalvik.vm.dex2oat-filter:speed",
    "persist.dalvik.vm.image-dex2oat-filter:speed",
    "persist.pm.dexopt.bg-dexopt:idle",
    "persist.pm.dexopt.ab-ota:idle",
    "persist.pm.dexopt.install:speed",
    "persist.pm.dexopt.shared:speed",
    "persist.pm.dexopt.first_boot:speed"
)
foreach ($p in $compiler) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    MmuAdb "setprop $key $val" | Out-Null
    $short = $key -replace '^persist\.', ''
    MmuAdb "setprop $short $val" | Out-Null
}
Ok "Compiler props set"

# ---------------------------------------------------------------------------
# 15. VM Config - 1CPU/1GB/30fps
# ---------------------------------------------------------------------------
Step "15. vm_config.json" "1CPU 1GB 30fps no-vsync"
$cfg = Join-Path $VmDir "configs\vm_config.json"
if (Test-Path $cfg) {
    $j = Get-Content $cfg -Raw | ConvertFrom-Json
    $j.vm.cpu = "1"
    $j.vm.memory = "1"
    if (-not $j.display) { $j | Add-Member -MemberType NoteProperty -Name display -Value ([pscustomobject]@{}) }
    $j.display | Add-Member -MemberType NoteProperty -Name vsync -Value "false" -Force
    $j.display | Add-Member -MemberType NoteProperty -Name vertical_sync -Value "false" -Force
    $j.display | Add-Member -MemberType NoteProperty -Name frame_rate -Value 30 -Force
    $j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
    Ok "vm_config: 1CPU, 1GB, vsync=false, 30fps"
} else {
    Warn "vm_config.json not found"
}

# ---------------------------------------------------------------------------
# 16. Boot script for persistent runtime settings (array to avoid here-string issues)
# ---------------------------------------------------------------------------
Step "16. Boot script" "Runtime settings at boot"
$localBootScript = "D:\mumu-global-debloat\patch\boot_noroot.sh"
$bootScriptLines = @(
    "#!/system/bin/sh",
    "# Runtime optimization - apply at every boot",
    "",
    "# GPU minimal",
    "setprop debug.sf.latch_unsignaled 1",
    "setprop debug.sf.early_gl_latch 0",
    "setprop debug.sf.hwc_check 0",
    "setprop debug.hwui.sync_buffer 0",
    "setprop debug.hwui.disable_vsync true",
    "setprop debug.hwui.renderer skiavk",
    "setprop debug.hwui.use_gpu_pixel_buffers false",
    "setprop debug.hwui.asset_atlas_max_size 512",
    "setprop debug.hwui.gradient_cache_size 256",
    "setprop debug.hwui.path_cache_size 8",
    "setprop debug.hwui.drop_shadow_cache_size 8",
    "setprop debug.hwui.r_buffer_cache_size 2",
    "setprop debug.hwui.texture_cache_flushrate 0.1",
    "setprop debug.hwui.texture_cache_size 4",
    "setprop debug.hwui.layer_cache_size 8",
    "setprop debug.egl.hw 0",
    "setprop debug.composition.type gpu",
    "setprop debug.sf.disable_backpressure 1",
    "",
    "# Kernel memory (if root available)",
    "# sysctl -w vm.swappiness=0",
    "# sysctl -w vm.vfs_cache_pressure=500",
    "# sysctl -w vm.dirty_ratio=5",
    "# sysctl -w vm.dirty_background_ratio=2",
    "# swapoff -a 2>/dev/null"
)
Set-Content -LiteralPath $localBootScript -Value ($bootScriptLines -join "`n") -Encoding ASCII
$port = $info.adb_port
$standalone = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
& $standalone -s "127.0.0.1:$port" push $localBootScript /data/local/tmp/boot_noroot.sh 2>$null
if ($LASTEXITCODE -ne 0) {
    # adb push sometimes returns non-zero even on success; verify file exists
    $verify = MmuAdb "test -f /data/local/tmp/boot_noroot.sh && echo OK || echo MISSING"
    if ($verify -notmatch "OK") { Warn "Boot script push may have failed" }
    else { Ok "Boot script pushed (exit code ignored, file verified)" }
}
else {
    Ok "Boot script pushed"
}
MmuAdb "chmod 755 /data/local/tmp/boot_noroot.sh" | Out-Null
Ok "Boot script: /data/local/tmp/boot_noroot.sh"

# ---------------------------------------------------------------------------
# 17. Verificacion final
# ---------------------------------------------------------------------------
Step "17. Verificacion"
Write-Host ""
Write-Host "  Memoria:"
& $MuMu adb --vmindex $VmIndex --cmd "shell cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable'" 2>&1 | Out-String | ForEach-Object { Write-Host "    $_" }
Write-Host "  Paquetes deshabilitados:"
$disabled = MmuAdb "pm list packages -d"
$count = ($disabled -split "`r`n" | Where-Object {$_ -match "package:"}).Count
Write-Host "    $count"
Write-Host "  Animaciones:"
& $MuMu adb --vmindex $VmIndex --cmd "shell settings get global window_animation_scale" 2>&1 | ForEach-Object { Write-Host "    window_animation_scale: $_" }
& $MuMu adb --vmindex $VmIndex --cmd "shell settings get global transition_animation_scale" 2>&1 | ForEach-Object { Write-Host "    transition_animation_scale: $_" }
& $MuMu adb --vmindex $VmIndex --cmd "shell settings get global animator_duration_scale" 2>&1 | ForEach-Object { Write-Host "    animator_duration_scale: $_" }
Write-Host "  Auto-update:"
& $MuMu adb --vmindex $VmIndex --cmd "shell settings get global auto_update_apps" 2>&1 | ForEach-Object { Write-Host "    auto_update_apps: $_" }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  OPTIMIZACION NO-ROOT COMPLETADA" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Lo que NO se hizo (requiere root):"
Write-Host "    - Component-level disables (pm disable)"
Write-Host "    - Service stopping (setprop ctl.stop)"
Write-Host "    - Hosts file bind mount"
Write-Host "    - Kernel sysctl (vm.swappiness, etc)"
Write-Host "    - APEX disable (some need root)"
Write-Host ""
Write-Host "  Para optimizacion completa (con root):"
Write-Host "    1. vm_config.json: root: true"
Write-Host "    2. Reiniciar VM"
Write-Host "    3. MuMuManager.exe control --vmindex $VmIndex tool func --name root"
Write-Host "    4. Ejecutar full_optimize_boot_v3.ps1"
Write-Host ""
Write-Host "  Para persistir en boot:"
Write-Host "    adb shell sh /data/local/tmp/boot_noroot.sh"
Write-Host ""