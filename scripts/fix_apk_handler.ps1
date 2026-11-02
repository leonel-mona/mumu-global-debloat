<#======================================================================
  fix_apk_handler.ps1
  ---------------------------------------------------------------
  Arregla la instalación de APKs por doble-clic:
  1. Habilita PackageInstaller (si esta deshabilitado)
  2. Deshabilita el componente XApkInstallerActivity de MuMu Store
     para que deje de interceptar intents de .apk
  3. Verifica que PackageInstaller sea el unico handler
======================================================================#>

$ErrorActionPreference = 'Stop'

$AdbExe    = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$VmIndex   = 1
$PkgInstall = "com.android.packageinstaller"
$MumuStore  = "com.mumu.store"
$MumuApkActivity = "com.mumu.store/.install.XApkInstallerActivity"

Write-Host "=== FIX APK HANDLER ===" -ForegroundColor Cyan

# --------------------------------------------------------------
# 1. Obtener puerto ADB
# --------------------------------------------------------------
Write-Host "`n[1/5] Consultando VM $VmIndex ..."
$infoJson = & "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe" info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
if (-not $infoJson.is_android_started) {
    throw "La VM $VmIndex no esta corriendo."
}
$port = $infoJson.adb_port
Write-Host "    Puerto ADB: $port"

# Conectar
& $AdbExe connect "127.0.0.1:$port" | Out-Null
Start-Sleep -Seconds 2

# --------------------------------------------------------------
# 2. Habilitar PackageInstaller
# --------------------------------------------------------------
Write-Host "`n[2/5] Habilitando $PkgInstall ..."
& $AdbExe -s "127.0.0.1:$port" shell "pm enable --user 0 $PkgInstall" 2>&1 | Out-Null
$state = & $AdbExe -s "127.0.0.1:$port" shell "pm list packages -f $PkgInstall" 2>&1
Write-Host "    Estado: $state"

# --------------------------------------------------------------
# 3. Deshabilitar XApkInstallerActivity de MuMu Store
# --------------------------------------------------------------
Write-Host "`n[3/5] Deshabilitando componente $MumuApkActivity ..."
$out = & $AdbExe -s "127.0.0.1:$port" shell "pm disable $MumuApkActivity" 2>&1
Write-Host "    $out"

# --------------------------------------------------------------
# 4. Verificar handlers de MIME type package-archive
# --------------------------------------------------------------
Write-Host "`n[4/5] Verificando handlers de application/vnd.android.package-archive ..."
$dump = & $AdbExe -s "127.0.0.1:$port" shell "dumpsys package com.android.packageinstaller" 2>&1
$mumuDump = & $AdbExe -s "127.0.0.1:$port" shell "dumpsys package com.mumu.store" 2>&1

$pkgInstallMatch = $dump -match "package-archive"
$mumuMatch = $mumuDump -match "package-archive"

Write-Host "    PackageInstaller maneja package-archive: $pkgInstallMatch"
Write-Host "    MuMu Store maneja package-archive: $mumuMatch"

# --------------------------------------------------------------
# 5. Asegurar que MuMu Store siga deshabilitado a nivel de paquete
# --------------------------------------------------------------
Write-Host "`n[5/5] Asegurando que $MumuStore este deshabilitado ..."
& $AdbExe -s "127.0.0.1:$port" shell "pm disable-user --user 0 $MumuStore" 2>&1 | Out-Null
Write-Host "    OK."

Write-Host "`n=== LISTO ===" -ForegroundColor Cyan
Write-Host "Ahora el doble-clic en .apk usara el instalador oficial de Android."
Write-Host "Si no funciona, prueba con: pm enable --user 0 com.android.packageinstaller"