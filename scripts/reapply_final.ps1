<#
  reapply_final.ps1
  Script completo para reaplicar todas las optimizaciones en una VM nueva.
  Incluye: hardware mínimo, deshabilitar paquetes basura, deshabilitar componentes
  de anuncios, habilitar GMS/Play Store, settings anti-sugerencias, animaciones=0,
  servicios vendor, hosts anti-ads, fix APK handler (PackageInstaller como default).

  Uso:
    powershell -ExecutionPolicy Bypass -File reapply_final.ps1 -VmIndex <índice> -Serial "127.0.0.1:XXXX"
#>

param(
  [string]$MuMuManager = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe",
  [string]$Adb       = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe",
  [string]$Serial    = "127.0.0.1:16416",
  [string]$VmIndex   = "1"
)

$ErrorActionPreference = 'Stop'

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   REAPLICACIÓN COMPLETA DE OPTIMIZACIONES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

function Exec-Adb($cmd) {
    & $Adb -s $Serial shell $cmd 2>&1
}

function Exec-AdbSu($cmd) {
    & $Adb -s $Serial shell "su -c `"$cmd`"" 2>&1
}

# 1. Hardware mínimo
Write-Host "[1/10] Hardware mínimo..."
& $MuMuManager setting --vmindex $VmIndex --key performance_mode --value low | Out-Null
& $MuMuManager setting --vmindex $VmIndex --key gpu_mode --value low | Out-Null
& $MuMuManager setting --vmindex $VmIndex --key app_keptlive --value false | Out-Null
Write-Host "  OK: performance_mode=low, gpu_mode=low, app_keptlive=false"

# 2. Habilitar paquetes Google críticos (GMS, Play Store, GSF)
Write-Host "[2/10] Habilitando GMS y Play Store..."
$googleCritical = @(
    "com.google.android.gms",
    "com.android.vending",
    "com.google.android.gsf",
    "com.google.android.backuptransport",
    "com.google.android.partnersetup"
)
foreach ($pkg in $googleCritical) {
    Exec-Adb "pm enable $pkg" | Out-Null
    Write-Host "  OK: $pkg habilitado"
}

# 3. Deshabilitar paquetes no críticos (bloat)
Write-Host "[3/10] Deshabilitando bloatware..."
$disables = @(
    "com.mumu.store",
    "com.google.android.apps.restore",
    "com.google.android.configupdater",
    "com.google.android.syncadapters.contacts",
    "com.google.android.contacts",
    "com.google.android.feedback",
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
foreach ($pkg in $disables) {
    Exec-Adb "pm disable-user --user 0 $pkg" | Out-Null
    Write-Host "  OK: $pkg deshabilitado"
}

# 4. Deshabilitar componentes de anuncios (requiere root)
Write-Host "[4/10] Deshabilitando componentes de anuncios (root)..."
$adComponents = @(
    # MuMu Store
    "com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider",
    "com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider",
    "com.mumu.store/com.mumu.store.track.AdTrackingReceiver",
    "com.mumu.store/com.mumu.store.track.TrackingReceiver",
    "com.mumu.store/com.mumu.store.BootReceiver",
    "com.mumu.store/com.mumu.store.InstallationReceiver",
    # Play Store
    "com.android.vending/com.google.android.finsky.searchsuggestions.RecentSuggestionsProvider",
    # Google Play Services
    "com.google.android.gms/.ads.identifier.service.AdvertisingIdService",
    "com.google.android.gms/.ads.identifier.service.AdvertisingIdNotificationService"
)
foreach ($comp in $adComponents) {
    Exec-AdbSu "pm disable $comp" | Out-Null
    Write-Host "  OK: $comp deshabilitado"
}

# 5. FIX APK HANDLER: PackageInstaller como default para .apk
Write-Host "[5/10] Fix APK handler (PackageInstaller como default)..."
Exec-Adb "pm enable --user 0 com.android.packageinstaller" | Out-Null
Exec-AdbSu "pm disable com.mumu.store/com.mumu.store.install.XApkInstallerActivity" | Out-Null
Write-Host "  OK: PackageInstaller habilitado, XApkInstallerActivity deshabilitado"

# 6. Settings globales anti-sugerencias
Write-Host "[6/10] Settings anti-sugerencias..."
Exec-AdbSu 'settings put secure show_app_recommendations 0'
Exec-AdbSu 'settings put secure enable_suggestions 0'
Exec-AdbSu 'settings put global enable_advertising_id_collection 0'
Exec-AdbSu 'settings put secure show_search_app_suggestions 0'
Write-Host "  OK: Settings aplicados"

# 7. Animaciones = 0
Write-Host "[7/10] Animaciones = 0..."
Exec-Adb 'settings put global window_animation_scale 0.0'
Exec-Adb 'settings put global transition_animation_scale 0.0'
Exec-Adb 'settings put global animator_duration_scale 0.0'
Write-Host "  OK: Animaciones deshabilitadas"

# 8. Servicios vendor no esenciales
Write-Host "[8/10] Servicios vendor..."
$vendorServices = @(
    "vendor.bluetooth-1-1",
    "vendor.gnss-2-0",
    "vendor.sensors-hal-2-1-multihal",
    "vendor.vibrator-1-3",
    "vendor.camera-provider-2-4",
    "vendor.power.stats-hal-1-0-mock",
    "vendor.ril-daemon"
)
foreach ($svc in $vendorServices) {
    Exec-Adb "setprop ctl.stop $svc" | Out-Null
    Exec-Adb "setprop ctl.disable $svc" | Out-Null
    Write-Host "  OK: $svc detenido y deshabilitado"
}

# 9. Hosts anti-ads (intenta /system RW)
Write-Host "[9/10] Hosts anti-ads..."
try {
    Exec-AdbSu 'mount -o rw,remount /system' | Out-Null
    & $Adb -s $Serial push "D:\mumu-global-debloat\patch\hosts_fixed.txt" /data/local/tmp/hosts.antiad | Out-Null
    Exec-AdbSu 'cp /data/local/tmp/hosts.antiad /system/etc/hosts; chmod 644 /system/etc/hosts'
    Write-Host "  OK: /system/etc/hosts actualizado"
} catch {
    Write-Host "  WARN: No se pudo montar /system RW (hosts no aplicado en vivo)"
    Write-Host "        -> Usar merge_diff.ps1 + swap_base.ps1 para hornear en base"
}

# 10. Reiniciar
Write-Host "[10/10] Reiniciando VM..."
& $MuMuManager control --vmindex $VmIndex shutdown | Out-Null
Start-Sleep -Seconds 10
& $MuMuManager control --vmindex $VmIndex launch | Out-Null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   REAPLICACIÓN COMPLETADA" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:"
Write-Host "1. Esperar a que arranque (~100-120s en hardware low)"
Write-Host "2. Abrir Play Store y logear con cuenta Google"
Write-Host "3. Verificar que NO aparecen sugerencias/anuncios"
Write-Host "4. Probar doble-clic en .apk -> debe abrir instalador oficial"
Write-Host "5. Si todo OK, cerrar MuMu y ejecutar merge_diff.ps1 + swap_base.ps1:"
Write-Host "   merge_diff.ps1 -Base 'D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi' -Diff 'D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-<idx>\ota.vdi' -Out 'D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi'"
Write-Host "   swap_base.ps1 -Merged 'D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi'"
Write-Host ""
Write-Host "Base MD5 esperado (fusionado): 7c4270b310b4eab8b2aa0db40e2100a0"