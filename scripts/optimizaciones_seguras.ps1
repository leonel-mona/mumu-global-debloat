<#======================================================================
  optimizaciones_seguras.ps1
  =====================================================================
  Optimizaciones seguras para MuMu Player Global 12.0 (VM con root).
  Riesgo: BAJO (rollback inmediato disponible)
  
  Uso:
    powershell -ExecutionPolicy Bypass -File optimizaciones_seguras.ps1 -VmIndex 1
======================================================================#>

param(
  [string]$VmIndex = "1",
  [string]$Serial  = "127.0.0.1:16416"
)

$AdbExe = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$MuMu   = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"

function Adb   { param([string]$cmd) return (& $AdbExe -s $Serial shell $cmd 2>&1 | Out-String).Trim() }
function AdbSu { param([string]$cmd) return (& $AdbExe -s $Serial shell "/system/xbin/su -c '$cmd'" 2>&1 | Out-String).Trim() }
function Mmu   { param([string]$cmd) return (& $MuMu control --vmindex $VmIndex $cmd 2>&1 | Out-String).Trim() }

$ErrorActionPreference = 'Continue'

Write-Host "=== OPTIMIZACIONES SEGURAS (VM $VmIndex) ===" -ForegroundColor Cyan
Write-Host "Serial: $Serial" -ForegroundColor Gray
Write-Host ""

# --------------------------------------------------------------
# 1. Dalvik VM tuning (persiste en /data/property)
# --------------------------------------------------------------
Write-Host "[1/6] Dalvik VM tuning..." -ForegroundColor Cyan
AdbSu "setprop persist.dalvik.vm.heapstartsize 4m"
AdbSu "setprop persist.dalvik.vm.heapgrowthlimit 96m"
AdbSu "setprop persist.dalvik.vm.heapsize 192m"
AdbSu "setprop persist.dalvik.vm.heapminfree 512k"
AdbSu "setprop persist.dalvik.vm.heapmaxfree 8m"
AdbSu "setprop dalvik.vm.heapstartsize 4m"
AdbSu "setprop dalvik.vm.heapgrowthlimit 96m"
AdbSu "setprop dalvik.vm.heapsize 192m"
Write-Host "    heapstartsize=4m, heapgrowthlimit=96m, heapsize=192m" -ForegroundColor Green

# --------------------------------------------------------------
# 2. Logcat / logging mínimo (persiste en /data/property)
# --------------------------------------------------------------
Write-Host "[2/6] Logcat mínimo..." -ForegroundColor Cyan
AdbSu "setprop persist.logd.size 64K"
AdbSu "setprop persist.logd.size.main 64K"
AdbSu "setprop persist.logd.size.system 64K"
AdbSu "setprop persist.logd.size.radio 64K"
AdbSu "setprop persist.logd.size.events 64K"
AdbSu "logcat -c"
Write-Host "    logd buffers: 64K" -ForegroundColor Green

# --------------------------------------------------------------
# 3. GPU / SurfaceFlinger tuning (runtime)
# --------------------------------------------------------------
Write-Host "[3/6] GPU/SurfaceFlinger..." -ForegroundColor Cyan
AdbSu "setprop debug.sf.latch_unsignaled 1"
AdbSu "setprop debug.sf.early_gl_latch 0"
AdbSu "setprop debug.hwui.sync_buffer 0"
AdbSu "setprop debug.hwui.force_dark_mode 0"
AdbSu "setprop debug.sf.hwc_check 0"
Write-Host "    latch_unsignaled=1, early_gl_latch=0, hwc_check=0" -ForegroundColor Green

# --------------------------------------------------------------
# 4. Servicios no esenciales (stop, se reinician al boot)
# --------------------------------------------------------------
Write-Host "[4/6] Servicios no esenciales (stop)..." -ForegroundColor Cyan
$stopServices = @(
    "thermal-engine",
    "gatekeeperd",
    "dumpstate"
)
foreach ($s in $stopServices) {
    AdbSu "setprop ctl.stop $s" | Out-Null
}
Write-Host "    Parados: thermal-engine, gatekeeperd, dumpstate" -ForegroundColor Green

# --------------------------------------------------------------
# 5. APEX modules no esenciales (disable-user)
# --------------------------------------------------------------
Write-Host "[5/6] APEX modules..." -ForegroundColor Cyan
$apexOff = @("android.ext.services")
foreach ($a in $apexOff) {
    AdbSu "pm disable-user --user 0 $a" | Out-Null
    Write-Host "    Deshabilitado: $a"
}
Write-Host "    APEX procesados" -ForegroundColor Green

# --------------------------------------------------------------
# 6. Configuración MuMu: vsync/frame_rate en vm_config.json
# --------------------------------------------------------------
Write-Host "[6/6] vm_config.json..." -ForegroundColor Cyan
$cfg = Join-Path "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-$VmIndex" "configs\vm_config.json"
if (Test-Path $cfg) {
  $j = Get-Content $cfg -Raw | ConvertFrom-Json
  if (-not $j.display) { $j | Add-Member -MemberType NoteProperty -Name display -Value ([pscustomobject]@{}) }
  $j.display | Add-Member -MemberType NoteProperty -Name vsync -Value "false" -Force
  $j.display | Add-Member -MemberType NoteProperty -Name vertical_sync -Value "false" -Force
  $j.display | Add-Member -MemberType NoteProperty -Name frame_rate -Value 30 -Force
  $j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
  Write-Host "    vsync=false, vertical_sync=false, frame_rate=30" -ForegroundColor Green
} else {
  Write-Warning "    No se encontró vm_config.json: $cfg"
}

Write-Host ""
Write-Host "=== OPTIMIZACIONES SEGURAS COMPLETADAS ===" -ForegroundColor Green
Write-Host "Rollback: `AdbSu 'setprop persist.dalvik.vm.heapstartsize 16m'` etc."