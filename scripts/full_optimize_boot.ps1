<#======================================================================
  full_optimize_boot.ps1
  =====================================================================
  Script TODO-EN-UNO para optimizar el boot de MuMu Player Global 12.0
  Aplica TODAS las optimizaciones seguras:
    1. Dalvik VM tuning (persiste)
    2. Logcat minimo (persiste)
    3. GPU/SurfaceFlinger tuning
    4. Stop servicios mock (BT, camera, GNSS, sensors, vibrator, WiFi)
    5. Stop zygote_secondary (32-bit)
    6. Stop media scanner/extractor
    7. APEX modules disable
    8. Bloatware/packages disable
    9. APK handler fix (PackageInstaller)
    10. Settings anti-ads/anti-suggestions
    11. Animaciones=0
    12. Hosts anti-ads
    13. Script de boot persistente (/data/local/tmp/boot_opt.sh)
    14. vm_config.json (vsync off, frame_rate 30)

  Uso:
    powershell -ExecutionPolicy Bypass -File full_optimize_boot.ps1 -VmIndex 1
======================================================================#>

param(
  [int]$VmIndex = 1,
  [string]$Serial = "",
  [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$AdbExe = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$MuMu   = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"
$VmDir  = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-$VmIndex"
$HostsFile = "D:\mumu-global-debloat\patch\hosts_fixed.txt"
$Step = 0

function Step {
    param([string]$title, [string]$detail = "")
    $script:Step++
    Write-Host ""
    Write-Host ("[{0}] {1}" -f $script:Step, $title) -ForegroundColor Cyan
    if ($detail) { Write-Host "    $detail" -ForegroundColor Gray }
}

function Adb   { param([string]$cmd) & $AdbExe -s $Script:Serial shell $cmd 2>&1 | Out-String }
function AdbSu { param([string]$cmd) & $AdbExe -s $Script:Serial shell "/system/xbin/su -c '$cmd'" 2>&1 | Out-String }
function Ok    { param([string]$msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn  { param([string]$msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 0. Conectar ADB
# ---------------------------------------------------------------------------
Step "Conexión ADB"

if (-not $Serial) {
    $info = & $MuMu info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
    if (-not $info -or -not $info.is_android_started) {
        Write-Host "    VM no esta corriendo. Lanzando..." -ForegroundColor Yellow
        & $MuMu main launch | Out-Null
        Start-Sleep 5
        & $MuMu control --vmindex $VmIndex launch | Out-Null
        $maxWait = 300
        $elapsed = 0
        while ($elapsed -lt $maxWait) {
            Start-Sleep 5
            $elapsed += 5
            $info = & $MuMu info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
            if ($info.is_android_started -and $info.player_state -eq "start_finished") { break }
        }
        if (-not $info.is_android_started) { throw "VM no arranco en $maxWait s" }
    }
    # Si la IP no es 127.0.0.1, forzar 127.0.0.1 (MuMu a veces reporta IP LAN)
    $adbIp = $info.adb_host_ip
    if ($adbIp -ne "127.0.0.1" -and $adbIp -ne "0.0.0.0") { $adbIp = "127.0.0.1" }
    $Serial = $adbIp + ":" + $info.adb_port
    Write-Host "    ADB: $Serial (reportado: $($info.adb_host_ip))"
}
$Script:Serial = $Serial

& $AdbExe connect $Serial 2>&1 | Out-Null
Start-Sleep 3

$test = Adb "echo ok"
if ($test -notmatch "ok") {
    $port = ($Script:Serial -split ':')[1]
    $alt = "127.0.0.1:$port"
    & $AdbExe connect $alt 2>&1 | Out-Null
    Start-Sleep 3
    $test = Adb "echo ok"
    if ($test -match "ok") { $Script:Serial = $alt }
}
if ($test -notmatch "ok") { throw "No se puede conectar ADB a $Serial" }
Ok "ADB conectado: $Script:Serial"

# ---------------------------------------------------------------------------
# 1. Dalvik VM tuning
# ---------------------------------------------------------------------------
Step "1. Dalvik VM tuning" "Heap reducido para 1GB RAM"

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
    AdbSu "setprop $key $val" | Out-Null
    $short = $key -replace '^persist\.', ''
    AdbSu "setprop $short $val" | Out-Null
}
Ok "heap: 4m start / 96m growth / 192m max"

# ---------------------------------------------------------------------------
# 2. Logcat minimo
# ---------------------------------------------------------------------------
Step "2. Logcat minimo" "Buffers reducidos a 64K"

$logdProps = @(
    "persist.logd.size:64K",
    "persist.logd.size.main:64K",
    "persist.logd.size.system:64K",
    "persist.logd.size.radio:64K",
    "persist.logd.size.events:64K"
)
foreach ($p in $logdProps) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    AdbSu "setprop $key $val" | Out-Null
}
Adb "logcat -c" | Out-Null
Ok "Buffers: 64K"

# ---------------------------------------------------------------------------
# 3. GPU / SurfaceFlinger
# ---------------------------------------------------------------------------
Step "3. GPU / SurfaceFlinger"

$gpuProps = @(
    "debug.sf.latch_unsignaled:1",
    "debug.sf.early_gl_latch:0",
    "debug.sf.hwc_check:0",
    "debug.hwui.sync_buffer:0",
    "debug.hwui.force_dark_mode:0"
)
foreach ($p in $gpuProps) {
    $key = $p -split ':' | Select-Object -First 1
    $val = $p -split ':' | Select-Object -Last 1
    AdbSu "setprop $key $val" | Out-Null
}
Ok "latch_unsignaled=1, early_gl_latch=0, hwc_check=0"

# ---------------------------------------------------------------------------
# 4. Stop servicios hardware mock
# ---------------------------------------------------------------------------
Step "4. Stop hardware mocks" "BT, camera, GNSS, sensors, vibrator, WiFi"

$hardwareMocks = @(
    "vendor.bluetooth-1-1",
    "vendor.camera-provider-2-4",
    "vendor.gnss-2-0",
    "vendor.sensors-hal-2-1-multihal",
    "vendor.vibrator-1-3",
    "vendor.wifi_hal_legacy",
    "vendor.ril-daemon",
    "vendor.gatekeeper-1-0",
    "vendor.power.stats-hal-1-0-mock",
    "cameraserver",
    "wificond",
    "mediaextractor",
    "mediametrics",
    "media.swcodec",
    "traced",
    "traced_probes",
    "tombstoned",
    "statsd",
    "gatekeeperd",
    "thermal-engine"
)

$stopped = 0
foreach ($svc in $hardwareMocks) {
    $state = (Adb "getprop init.svc.$svc").Trim()
    if ($state -eq "running" -or $state -eq "restarting") {
        AdbSu "setprop ctl.stop $svc" | Out-Null
        $stopped++
    }
}
Ok "$stopped servicios parados"

# ---------------------------------------------------------------------------
# 5. Stop zygote_secondary
# ---------------------------------------------------------------------------
Step "5. Stop zygote_secondary" "Libera memoria y boot 32-bit"

$zygoteState = (Adb "getprop init.svc.zygote_secondary").Trim()
if ($zygoteState -eq "running") {
    AdbSu "setprop ctl.stop zygote_secondary" | Out-Null
    Start-Sleep 2
    $newState = (Adb "getprop init.svc.zygote_secondary").Trim()
    if ($newState -eq "stopped") {
        Ok "zygote_secondary detenido"
    } else {
        Warn "zygote_secondary sigue $newState"
    }
} else {
    Ok "zygote_secondary ya detenido ($zygoteState)"
}

# ---------------------------------------------------------------------------
# 6. APEX modules
# ---------------------------------------------------------------------------
Step "6. APEX modules"

$apexOff = @(
    "android.ext.services"
)
foreach ($a in $apexOff) {
    AdbSu "pm disable-user --user 0 $a" | Out-Null
}
Ok "APEX no esenciales deshabilitados"

# ---------------------------------------------------------------------------
# 7. Bloatware
# ---------------------------------------------------------------------------
Step "7. Bloatware" "Deshabilitar paquetes"

$disablePkgs = @(
    "com.mumu.store",
    "com.google.android.apps.restore",
    "com.google.android.configupdater",
    "com.google.android.partnersetup",
    "com.google.android.feedback",
    "com.google.android.contacts",
    "com.google.android.syncadapters.contacts",
    "app.revanced.android.gms",
    "ch.protonvpn.android",
    "com.cxinventor.file.explorer",
    "mu.origin.ro.ggplay.qjmu",
    "v8.ragezone.hhdev",
    "com.hwsj.club",
    "com.yablio.sendfilestotv",
    "com.ltv",
    "com.esaba.downloader",
    "com.qmqj.tianmashikong.mi"
)
$disabled = 0
foreach ($pkg in $disablePkgs) {
    $res = Adb "pm disable-user --user 0 $pkg"
    if ($res -match "new state: disabled") { $disabled++ }
}
Ok "$disabled paquetes deshabilitados"

# ---------------------------------------------------------------------------
# 8. Componentes de anuncios
# ---------------------------------------------------------------------------
Step "8. Componentes de anuncios" "Ad tracking + XApkInstaller"

$adComponents = @(
    "com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider",
    "com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider",
    "com.mumu.store/com.mumu.store.track.AdTrackingReceiver",
    "com.mumu.store/com.mumu.store.track.TrackingReceiver",
    "com.mumu.store/com.mumu.store.BootReceiver",
    "com.mumu.store/com.mumu.store.InstallationReceiver",
    "com.mumu.store/com.mumu.store.install.XApkInstallerActivity",
    "com.android.vending/com.google.android.finsky.searchsuggestions.RecentSuggestionsProvider",
    "com.google.android.gms/.ads.identifier.service.AdvertisingIdService",
    "com.google.android.gms/.ads.identifier.service.AdvertisingIdNotificationService",
    "app.lawnchair/app.lawnchair.smartspace.SmartspaceAppWidgetProvider"
)
$compDisabled = 0
foreach ($comp in $adComponents) {
    $res = AdbSu "pm disable $comp"
    if ($res -match "new state: disabled") { $compDisabled++ }
}
Ok "$compDisabled componentes deshabilitados"

# ---------------------------------------------------------------------------
# 9. APK handler fix
# ---------------------------------------------------------------------------
Step "9. APK Handler" "PackageInstaller por defecto"

Adb "pm enable --user 0 com.android.packageinstaller" | Out-Null
Ok "PackageInstaller habilitado"

# ---------------------------------------------------------------------------
# 10. Google paquetes criticos
# ---------------------------------------------------------------------------
Step "10. Google criticos" "GMS, Play Store, GSF"

$googlePkg = @(
    "com.google.android.gms",
    "com.android.vending",
    "com.google.android.gsf",
    "com.google.android.backuptransport"
)
foreach ($pkg in $googlePkg) {
    Adb "pm enable $pkg" | Out-Null
}
Ok "GMS, Play Store, GSF habilitados"

# ---------------------------------------------------------------------------
# 11. Settings anti-ads
# ---------------------------------------------------------------------------
Step "11. Settings anti-ads"

$settings = @(
    "secure show_app_recommendations 0",
    "secure enable_suggestions 0",
    "secure show_search_app_suggestions 0",
    "global enable_advertising_id_collection 0",
    "global search_assist_enabled 0",
    "secure assistant_enabled 0"
)
foreach ($s in $settings) {
    Adb "settings put $s" | Out-Null
}
Ok "Settings aplicados"

# ---------------------------------------------------------------------------
# 12. Animaciones = 0
# ---------------------------------------------------------------------------
Step "12. Animaciones"

$animSettings = @(
    "global window_animation_scale 0.0",
    "global transition_animation_scale 0.0",
    "global animator_duration_scale 0.0"
)
foreach ($s in $animSettings) {
    Adb "settings put $s" | Out-Null
}
Ok "Animaciones deshabilitadas"

# ---------------------------------------------------------------------------
# 13. Hosts anti-ads
# ---------------------------------------------------------------------------
Step "13. Hosts anti-ads" "217 dominios"

if (Test-Path $HostsFile) {
    & $AdbExe -s $Script:Serial push $HostsFile /data/local/tmp/hosts.antiad 2>&1 | Out-Null
    AdbSu "mount -o rw,remount /system" | Out-Null
    AdbSu "cp /data/local/tmp/hosts.antiad /system/etc/hosts && chmod 644 /system/etc/hosts" | Out-Null
    AdbSu "mount -o ro,remount /system" | Out-Null
    Ok "Hosts actualizado"
} else {
    Warn "Hosts file no encontrado: $HostsFile"
}

# ---------------------------------------------------------------------------
# 14. Boot script persistente
# ---------------------------------------------------------------------------
Step "14. Script de boot" "Auto-apply en cada arranque"

$bootScript = @'
#!/system/bin/sh
# Boot optimization - run at every boot
for svc in vendor.bluetooth-1-1 vendor.camera-provider-2-4 vendor.gnss-2-0 vendor.sensors-hal-2-1-multihal vendor.vibrator-1-3 vendor.wifi_hal_legacy vendor.ril-daemon vendor.gatekeeper-1-0 vendor.power.stats-hal-1-0-mock cameraserver wificond mediaextractor mediametrics media.swcodec traced traced_probes tombstoned statsd gatekeeperd thermal-engine zygote_secondary; do
    setprop ctl.stop "$svc" 2>/dev/null
done
setprop debug.sf.latch_unsignaled 1
setprop debug.sf.early_gl_latch 0
setprop debug.sf.hwc_check 0
setprop debug.hwui.sync_buffer 0
setprop debug.hwui.force_dark_mode 0
'@

$localBootScript = "D:\mumu-global-debloat\patch\boot_opt.sh"
Set-Content -LiteralPath $localBootScript -Value $bootScript -Encoding ASCII
& $AdbExe -s $Script:Serial push $localBootScript /data/local/tmp/boot_opt.sh 2>&1 | Out-Null
AdbSu "chmod 755 /data/local/tmp/boot_opt.sh" | Out-Null
Ok "Script en /data/local/tmp/boot_opt.sh"

# ---------------------------------------------------------------------------
# 15. vm_config.json
# ---------------------------------------------------------------------------
Step "15. vm_config.json" "vsync off, frame_rate 30"

$cfg = Join-Path $VmDir "configs\vm_config.json"
if (Test-Path $cfg) {
    $j = Get-Content $cfg -Raw | ConvertFrom-Json
    if (-not $j.display) { $j | Add-Member -MemberType NoteProperty -Name display -Value ([pscustomobject]@{}) }
    $j.display | Add-Member -MemberType NoteProperty -Name vsync -Value "false" -Force
    $j.display | Add-Member -MemberType NoteProperty -Name vertical_sync -Value "false" -Force
    $j.display | Add-Member -MemberType NoteProperty -Name frame_rate -Value 30 -Force
    $j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
    Ok "vsync=false, frame_rate=30"
} else {
    Warn "vm_config.json no encontrado en $cfg"
}

# ---------------------------------------------------------------------------
# 16. Verificacion final
# ---------------------------------------------------------------------------
Step "16. Verificacion final"

Write-Host ""
$bootCompleted = (Adb "getprop sys.boot_completed").Trim()
$zygoteState   = (Adb "getprop init.svc.zygote_secondary").Trim()
$heapStart     = (Adb "getprop dalvik.vm.heapstartsize").Trim()
$heapGrowth    = (Adb "getprop dalvik.vm.heapgrowthlimit").Trim()
$logdSize      = (Adb "getprop persist.logd.size").Trim()
$latch         = (Adb "getprop debug.sf.latch_unsignaled").Trim()

Write-Host "  sys.boot_completed    : $bootCompleted"
Write-Host "  zygote_secondary      : $zygoteState"
Write-Host "  heapstartsize         : $heapStart"
Write-Host "  heapgrowthlimit       : $heapGrowth"
Write-Host "  logd.size             : $logdSize"
Write-Host "  latch_unsignaled      : $latch"

$disabled = (Adb "pm list packages -d").Trim()
$disabledCount = ($disabled -split "`n" | Where-Object {$_ -match "package:"}).Count
Write-Host "  Paquetes deshabilitados: $disabledCount"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  OPTIMIZACION COMPLETADA" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Para aplicar en cada boot (servicios que no persisten):"
Write-Host "    adb shell su -c 'sh /data/local/tmp/boot_opt.sh'"
Write-Host ""
Write-Host "  Para persistir en base (todas las VMs nuevas):"
Write-Host "    1. MuMuManager.exe main kill"
Write-Host "    2. merge_diff.ps1 -Base ... -Diff ota.vdi -Out merged.vdi"
Write-Host "    3. swap_base.ps1 -Merged merged.vdi"
Write-Host ""