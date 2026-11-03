<#======================================================================
  full_optimize_boot_v3.ps1
  =====================================================================
  Optimizacion completa boot - usa MuMuManager.exe adb (funciona con IP LAN)
======================================================================#>

param(
  [int]$VmIndex = 1,
  [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
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

function MmuAdb   { param([string]$cmd) & $MuMu adb --vmindex $VmIndex --cmd "shell $cmd" 2>&1 | Out-String }
function MmuAdbSu { param([string]$cmd) & $MuMu adb --vmindex $VmIndex --cmd "shell /system/xbin/su -c '$cmd'" 2>&1 | Out-String }
function Ok    { param([string]$msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn  { param([string]$msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 0. Verificar VM corriendo
# ---------------------------------------------------------------------------
Step "Conexión ADB"
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
Ok "VM corriendo - IP reportada: $($info.adb_host_ip):$($info.adb_port)"

# Test ADB via MuMu
$test = MmuAdb "echo ok"
if ($test -notmatch "ok") { throw "MuMu ADB no responde" }
Ok "MuMu ADB funcionando"

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
    MmuAdbSu "setprop $key $val" | Out-Null
    $short = $key -replace '^persist\.', ''
    MmuAdbSu "setprop $short $val" | Out-Null
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
    MmuAdbSu "setprop $key $val" | Out-Null
}
MmuAdb "logcat -c" | Out-Null
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
    MmuAdbSu "setprop $key $val" | Out-Null
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
    $state = (MmuAdb "getprop init.svc.$svc").Trim()
    if ($state -eq "running" -or $state -eq "restarting") {
        MmuAdbSu "setprop ctl.stop $svc" | Out-Null
        $stopped++
    }
}
Ok "$stopped servicios parados"

# ---------------------------------------------------------------------------
# 5. Stop zygote_secondary
# ---------------------------------------------------------------------------
Step "5. Stop zygote_secondary" "Libera memoria y boot 32-bit"

$zygoteState = (MmuAdb "getprop init.svc.zygote_secondary").Trim()
if ($zygoteState -eq "running") {
    MmuAdbSu "setprop ctl.stop zygote_secondary" | Out-Null
    Start-Sleep 2
    $newState = (MmuAdb "getprop init.svc.zygote_secondary").Trim()
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
    MmuAdbSu "pm disable-user --user 0 $a" | Out-Null
}
Ok "APEX no esenciales deshabilitados"

# ---------------------------------------------------------------------------
# 6b. MuMu Store: disable at user level (keeps APK installer, no splash)
# ---------------------------------------------------------------------------
Step "6b. MuMu Store disable-user" "pm disable-user --user 0 (no splash, installer works)"

MmuAdbSu "pm install-existing com.mumu.store" | Out-Null
MmuAdbSu "pm disable-user --user 0 com.mumu.store" | Out-Null
$storeCheck = (MmuAdb "pm list packages com.mumu.store").Trim()
if ($storeCheck -match "com.mumu.store") {
    Ok "MuMu Store presente (disabled-user) - sin splash, installer OK"
} else {
    Warn "MuMu Store no encontrado"
}

# Verify APK installer works
$testInstall = & $MuMu control --vmindex $VmIndex app install --apk "D:\mumu-global-debloat\store.apk" 2>&1
if ($testInstall -match '"package"') {
    Ok "MuMuManager.exe control app install: FUNCIONA"
} else {
    Warn "MuMuManager.exe control app install: $testInstall"
}

# 7. Bloatware
# ---------------------------------------------------------------------------
Step "7. Bloatware" "Deshabilitar paquetes"

$disablePkgs = @(
    # com.mumu.store is disabled-user (no splash), kept for reference

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
    $res = MmuAdb "pm disable-user --user 0 $pkg"
    if ($res -match "new state: disabled") { $disabled++ }
}
Ok "$disabled paquetes deshabilitados"

# ---------------------------------------------------------------------------
# 8. Componentes de anuncios
# ---------------------------------------------------------------------------
Step "8. Componentes de anuncios" "Ad tracking + XApkInstaller"

# NOTE: com.mumu.store is UNINSTALLED (pm uninstall -k --user 0) - no splash ads
$adComponents = @(
    "com.android.vending/com.google.android.finsky.searchsuggestions.RecentSuggestionsProvider",
    "com.google.android.ads.identifier.service.AdvertisingIdService",
    "com.google.android.ads.identifier.service.AdvertisingIdNotificationService",
    "app.lawnchair/app.lawnchair.smartspace.SmartspaceAppWidgetProvider"
)
$compDisabled = 0
foreach ($comp in $adComponents) {
    $res = MmuAdbSu "pm disable $comp"
    if ($res -match "new state: disabled") { $compDisabled++ }
}
Ok "$compDisabled componentes deshabilitados"

# ---------------------------------------------------------------------------
# 9. APK handler fix
# ---------------------------------------------------------------------------
Step "9. APK Handler" "PackageInstaller por defecto"

MmuAdb "pm enable --user 0 com.android.packageinstaller" | Out-Null
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
    MmuAdb "pm enable $pkg" | Out-Null
}
Ok "GMS, Play Store, GSF habilitados"

# ---------------------------------------------------------------------------
# 11. Play Store optimizado (telemetría, auto-update, wear, instant apps)
# ---------------------------------------------------------------------------
Step "11. Play Store optimizado" "Deshabilitar telemetría + auto-update + wear/instant apps"

$playStoreDisable = @(
    # Boot / Auto-update services
    "com.android.vending/com.google.android.finsky.boothandler.BootCompletedReceiver",
    "com.android.vending/com.google.android.finsky.installservice.AppRecoveryUpdateService",
    "com.android.vending/com.google.android.finsky.installservice.DevTriggeredUpdateService",
    "com.android.vending/com.google.android.finsky.installservice.BlockingUpdateFlowActivity",
    "com.android.vending/com.google.android.finsky.installservice.UpdateSplashScreenActivity",
    "com.android.vending/com.google.android.finsky.installservice.NonBlockingUpdateFlowDialogActivity",
    "com.android.vending/com.google.android.finsky.splitinstallservice.SplitInstallService",
    "com.android.vending/com.google.android.finsky.assetmoduleservice.AssetModuleService",
    "com.android.vending/com.google.android.finsky.downloadservice.DownloadService",
    "com.android.vending/com.google.android.finsky.rollbackmanager.RollbackReceiver",
    # Wear support
    "com.android.vending/com.google.android.finsky.wearsupport.WearSupportService",
    "com.android.vending/com.google.android.finsky.wearsupport.WearChangeListenerService",
    # Instant apps
    "com.android.vending/com.google.android.finsky.instantapps.InstantAppsLoggingService",
    "com.android.vending/com.google.android.finsky.instantapps.EnabledStatusSyncService",
    "com.android.vending/com.google.android.finsky.instantapps.PhenotypeUpdateReceiver",
    "com.android.vending/com.google.android.finsky.instantapps.PhenotypeUpdateService",
    # Telemetry / Metrics / Engage
    "com.android.vending/com.google.android.finsky.appcontentservice.engage.AppEngageService",
    "com.android.vending/com.google.android.finsky.appcontentservice.engage.AppEngageServiceV2",
    "com.android.vending/com.google.android.finsky.appcontentservice.engage.broadcastreceiver.EngagePackageActionReceiver",
    "com.android.vending/com.google.android.finsky.apperrors.PlayAppErrorsService",
    "com.android.vending/com.google.android.finsky.enterprisedevicereport.AppStatesService",
    "com.android.vending/com.google.android.finsky.appdoctor.PhoneskyAppDoctorReceiver",
    "com.android.vending/com.google.android.finsky.recoverymode.safeselfupdate.SafeSelfUpdateService",
    "com.android.vending/com.google.android.finsky.emergencyselfupdate.EmergencySelfUpdateService",
    "com.android.vending/com.google.android.finsky.recoverymode.download.impl.RecoveryModeDownloadBroadcastReceiver",
    "com.android.vending/com.google.android.finsky.foregroundcoordinator.impl.ForegroundCoordinatorService",
    "com.android.vending/com.google.android.finsky.autoopen.notification.AutoOpenSchedulerService",
    # Debug / Unused activities
    "com.android.vending/com.google.android.finsky.activities.DebugActivity",
    "com.android.vending/com.google.android.finsky.autoarchivingoptinactivity.AutoArchivingOptInActivity",
    "com.android.vending/com.google.android.finsky.unauthenticated.activity.UnauthenticatedMainActivity",
    "com.android.vending/com.google.android.finsky.accessrestricted.AccessRestrictedActivity",
    "com.android.vending/com.google.android.finsky.marketingoptin.MarketingOptInActivity",
    "com.android.vending/com.google.android.finsky.screenshotsactivity.ScreenshotsActivityV2",
    "com.android.vending/com.google.android.finsky.protect.impl.PlayProtectHomeDeepLinkActivity",
    "com.android.vending/com.google.android.finsky.appdiscoveryservice.AppDiscoveryLaunchActivity",
    "com.android.vending/com.google.android.finsky.appdiscoveryservice.AppDiscoveryService",
    "com.android.vending/com.google.android.finsky.packageinstaller.main.AtomicInstallBroadcastReceiverMain",
    "com.android.vending/com.google.android.finsky.packageinstaller.background.AtomicInstallBroadcastReceiverBackground",
    # Widgets (personalized)
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.TravelWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.WatchWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ReadWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.CubesAppWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ShoppingWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ListenWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.FoodWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.SocialWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.GamesWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.ContentForwardWidgetProvider",
    # DSE / Search widgets
    "com.android.vending/com.google.android.finsky.dsehelper.SearchWidgetDseChangeBroadcastReceiver",
    # Setup / Restore
    "com.android.vending/com.google.android.finsky.setup.RestoreServiceV2",
    "com.android.vending/com.google.android.finsky.setup.VpaService",
    "com.android.vending/com.google.android.finsky.setup.RestoreFinishAckedReceiver",
    "com.android.vending/com.google.android.finsky.setup.LauncherConfigurationReceiver",
    "com.android.vending/com.google.android.finsky.setup.dse.impl.DseService",
    "com.android.vending/com.google.android.finsky.setup.PlaySetupServiceV2",
    "com.android.vending/com.google.android.finsky.setup.p2p.PlayP2pRestoreService",
    # Services
    "com.android.vending/com.google.android.finsky.services.MarketCatalogService",
    "com.android.vending/com.google.android.finsky.services.ReviewsService",
    "com.android.vending/com.google.android.finsky.services.DetailsService",
    "com.android.vending/com.google.android.finsky.services.LicensingService",
    "com.android.vending/com.google.android.finsky.licensingservice.background.BackgroundLicensingService",
    "com.android.vending/com.google.android.finsky.services.PlayGearheadService",
    "com.android.vending/com.google.android.finsky.services.PackageUpdateService",
    "com.android.vending/com.google.android.finsky.services.AdIdListener",
    "com.android.vending/com.google.android.finsky.zapp.PlayModuleService",
    "com.android.vending/com.google.android.finsky.installapi.PlayInstallService",
    "com.android.vending/com.google.android.finsky.prewarmservice.PrewarmService",
    "com.android.vending/com.google.android.finsky.shellservice.ProdShellService",
    "com.android.vending/com.google.android.finsky.shellservice.RootOnlyProdCommandReceiver",
    "com.android.vending/com.google.android.finsky.externalreferrer.GetInstallReferrerService",
    "com.android.vending/com.google.android.finsky.multiusercoordinator.MultiUserCoordinatorService",
    "com.android.vending/com.google.android.finsky.crossprofileinstallerservice.CrossProfileInstallerService",
    "com.android.vending/com.google.android.finsky.crossprofile.ProfileStateService",
    "com.android.vending/com.google.android.finsky.notification.impl.NotificationReceiver",
    "com.android.vending/com.google.android.finsky.notification.impl.NotificationSettingsBroadcastReceiver",
    "com.android.vending/com.google.android.finsky.downloadserviceclient.DownloadServiceReceiver",
    "com.android.vending/com.google.android.finsky.downloadserviceclient.DownloadServiceBackgroundReceiver",
    "com.android.vending/com.google.android.finsky.downloadservice.DownloadNotificationActionReceiver",
    "com.android.vending/com.google.android.finsky.downloadservice.DownloadRetryActionReceiver",
    "com.android.vending/com.google.android.finsky.ageverification.service.AgeSignalsService",
    "com.android.vending/com.google.android.finsky.multiinstall.MultiInstallActivity",
    "com.android.vending/com.google.android.finsky.settings.GaiaAuthActivity",
    "com.android.vending/com.google.android.finsky.tos.TosActivity",
    "com.android.vending/com.google.android.finsky.tos.TosAckedReceiver",
    "com.android.vending/com.google.android.finsky.userlanguages.LocaleChangedReceiver",
    "com.android.vending/com.google.android.finsky.userlanguages.ApplicationLocaleChangedReceiver",
    "com.android.vending/com.google.android.finsky.accounts.impl.AccountsChangedReceiver",
    "com.android.vending/com.google.android.finsky.simhandler.SimStateReceiver",
    "com.android.vending/com.google.android.finsky.billing.iab.InAppBillingService",
    "com.android.vending/com.google.android.finsky.billing.legacyservice.BillingAccountService",
    "com.android.vending/com.google.android.finsky.addtohomescreen.AddToHomeScreenSettingProvider",
    "com.android.vending/com.google.android.finsky.devicemanagement.receiver.DeviceManagementReceiver",
    "com.android.vending/com.google.android.finsky.permissionrevocation.UnusedAppRestrictionsBackportService",
    "com.android.vending/com.google.android.finsky.appswidgetmanager.impl.AppWidgetPinnedReceiver",
    "com.android.vending/com.google.android.finsky.billing.acquire.SheetUiBuilderHostActivity",
    "com.android.vending/com.google.android.finsky.phoenix.ACQUIRE"
)
$psDisabled = 0
foreach ($comp in $playStoreDisable) {
    $res = MmuAdbSu "pm disable $comp"
    if ($res -match "new state: disabled") { $psDisabled++ }
}
Ok "$psDisabled / $($playStoreDisable.Count) componentes Play Store deshabilitados"

# Settings: deshabilitar auto-update
$psSettings = @(
    "global auto_update_apps 0",
    "global auto_update_apps_over_wifi_only 0",
    "global package_verifier_enable 0",
    "global play_store_auto_update 0"
)
foreach ($s in $psSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Auto-update deshabilitado (4 settings globales)"

# Mantener componentes esenciales de Play Store
$psKeep = @(
    "com.android.vending/com.android.vending.AssetBrowserActivity",
    "com.android.vending/com.google.android.finsky.activities.MainActivity",
    "com.android.vending/com.google.android.finsky.install.InstallService",
    "com.android.vending/com.google.android.finsky.installapi.PlayInstallService",
    "com.android.vending/com.google.android.finsky.installservice.InstallService",
    "com.android.vending/com.google.android.finsky.protect.ExternalPlayProtectHomeEntryPoint"
)
foreach ($comp in $psKeep) {
    MmuAdbSu "pm enable $comp" | Out-Null
}
Ok "Componentes esenciales Play Store mantenidos (incluye AssetBrowserActivity - icono launcher)"

# ---------------------------------------------------------------------------
# 12. Settings anti-ads
# ---------------------------------------------------------------------------
Step "12. Settings anti-ads"

$settings = @(
    "secure show_app_recommendations 0",
    "secure enable_suggestions 0",
    "secure show_search_app_suggestions 0",
    "global enable_advertising_id_collection 0",
    "global search_assist_enabled 0",
    "secure assistant_enabled 0"
)
foreach ($s in $settings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Settings aplicados"

# ---------------------------------------------------------------------------
# 13. Animaciones = 0
# ---------------------------------------------------------------------------
Step "13. Animaciones"

$animSettings = @(
    "global window_animation_scale 0.0",
    "global transition_animation_scale 0.0",
    "global animator_duration_scale 0.0"
)
foreach ($s in $animSettings) {
    MmuAdb "settings put $s" | Out-Null
}
Ok "Animaciones deshabilitadas"

# ---------------------------------------------------------------------------
# 14. Hosts anti-ads
# ---------------------------------------------------------------------------
Step "14. Hosts anti-ads" "217 dominios (Google auth desbloqueado)"

if (Test-Path $HostsFile) {
    $port = $info.adb_port
    $standalone = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
    & $standalone connect "127.0.0.1:$port" 2>&1 | Out-Null
    Start-Sleep 3
    & $standalone -s "127.0.0.1:$port" push $HostsFile /data/local/tmp/hosts.antiad 2>&1 | Out-Null
    MmuAdbSu "mount -o rw,remount /system" | Out-Null
    MmuAdbSu "cp /data/local/tmp/hosts.antiad /system/etc/hosts && chmod 644 /system/etc/hosts" | Out-Null
    MmuAdbSu "mount -o ro,remount /system" | Out-Null
    Ok "Hosts actualizado"
} else {
    Warn "Hosts file no encontrado: $HostsFile"
}

# ---------------------------------------------------------------------------
# 15. Boot script persistente
# ---------------------------------------------------------------------------
Step "15. Script de boot" "Auto-apply en cada arranque"

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
$port = $info.adb_port
$standalone = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
& $standalone -s "127.0.0.1:$port" push $localBootScript /data/local/tmp/boot_opt.sh 2>&1 | Out-Null
MmuAdbSu "chmod 755 /data/local/tmp/boot_opt.sh" | Out-Null
Ok "Script en /data/local/tmp/boot_opt.sh"

# ---------------------------------------------------------------------------
# 16. vm_config.json
# ---------------------------------------------------------------------------
Step "16. vm_config.json" "vsync off, frame_rate 30"

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
# 17. Verificacion final
# ---------------------------------------------------------------------------
Step "17. Verificacion final"

Write-Host ""
$bootCompleted = (MmuAdb "getprop sys.boot_completed").Trim()
$zygoteState   = (MmuAdb "getprop init.svc.zygote_secondary").Trim()
$heapStart     = (MmuAdb "getprop dalvik.vm.heapstartsize").Trim()
$heapGrowth    = (MmuAdb "getprop dalvik.vm.heapgrowthlimit").Trim()
$logdSize      = (MmuAdb "getprop persist.logd.size").Trim()
$latch         = (MmuAdb "getprop debug.sf.latch_unsignaled").Trim()

Write-Host "  sys.boot_completed    : $bootCompleted"
Write-Host "  zygote_secondary      : $zygoteState"
Write-Host "  heapstartsize         : $heapStart"
Write-Host "  heapgrowthlimit       : $heapGrowth"
Write-Host "  logd.size             : $logdSize"
Write-Host "  latch_unsignaled      : $latch"

$disabled = (MmuAdb "pm list packages -d").Trim()
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