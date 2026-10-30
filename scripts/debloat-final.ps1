<#
  debloat-final.ps1
  Script completo de debloat para MuMu Player Global 12.0
  
  Elimina:
  - Paquetes ad-tech de /system (store_overseas, acc_overseas, oaidmanager)
  - Splash de arranque con botón "eliminar anuncios"
  - Widgets publicitarios de com.mumu.store
  - Telemetría y dominios de anuncios
  
  Instala:
  - mini-installer.apk (permite instalar APKs por doble click sin Tienda MuMu)
  
  Requisitos:
    - MuMu abierto con ROOT activado (Ajustes -> Otros -> Root)
    - ADB de MuMu disponible
    - Permisos de administrador (para hosts de Windows)
  
  Uso:
    powershell -ExecutionPolicy Bypass -File .\debloat-final.ps1
    .\debloat-final.ps1 -Serial "192.168.1.149:5555"
#>
[CmdletBinding()]
param(
  [string]$MuMuManager = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe",
  [string]$Adb       = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe",
  [string]$Serial    = "192.168.1.149:5555",
  [string]$VmIndex   = "0",
  [string]$MiniInstallerApk = "D:\mumu-global-debloat\patch\mini-installer.apk"
)

$ErrorActionPreference = 'Stop'
$roaming = Join-Path $env:APPDATA "Netease\MuMuPlayerGlobal"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   MuMu Player Global 12.0 - Debloat Final" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. VACIAR CACHE DE SPLASH DEL HOST (startupImage)
Write-Host "[1/8] Vaciando cache de anuncios del splash (startupImage)..." -ForegroundColor Green
$si = Join-Path $roaming "data\startupImage"
if (Test-Path $si) {
  Get-ChildItem $si -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
  $manifest = Join-Path $si "imageManager.json"
  Set-Content -LiteralPath $manifest -Value "{`r`n  `"info`": []`r`n}" -Encoding UTF8 -NoNewline
  attrib +R $manifest
  Write-Host "  [OK] startupImage vaciado y imageManager.json puesto en solo lectura"
} else {
  Write-Host "  [INFO] startupImage no existe, nada que limpiar"
}

# 2. ELIMINAR boot_screenshot.png (captura de arranque con anuncios)
Write-Host "[2/8] Eliminando boot_screenshot.png (splash residual con anuncios)..." -ForegroundColor Green
$bootScreenshot = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0\private_shared\boot_screenshot.png"
if (Test-Path $bootScreenshot) {
  Remove-Item -LiteralPath $bootScreenshot -Force
  Write-Host "  [OK] boot_screenshot.png eliminado"
} else {
  Write-Host "  [INFO] boot_screenshot.png no existe"
}

# 3. CONECTAR ADB
Write-Host "[3/8] Conectando ADB..." -ForegroundColor Green
& $Adb connect $Serial | Out-Null
Start-Sleep -Seconds 2

# 4. MONTAR /system EN RW Y APLICAR DEBLOAT DE SISTEMA
Write-Host "[4/8] Aplicando debloat de sistema (/system)..." -ForegroundColor Green
& $Adb -s $Serial shell "su -c 'mount -o rw,remount /system'" | Out-Null
Start-Sleep -Seconds 1

# Renombrar APKs ad-tech de /system/priv-app a .apk.off
$systemAdTech = @(
  "com.mumu.store_overseas",
  "com.mumu.acc_overseas",
  "com.nemu.oaidmanager"
)
foreach ($pkg in $systemAdTech) {
  $result = & $Adb -s $Serial shell "su -c 'p=/system/priv-app/$pkg/$pkg.apk; [ -f \$p ] && mv \$p \$p.off; echo RENAMED: \$pkg' 2>&1"
  Write-Host "  $result"
}

# INSTALAR STUB DE TIENDA MUMU LIMPIA EN /system/priv-app
Write-Host "  Instalando stub com.mumu.store (tienda limpia sin anuncios)..." -ForegroundColor Green
$stubApk = Join-Path $PSScriptRoot "..\patch\com.mumu.store.apk"
if (Test-Path $stubApk) {
  & $Adb -s $Serial push $stubApk /sdcard/com.mumu.store.apk | Out-Null
  $result = & $Adb -s $Serial shell "su -c 'mkdir -p /system/priv-app/com.mumu.store && cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store/com.mumu.store.apk && chmod 644 /system/priv-app/com.mumu.store/com.mumu.store.apk && chmod 755 /system/priv-app/com.mumu.store && echo OK: stub instalado en /system/priv-app/com.mumu.store' 2>&1"
  Write-Host "  $result"
} else {
  Write-Host "  [ERROR] No se encuentra $stubApk" -ForegroundColor Red
}

# Subir hosts anti-anuncios
$hostsFile = Join-Path $PSScriptRoot "..\patch\hosts"
if (Test-Path $hostsFile) {
  & $Adb -s $Serial push $hostsFile /data/local/tmp/hosts.antiad | Out-Null
  & $Adb -s $Serial shell "su -c 'cp /data/local/tmp/hosts.antiad /system/etc/hosts; chmod 644 /system/etc/hosts; rm -f /data/local/tmp/hosts.antiad'" | Out-Null
  Write-Host "  [OK] /system/etc/hosts actualizado"
}

# 5. DESHABILITAR COMPONENTES PUBLICITARIOS DE com.mumu.store (en /data)
Write-Host "[5/8] Deshabilitando componentes publicitarios de com.mumu.store..." -ForegroundColor Green
$storeComponents = @(
  "com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider",
  "com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider",
  "com.mumu.store/com.mumu.store.track.AdTrackingReceiver",
  "com.mumu.store/com.mumu.store.track.TrackingReceiver",
  "com.mumu.store/com.mumu.store.BootReceiver",
  "com.mumu.store/com.mumu.store.InstallationReceiver"
)
foreach ($comp in $storeComponents) {
  $result = & $Adb -s $Serial shell "su -c 'pm disable $comp' 2>&1"
  if ($result -match "disabled") { Write-Host "  [OK] $comp" }
  else { Write-Host "  [WARN] $comp -> $result" }
}

# 6. VERIFICAR STUB DE TIENDA MUMU (ya instalado en /system/priv-app en paso 4)
Write-Host "[6/8] Verificando stub com.mumu.store..." -ForegroundColor Green
$stubPath = & $Adb -s $Serial shell "pm path com.mumu.store 2>&1" | Out-String
Write-Host "  $($stubPath.Trim())"
$stubEnabled = & $Adb -s $Serial shell "dumpsys package com.mumu.store | grep 'enabled=' 2>&1" | Out-String
Write-Host "  $($stubEnabled.Trim())"

# 7. OPTIMIZACIONES DE RENDIMIENTO Y HOSTS DE WINDOWS
Write-Host "[7/8] Aplicando optimizaciones y bloqueos de hosts en Windows..." -ForegroundColor Green
& $MuMuManager setting --vmindex $VmIndex --key performance_mode --value middle | Out-Null
& $MuMuManager setting --vmindex $VmIndex --key app_keptlive --value false | Out-Null

& $Adb -s $Serial shell "settings put global window_animation_scale 0.0; settings put global transition_animation_scale 0.0; settings put global animator_duration_scale 0.0" | Out-Null

# Quitar puntos rojos
$nxcfg = Join-Path $roaming "configs\nx_main.json"
if (Test-Path $nxcfg) {
  $j = Get-Content $nxcfg -Raw | ConvertFrom-Json
  $j.nxmain.deskshort_redpoint = "0"
  $j.nxmain.devicemenu_redpoint = "0"
  ($j | ConvertTo-Json -Depth 10) | Set-Content $nxcfg -Encoding UTF8
}

# Bloquear dominios en hosts de Windows (requiere UAC)
$domains = @(
  "mumu-global.fp.ps.easebar.com", "adl.guinfra.com", "stardesk.net", "www.stardesk.net",
  "event.sc.gearupportal.com", "shence-api.mumu.163.com", "fcount-api.webapp.easebar.com",
  "fcount-api.webapp.163.com", "api.mumu.nie.netease.com", "sentry.netease.com",
  "report-api.mumuplayer.com", "api.mumuglobal.com"
)
$hosts = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$current = Get-Content $hosts -Raw
$toAdd = ""
foreach ($d in $domains) { if ($current -notmatch [regex]::Escape($d)) { $toAdd += "0.0.0.0 $d`r`n" } }
if ($toAdd) {
  $tmp = Join-Path $env:TEMP "mumu_hosts_block.txt"
  Set-Content -LiteralPath $tmp -Value ("`r`n# --- MuMu debloat: ads/telemetry ---`r`n" + $toAdd) -Encoding ASCII -NoNewline
  Start-Process -FilePath "cmd.exe" -ArgumentList "/c type `"$tmp`" >> `"$hosts`"" -Verb RunAs -Wait
  ipconfig /flushdns | Out-Null
  Write-Host "  [OK] hosts de Windows actualizado (UAC)"
} else {
  Write-Host "  [INFO] Dominios ya bloqueados en hosts"
}

