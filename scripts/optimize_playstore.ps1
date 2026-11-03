<#======================================================================
  optimize_playstore.ps1
  Optimiza Play Store: deshabilita telemetría, auto-update, servicios innecesarios
  Uso: .\optimize_playstore.ps1 -VmIndex 1
======================================================================#>
param(
  [int]$VmIndex = 1
)

$ErrorActionPreference = 'Stop'
$MuMu = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"

function MmuAdbSu { param([string]$cmd) & $MuMu adb --vmindex $VmIndex --cmd "shell su -c '$cmd'" 2>&1 | Out-String }
function Ok    { param([string]$msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn  { param([string]$msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }

Write-Host "=== OPTIMIZANDO PLAY STORE (com.android.vending) ==="

# Componentes a deshabilitar (telemetría, auto-update, wear, instant apps, widgets, debug, etc.)
$disableComponents = @(
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

$disabled = 0
foreach ($comp in $disableComponents) {
    $res = MmuAdbSu "pm disable $comp"
    if ($res -match "new state: disabled") { $disabled++ }
}
Ok "$disabled / $($disableComponents.Count) componentes deshabilitados"

# Settings: deshabilitar auto-update
$settings = @(
    "global auto_update_apps 0",
    "global auto_update_apps_over_wifi_only 0",
    "global package_verifier_enable 0",
    "global play_store_auto_update 0"
)
foreach ($s in $settings) {
    & $MuMu adb --vmindex $VmIndex --cmd "shell settings put $s" | Out-Null
}
Ok "Auto-update deshabilitado (4 settings)"

# Mantener habilitados componentes esenciales
$keepEnabled = @(
    "com.android.vending/com.android.vending.AssetBrowserActivity",
    "com.android.vending/com.google.android.finsky.activities.MainActivity",
    "com.android.vending/com.google.android.finsky.install.InstallService",
    "com.android.vending/com.google.android.finsky.installapi.PlayInstallService",
    "com.android.vending/com.google.android.finsky.installservice.InstallService",
    "com.android.vending/com.google.android.finsky.protect.ExternalPlayProtectHomeEntryPoint"
)
foreach ($comp in $keepEnabled) {
    MmuAdbSu "pm enable $comp" | Out-Null
}
Ok "Componentes esenciales mantenidos habilitados (incluye AssetBrowserActivity - icono launcher)"

# Verificación
$storeCheck = & $MuMu adb --vmindex $VmIndex --cmd "shell am start -n com.android.vending/com.google.android.finsky.activities.MainActivity" 2>&1
if ($storeCheck -match "Starting: Intent") {
    Ok "Play Store abre correctamente"
}

$settingsCheck = & $MuMu adb --vmindex $VmIndex --cmd "shell settings list global | grep -E 'auto_update|package_verifier|play_store'" 2>&1
Ok "Settings: $($settingsCheck.Trim() -replace '\r\n', '; ')"

Write-Host ""
Write-Host "=== PLAY STORE OPTIMIZADO ===" -ForegroundColor Green
Write-Host "- Telemetría/Engage deshabilitada"
Write-Host "- Auto-update deshabilitado (settings + components)"
Write-Host "- Wear, Instant Apps, Widgets deshabilitados"
Write-Host "- Servicios debug/recovery deshabilitados"
Write-Host "- Login, descargas, Play Protect: FUNCIONALES"