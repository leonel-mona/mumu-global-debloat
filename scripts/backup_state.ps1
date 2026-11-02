<#======================================================================
  backup_state.ps1
  Crea un backup COMPLETO del estado de la VM
======================================================================#>

$ErrorActionPreference = 'Stop'
$AdbExe    = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$Serial    = "127.0.0.1:16416"
$VmDir     = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-1"
$BackupDir = "D:\MuMuPlayerGlobal-12.0\backup_debloat\state_" + (Get-Date -Format 'yyyyMMdd_HHmmss')

Write-Host "=== BACKUP STATE -> $BackupDir ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

function Adb {
    param([string]$cmd)
    return (& $AdbExe -s $Serial shell $cmd 2>&1 | Out-String).Trim()
}

# 1. Settings completos
Write-Host "`n[1/5] Settings..."
@("secure", "global", "system") | ForEach-Object {
    $scope = $_
    $out = Adb "settings list $scope"
    Set-Content -LiteralPath "$BackupDir\settings_$scope.txt" -Value $out -Encoding UTF8
    $count = ($out -split "`n" | Where-Object {$_ -ne ''}).Count
    Write-Host "    $scope : $count entries"
}

# 2. Paquetes
Write-Host "`n[2/5] Paquetes..."
$pkgFiles = @{
    "packages_all.txt"      = "pm list packages -f"
    "packages_enabled.txt"  = "pm list packages -e"
    "packages_disabled.txt" = "pm list packages -d"
    "packages_system.txt"   = "pm list packages -s"
    "packages_user0.txt"    = "pm list packages --user 0"
}
$pkgFiles.GetEnumerator() | ForEach-Object {
    $name = $_.Key
    $cmd = $_.Value
    $out = Adb $cmd
    Set-Content -LiteralPath "$BackupDir\$name" -Value $out -Encoding UTF8
    $count = ($out -split "`n" | Where-Object {$_ -ne ''}).Count
    Write-Host "    $name : $count lines"
}

# 3. Props
Write-Host "`n[3/5] Props..."
$out = Adb "getprop"
Set-Content -LiteralPath "$BackupDir\props.txt" -Value $out -Encoding UTF8
$count = ($out -split "`n" | Where-Object {$_ -ne ''}).Count
Write-Host "    props.txt : $count lines"

# 4. Hosts file
Write-Host "`n[4/5] Hosts..."
$out = Adb "cat /system/etc/hosts"
Set-Content -LiteralPath "$BackupDir\hosts.txt" -Value $out -Encoding UTF8

# 5. vm_config.json
Write-Host "`n[5/5] vm_config.json..."
Copy-Item -LiteralPath "$VmDir\configs\vm_config.json" -Destination "$BackupDir\vm_config.json" -Force

# 6. Dumpsys package (apps criticas)
Write-Host "`n[6/5] Componentes deshabilitados (apps criticas)..."
$critics = @(
    "com.android.vending",
    "com.google.android.gms",
    "com.mumu.store",
    "app.lawnchair",
    "com.android.packageinstaller",
    "com.android.settings",
    "com.android.systemui"
)
foreach ($p in $critics) {
    Write-Host "    pm_dump_$p ..."
    $out = Adb "/system/xbin/su -c 'pm dump $p'"
    Set-Content -LiteralPath "$BackupDir\pm_dump_$p.txt" -Value $out -Encoding UTF8
}

# 7. Dumpsys varios
Write-Host "`n[7/5] Dumpsys varios..."
$dumpsysList = @(
    "package", "activity", "window", "activity activities", "activity top",
    "appwidget", "wallpaper", "input", "display", "power", "battery",
    "connectivity", "netd", "account", "user", "jobscheduler", "notification",
    "accessibility", "meminfo", "cpuinfo"
)
foreach ($d in $dumpsysList) {
    $safeName = $d -replace '\s+', '_'
    Write-Host "    dumpsys_$safeName ..."
    try {
        $ErrorActionPreference = 'Continue'
        $out = Adb "dumpsys $d"
        $ErrorActionPreference = 'Stop'
        if ($out -match "Can't find service|Error|Failed|No such") {
            Write-Warning "    Skip: $d"
            continue
        }
        Set-Content -LiteralPath "$BackupDir\dumpsys_$safeName.txt" -Value $out -Encoding UTF8
    } catch {
        Write-Warning "    Error en $d"
    }
}

Write-Host "`n=== BACKUP COMPLETADO ===" -ForegroundColor Green
Write-Host "Ubicacion: $BackupDir"

# Listar archivos
$files = Get-ChildItem -LiteralPath $BackupDir -File
Write-Host "Archivos: $($files.Count)"
$size = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host "Tamano total: $([math]::Round($size/1MB, 2)) MB"