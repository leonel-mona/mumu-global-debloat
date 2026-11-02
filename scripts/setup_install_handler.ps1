<#======================================================================
  setup_install_handler.ps1
  ---------------------------------------------------------------
  Configura la VM MuMu para que la instalación de APKs mediante
  doble-clic use el instalador oficial de Android (PackageInstaller)
  en lugar de MuMu Store.
======================================================================#>

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------
# Configuración (ajusta solo si tu entorno difiere)
# --------------------------------------------------------------
$MuMuExe    = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"
$AdbExe     = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$VmIndex    = 1                    # VM con root (la que acabamos de configurar)
$MumuStore  = "com.mumu.store"
$PkgInstall = "com.android.packageinstaller"
$ActInstall = "com.android.packageinstaller.PackageInstallerActivity"  # Android 12

Write-Host "=== SETUP HANDLER DE INSTALACION APK ===" -ForegroundColor Cyan

# --------------------------------------------------------------
# 1. Obtener puerto ADB de la VM
# --------------------------------------------------------------
Write-Host "`n[1/6] Consultando info de VM $VmIndex ..."
$infoJson = & $MuMuExe info --vmindex $VmIndex 2>&1 | ConvertFrom-Json
if (-not $infoJson.is_android_started) {
    throw "La VM $VmIndex no esta corriendo. Iniciala primero."
}
$port = $infoJson.adb_port
Write-Host "    Puerto ADB: $port"

# --------------------------------------------------------------
# 2. Conectar ADB
# --------------------------------------------------------------
Write-Host "`n[2/6] Conectando ADB ..."
& $AdbExe connect "127.0.0.1:$port" | Out-Null
Start-Sleep -Seconds 2

# --------------------------------------------------------------
# 3. Verificar root (adb root)
# --------------------------------------------------------------
Write-Host "`n[3/6] Verificando root ..."
$rootCheck = & $AdbExe -s "127.0.0.1:$port" shell /system/xbin/su -c "id" 2>&1
if ($rootCheck -notmatch "uid=0") {
    throw "Root no disponible: $rootCheck"
}
Write-Host "    OK: $rootCheck.Trim()"

# --------------------------------------------------------------
# 4. Limpiar preferencia previa de MuMu Store
# --------------------------------------------------------------
Write-Host "`n[4/6] Limpiando preferencias de $MumuStore ..."
& $AdbExe -s "127.0.0.1:$port" shell pm clear-preferred-activities $MumuStore 2>&1 | Out-Null
Write-Host "    Hecho."

# --------------------------------------------------------------
# 5. Registrar PackageInstaller como default para VIEW .apk
# --------------------------------------------------------------
Write-Host "`n[5/6] Registrando $PkgInstall como handler por defecto ..."
$cmd = "pm set-preferred-activity -a android.intent.action.VIEW -c android.intent.category.DEFAULT -t application/vnd.android.package-archive $PkgInstall/$ActInstall"
$out = & $AdbExe -s "127.0.0.1:$port" shell $cmd 2>&1
Write-Host "    Salida: $out"

# --------------------------------------------------------------
# 6. Verificar que quedo escrito
# --------------------------------------------------------------
Write-Host "`n[6/6] Verificando preferencia registrada ..."
$pref = & $AdbExe -s "127.0.0.1:$port" shell pm get-preferred-activities 2>&1
if ($pref -match [regex]::Escape("$PkgInstall/$ActInstall")) {
    Write-Host "    Preferencia ACTIVA para $PkgInstall/$ActInstall" -ForegroundColor Green
} else {
    Write-Warning "    No se ve la preferencia en la salida. Revisa manualmente:"
    Write-Host $pref
}

# --------------------------------------------------------------
# 7. Asegurar que MuMu Store sigue deshabilitado
# --------------------------------------------------------------
Write-Host "`n[7/7] Confirmando que $MumuStore sigue deshabilitado ..."
& $AdbExe -s "127.0.0.1:$port" shell pm disable-user --user 0 $MumuStore 2>&1 | Out-Null
Write-Host "    OK."

Write-Host "`n=== LISTO ===" -ForegroundColor Cyan
Write-Host "Ahora, al hacer doble-clic en cualquier .apk dentro del emulador,"
Write-Host "se abrira el instalador oficial de Android (PackageInstaller)."