<#
  backup_state_mumu.ps1
  Backup completo del estado de la VM usando MuMuManager.exe adb (confiable)
#>
param(
  [Parameter(Mandatory=$true)][int]$VmIndex,
  [string]$OutDir = "D:\MuMuPlayerGlobal-12.0\backup_debloat"
)

$ErrorActionPreference = 'Stop'
$MuMu = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"

function Get-AdbOut {
  param([string]$cmd)
  $out = & $MuMu adb --vmindex $VmIndex --cmd "shell $cmd" 2>&1
  return $out.Trim()
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$dir = Join-Path $OutDir "state_$ts"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

Write-Host "=== BACKUP STATE (MuMu ADB) -> $dir ==="

# 1. Settings
Write-Host "[1/8] Settings..."
Get-AdbOut "settings list global"   | Set-Content "$dir\settings_global.txt" -Encoding UTF8
Get-AdbOut "settings list secure"  | Set-Content "$dir\settings_secure.txt" -Encoding UTF8
Get-AdbOut "settings list system"  | Set-Content "$dir\settings_system.txt" -Encoding UTF8

# 2. Paquetes
Write-Host "[2/8] Paquetes..."
Get-AdbOut "pm list packages -e"    | Set-Content "$dir\packages_enabled.txt" -Encoding UTF8
Get-AdbOut "pm list packages -d"    | Set-Content "$dir\packages_disabled.txt" -Encoding UTF8
Get-AdbOut "pm list packages -u"    | Set-Content "$dir\packages_all.txt" -Encoding UTF8

# 3. Componentes deshabilitados
Write-Host "[3/8] Componentes deshabilitados..."
@(
  "com.android.vending",
  "com.google.android.gms",
  "com.google.android.gsf",
  "app.lawnchair"
) | ForEach-Object {
  $out = Get-AdbOut "dumpsys package $_"
  $out | Select-String "disabledComponents:" -Context 0,50 | ForEach-Object { $_.Context.PostContext } | Set-Content "$dir\components_disabled_$_.txt" -Encoding UTF8
}

# 4. Props
Write-Host "[4/8] Props..."
$props = Get-AdbOut "getprop"
$props | Select-String "persist" | Set-Content "$dir\props_persist.txt" -Encoding UTF8
$props | Select-String "debug.sf" | Set-Content "$dir\props_debug_sf.txt" -Encoding UTF8
$props | Select-String "debug.hwui" | Set-Content "$dir\props_debug_hwui.txt" -Encoding UTF8
$props | Select-String "dalvik.vm.heap" | Set-Content "$dir\props_dalvik.txt" -Encoding UTF8

# 5. Servicios init
Write-Host "[5/8] Servicios init..."
$props | Select-String "init.svc" | Set-Content "$dir\init_services.txt" -Encoding UTF8

# 6. Hosts
Write-Host "[6/8] Hosts..."
Get-AdbOut "cat /etc/hosts" | Set-Content "$dir\hosts.txt" -Encoding UTF8

# 7. vm_config.json
Write-Host "[7/8] vm_config.json..."
Get-AdbOut "cat /sdcard/MuMu/shared/vm_config.json 2>/dev/null || cat /data/media/0/MuMu/shared/vm_config.json 2>/dev/null || cat /mnt/sdcard/MuMu/shared/vm_config.json 2>/dev/null || echo 'NOT FOUND'" | Set-Content "$dir\vm_config.json" -Encoding UTF8

# 8. Boot script
Write-Host "[8/8] boot_opt.sh..."
Get-AdbOut "cat /data/local/tmp/boot_opt.sh 2>/dev/null || echo 'NOT FOUND'" | Set-Content "$dir\boot_opt.sh" -Encoding UTF8

# Resumen
Write-Host ""
Write-Host "=== RESUMEN ==="
$enabled = (Get-Content "$dir\packages_enabled.txt").Count
$disabled = (Get-Content "$dir\packages_disabled.txt").Count
Write-Host "  Paquetes enabled:  $enabled"
Write-Host "  Paquetes disabled: $disabled"
Write-Host "  Directorio: $dir"