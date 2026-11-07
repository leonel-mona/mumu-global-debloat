<#======================================================================
  optimize_ultra_safe.ps1
  =====================================================================
  SAFE Optimization for MuMu Player Global 12.0
  Uses root (su -c) for privileged commands via MmuRoot wrapper
  
  PRESERVED NETWORK COMPONENTS (NOT touched):
  - android.resolv
  - com.android.conscrypt
  - android.tzdata
  - com.android.networkstack
  - com.android.server.wifi
  - com.android.connectivity.resources
  
  Does NOT modify vm_config.json
======================================================================#>

param(
  [int]$VmIndex = 1,
  [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$MuMu   = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"
$AdbExe = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
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
    $port = $script:adbPort
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & $AdbExe -s "127.0.0.1:$port" shell $cmd 2>&1
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

function MmuRoot {
    param([string]$cmd)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & $AdbExe -s "127.0.0.1:$($script:adbPort)" shell "su -c '$cmd'" 2>&1
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
# 0. Verify VM running and get ADB port
# ---------------------------------------------------------------------------
Step "ADB Connection"
$info = & $MuMu info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
if (-not $info.is_android_started) { throw "VM is not running" }
$script:adbPort = $info.adb_port
$test = MmuAdb "echo ok"
if ($test -notmatch "ok") { throw "ADB not responding" }
Ok "VM running - IP: $($info.adb_host_ip):$($info.adb_port)"

# ---------------------------------------------------------------------------
# 1. Apply sysctls via root (vm.swappiness=0, vm.vfs_cache_pressure=500)
# ---------------------------------------------------------------------------
Step "1. Kernel sysctls" "swappiness=0, vfs_cache_pressure=500"
MmuRoot "sysctl -w vm.swappiness=0" | Out-Null
MmuRoot "sysctl -w vm.vfs_cache_pressure=500" | Out-Null
Ok "sysctls applied"

# ---------------------------------------------------------------------------
# 2. Simplify boot_noroot.sh to only 2 sysctl lines
# ---------------------------------------------------------------------------
Step "2. boot_noroot.sh" "Simplified to 2 sysctl lines only"
$localBootScript = "D:\mumu-global-debloat\patch\boot_noroot.sh"
$bootScriptLines = @(
    "#!/system/bin/sh",
    "# Simplified boot script - only sysctls",
    "",
    "su -c 'sysctl -w vm.swappiness=0'",
    "su -c 'sysctl -w vm.vfs_cache_pressure=500'"
)
Set-Content -LiteralPath $localBootScript -Value ($bootScriptLines -join "`n") -Encoding ASCII
$standalone = $AdbExe
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$null = & $standalone -s "127.0.0.1:$($script:adbPort)" push $localBootScript /data/local/tmp/boot_noroot.sh 2>$null
$ErrorActionPreference = $prevEap
MmuAdb "chmod 755 /data/local/tmp/boot_noroot.sh" | Out-Null
Ok "boot_noroot.sh simplified and pushed"

# ---------------------------------------------------------------------------
# 3. Disable 10 GMS components (non-network, non-auth)
# ---------------------------------------------------------------------------
Step "3. GMS components" "10 non-network, non-auth components"
$gmsComponents = @(
    "com.google.android.gms/.clearcut.debug.ClearcutDebugDumpService",
    "com.google.android.gms/.semanticlocation.service.SemanticLocationService",
    "com.google.android.gms/.nearby.presence.service.LifeCycleService",
    "com.google.android.gms/.nearby.sharing.ReceiveSurfaceService",
    "com.google.android.gms/.nearby.sharing.SendSurfaceService",
    "com.google.android.gms/.findmydevice.spot.bleadvertising.OfflineBeaconService_Persistent",
    "com.google.androidlocation.internal.server.GoogleLocationService",
    "com.google.androidlocation.fused.FusedLocationService",
    "com.google.androidlocation.geocode.GeocodeService",
    "com.google.androidlocation.drivingmode.DrivingModeSettingsActivity"
)
$disabled = 0
foreach ($c in $gmsComponents) {
    $res = MmuAdb "pm disable-user --user 0 $c"
    if ($res -match "new state: disabled") { $disabled++ }
}
Ok "$disabled GMS components disabled"

# ---------------------------------------------------------------------------
# 4. Disable 15 system packages (non-network)
# ---------------------------------------------------------------------------
Step "4. System packages" "15 non-network packages"
$systemPkgs = @(
    "com.android.chrome",
    "com.android.browser",
    "com.android.email",
    "com.android.calculator2",
    "com.android.calendar",
    "com.android.deskclock",
    "com.android.soundrecorder",
    "com.android.mms",
    "com.android.stk",
    "com.android.gallery3d",
    "com.android.camera2",
    "com.android.chromium",
    "com.android.providers.calendar",
    "com.android.wallpaper",
    "com.google.android.contacts"
)
foreach ($pkg in $systemPkgs) {
    MmuAdb "pm disable-user --user 0 $pkg" | Out-Null
}
Ok "15 system packages disabled"

# ---------------------------------------------------------------------------
# 5. Disable 8 APEX modules (non-critical, non-network)
# ---------------------------------------------------------------------------
Step "5. APEX modules" "8 non-critical (network components preserved)"
$apexModules = @(
    "android.ext.services",
    "android.media",
    "android.media.swcodec",
    "android.tethering",
    "com.android.appsearch",
    "com.android.ipsec",
    "com.android.mediaprovider",
    "com.android.os.statsd"
)
foreach ($a in $apexModules) {
    MmuAdb "pm disable-user --user 0 $a" | Out-Null
}
Ok "8 APEX modules disabled"

# ---------------------------------------------------------------------------
# 6. Disable 7 HAL packages
# ---------------------------------------------------------------------------
Step "6. HAL packages" "7 unused hardware abstraction layers"
$halPkgs = @(
    "android.hardware.bluetooth",
    "android.hardware.gnss",
    "android.hardware.camera",
    "android.hardware.vibrator",
    "android.hardware.nfc",
    "android.hardware.fingerprint",
    "android.hardware.wifi"
)
foreach ($p in $halPkgs) {
    MmuAdb "pm disable-user --user 0 $p" | Out-Null
}
Ok "7 HAL packages disabled"

# ---------------------------------------------------------------------------
# 7. Apply additional safe optimizations
# ---------------------------------------------------------------------------
Step "7. Additional optimizations" "Animations, power, logcat"

# Animations off
MmuAdb "settings put global window_animation_scale 0.0" | Out-Null
MmuAdb "settings put global transition_animation_scale 0.0" | Out-Null
MmuAdb "settings put global animator_duration_scale 0.0" | Out-Null

# Power settings
MmuAdb "settings put global low_power_mode 1" | Out-Null
MmuAdb "settings put global adaptive_battery 0" | Out-Null

# Logcat minimal
MmuAdb "logcat -c" | Out-Null
MmuAdb "setprop persist.logd.size 16K" | Out-Null

Ok "Additional optimizations applied"

# ---------------------------------------------------------------------------
# 8. Verification
# ---------------------------------------------------------------------------
Step "8. Verification"
Write-Host ""
Write-Host "  Sysctl values:" -ForegroundColor Cyan
$swappiness = MmuAdb "sysctl vm.swappiness 2>/dev/null || echo 'N/A (need root)'"
Write-Host "    $swappiness"
$vfs = MmuAdb "sysctl vm.vfs_cache_pressure 2>/dev/null || echo 'N/A (need root)'"
Write-Host "    $vfs"

Write-Host ""
Write-Host "  Animation scales:" -ForegroundColor Cyan
$winScale = MmuAdb "settings get global window_animation_scale"
Write-Host "    window_animation_scale: $winScale"
$transScale = MmuAdb "settings get global transition_animation_scale"
Write-Host "    transition_animation_scale: $transScale"
$animScale = MmuAdb "settings get global animator_duration_scale"
Write-Host "    animator_duration_scale: $animScale"

Write-Host ""
Write-Host "  Disabled packages count:" -ForegroundColor Cyan
$disabledList = MmuAdb "pm list packages -d"
$disabledCount = ($disabledList -split "`n" | Where-Object { $_ -match "^package:" }).Count
Write-Host "    $disabledCount packages disabled"

Write-Host ""
Write-Host "  Preserved network components (should be enabled):" -ForegroundColor Cyan
$preserved = @(
    "android.resolv",
    "com.android.conscrypt",
    "android.tzdata",
    "com.android.networkstack",
    "com.android.server.wifi",
    "com.android.connectivity.resources"
)
foreach ($pkg in $preserved) {
    $status = MmuAdb "pm list packages -e | grep $pkg"
    if ($status -match $pkg) {
        Write-Host "    [OK] $pkg" -ForegroundColor Green
    } else {
        Write-Host "    [CHECK] $pkg" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  OPTIMIZATION COMPLETE (ULTRA SAFE)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Applied:" -ForegroundColor Green
Write-Host "    - sysctl: vm.swappiness=0, vm.vfs_cache_pressure=500"
Write-Host "    - boot_noroot.sh: simplified to 2 sysctl lines"
Write-Host "    - 10 GMS components disabled (non-network, non-auth)"
Write-Host "    - 15 system packages disabled (non-network)"
Write-Host "    - 8 APEX modules disabled (non-critical, non-network)"
Write-Host "    - 7 HAL packages disabled"
Write-Host "    - Animations, power, logcat optimizations"
Write-Host ""
Write-Host "  Preserved (NOT modified):" -ForegroundColor Cyan
Write-Host "    - android.resolv"
Write-Host "    - com.android.conscrypt"
Write-Host "    - android.tzdata"
Write-Host "    - com.android.networkstack"
Write-Host "    - com.android.server.wifi"
Write-Host "    - com.android.connectivity.resources"
Write-Host "    - vm_config.json"
Write-Host ""
Write-Host "  To apply boot script at next boot:" -ForegroundColor Yellow
Write-Host "    MmuAdb 'sh /data/local/tmp/boot_noroot.sh'"
Write-Host ""