# 8. VERIFICACIÓN FINAL
Write-Host "[8/8] Verificación final..." -ForegroundColor Green
Write-Host ""
Write-Host "=== VERIFICACIÓN SISTEMA ==="
& $Adb -s $Serial shell "md5sum /system/etc/hosts; wc -l /system/etc/hosts"
foreach ($pkg in $systemAdTech) {
  $path = & $Adb -s $Serial shell "pm path $pkg 2>&1" | Out-String
  Write-Host "  $pkg -> $($path.Trim())"
}

Write-Host ""
Write-Host "=== WIDGETS / APPWIDGET ==="
& $Adb -s $Serial shell "dumpsys appwidget | grep widgets.size" | Out-String | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "=== STUB TIENDA MUMU LIMPIA ==="
$stubPath = & $Adb -s $Serial shell "pm path com.mumu.store 2>&1" | Out-String
Write-Host "  $($stubPath.Trim())"
$stubInfo = & $Adb -s $Serial shell "dumpsys package com.mumu.store | Select-String 'enabled|stopped|dataDir|firstInstall|lastUpdate' 2>&1" | Out-String
Write-Host "  $($stubInfo.Trim())"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   DEBLOAT COMPLETADO!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para que los cambios en /system persistan tras reiniciar:"
Write-Host "  1. Cierra MuMu completamente"
Write-Host "  2. Ejecuta: .\scripts\merge_diff.ps1 (para generar system.merged.vdi)"
Write-Host "  3. Ejecuta: .\scripts\swap_base.ps1 (para hornear en base)"
Write-Host ""
Write-Host "El splash de arranque con 'eliminar anuncios' ya no deberia aparecer."
Write-Host "Los APKs se instalan con doble click via STUB com.mumu.store (tienda limpia en /system/priv-app)."
Write-Host ""
Write-Host "IMPORTANTE: El stub requiere hornear en la base (merge_diff + swap_base) para que"
Write-Host "el doble click funcione nativamente (uid 1000 = su permitido)."