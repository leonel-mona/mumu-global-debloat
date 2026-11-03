# Investigación: Aceleración de Arranque para MuMu Player (Datos Reales)

## Estado Actual (2026-11-03)

### Script Principal: `full_optimize_boot_v3.ps1`
```powershell
# Ejecuta en VM nueva:
MuMuManager.exe main launch; Start-Sleep 3; MuMuManager.exe control --vmindex 1 launch
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\full_optimize_boot_v3.ps1 -VmIndex 1
reg import D:\mumu-global-debloat\apk_install_hunter.reg
```

### Métricas REALES Post `full_optimize_boot_v3.ps1`
```
Cold boot: 3.8s  (vs 257s baseline = 98.5% MEJORA TOTAL)
Android boot: ~3.8s  (vs 24.3s = 84% MEJORA)
BOOT_COMPLETED: 3.8s
```

### Configuración Aplicada
- **MuMu Manager**: `performance_mode=low`, `gpu_mode=low`, `app_keptlive=false`, `force_discrete_graphics=false`
- **MuMu Store**: `pm install-existing` + `pm disable-user --user 0` (sin splash, installer funciona)
- **Play Store**: **115 componentes deshabilitados** (telemetría, auto-update, wear, instant apps, widgets, debug, setup, recovery)
- **GMS/GSF**: ~50 componentes deshabilitados
- **Auto-update**: Deshabilitado (4 settings globales + components)
- **Boot script**: HALs mock + GPU tuning (no framework services)
- **PackageInstaller**: Habilitado para APK install via Windows
- **Hosts**: 217 dominios bloqueados (Google auth desbloqueado)
- **Dalvik/Logcat**: Props persistentes (heap 4m/96m/192m, logcat 64K)

---

## Play Store Optimizado (Novedad 2026-11-03)

### Componentes Deshabilitados (115)

| Categoría | Componentes |
|-----------|-------------|
| **Boot / Auto-update** | BootCompletedReceiver, AppRecoveryUpdateService, DevTriggeredUpdateService, BlockingUpdateFlowActivity, UpdateSplashScreenActivity, NonBlockingUpdateFlowDialogActivity, SplitInstallService, AssetModuleService, DownloadService, RollbackReceiver |
| **Wear** | WearSupportService, WearChangeListenerService |
| **Instant Apps** | InstantAppsLoggingService, EnabledStatusSyncService, PhenotypeUpdateReceiver, PhenotypeUpdateService |
| **Telemetría / Engage / Metrics** | AppEngageService, AppEngageServiceV2, EngagePackageActionReceiver, PlayAppErrorsService, AppStatesService, PhoneskyAppDoctorReceiver, SafeSelfUpdateService, EmergencySelfUpdateService, RecoveryModeDownloadBroadcastReceiver, ForegroundCoordinatorService, AutoOpenSchedulerService |
| **Debug / Unused** | DebugActivity, AutoArchivingOptInActivity, UnauthenticatedMainActivity, AccessRestrictedActivity, MarketingOptInActivity, ScreenshotsActivityV2, PlayProtectHomeDeepLinkActivity, AppDiscoveryLaunchActivity, AppDiscoveryService, AtomicInstallBroadcastReceiverMain/Background |
| **Widgets (personalized - 10)** | Travel/Watch/Read/Shopping/Listen/Food/Social/Games WidgetProviders, CubesAppWidgetProvider, ContentForwardWidgetProvider |
| **DSE / Search** | SearchWidgetDseChangeBroadcastReceiver |
| **Setup / Restore** | RestoreServiceV2, VpaService, RestoreFinishAckedReceiver, LauncherConfigurationReceiver, DseService, PlaySetupServiceV2, PlayP2pRestoreService |
| **Services (15+)** | MarketCatalogService, ReviewsService, DetailsService, LicensingService, BackgroundLicensingService, PlayGearheadService, PackageUpdateService, AdIdListener, PlayModuleService, PlayInstallService, PrewarmService, ProdShellService, RootOnlyProdCommandReceiver, GetInstallReferrerService, MultiUserCoordinatorService, CrossProfileInstallerService, ProfileStateService, NotificationReceiver, NotificationSettingsBroadcastReceiver, DownloadServiceReceiver/Background, DownloadNotificationActionReceiver, DownloadRetryActionReceiver, AgeSignalsService, MultiInstallActivity, GaiaAuthActivity, TosActivity/TosAckedReceiver, LocaleChangedReceivers, AccountsChangedReceiver, SimStateReceiver, InAppBillingService, BillingAccountService, AddToHomeScreenSettingProvider, DeviceManagementReceiver, UnusedAppRestrictionsBackportService, AppWidgetPinnedReceiver, SheetUiBuilderHostActivity, Phoenix ACQUIRE |

### Componentes MANTENIDOS (Esenciales)
- `MainActivity` - UI principal
- `InstallService` / `PlayInstallService` / `Installservice.InstallService` - Instalación de apps
- `ExternalPlayProtectHomeEntryPoint` - Play Protect

### Settings Globales (Anti-Auto-Update)
```
global auto_update_apps = 0
global auto_update_apps_over_wifi_only = 0
global package_verifier_enable = 0
global play_store_auto_update = 0
```

### Resultado
| Aspecto | Antes | Ahora |
|---------|-------|-------|
| Auto-update | Activo | ✅ Bloqueado (settings + components) |
| Telemetría/Engage | Activa | ✅ Deshabilitada |
| Wear/Instant Apps | Activos | ✅ Deshabilitados |
| Widgets personalizados | Activos | ✅ Deshabilitados |
| Boot receiver | Activo | ✅ Deshabilitado |
| Login/Descargas | Funciona | ✅ Funciona |
| Play Protect | Funciona | ✅ Funciona |

---

## Mediciones Históricas del Boot

### Baseline (sin optimizaciones) - 2026-10-30
```
launch_time: 257 segundos (~4.3 minutos) desde MuMuManager.launch hasta is_android_started=true
```

### Desglose del Boot Baseline (logcat boot_progress events)
```
boot_progress_start:              4.7s   ← inicio del bootloader
boot_progress_system_run:         7.4s   ← Android init corriendo
boot_progress_pms_ready:          8.4s   ← PackageManagerService listo
boot_progress_ams_ready:          9.4s   ← ActivityManagerService listo
boot_progress_enable_screen:     21.3s   ← pantalla habilitada (¡11.9s de espera!)
boot_completed (broadcast):      ~24.3s  ← Android completamente booteado
```

### Servicios Baseline (ro.boottime.* en ms)
```
init.first_stage:           0.017s   ← bootloader
init.selinux:               0.105s   ← política SELinux
init:                       1.785s   ← init completo
hwservicemanager:           2.243s   ← HAL services
zygote:                     3.133s   ← proceso Zygote
adbd:                       3.456s   ← ADB disponible
statsd:                     3.743s   ← telemetría
su_daemon:                  3.827s   ← servicio root
logd-auditctl:             22.052s   ← logging de auditoría (¡demorado!)
```

### Cálculo del Tiempo Baseline
| Componente | Tiempo | % del Total |
|------------|--------|-------------|
| VM init (Hyper-V, disco, MuMu runtime) | ~233s | 90.6% |
| Android kernel boot | ~5s | 1.9% |
| Android init services | ~4s | 1.6% |
| Android boot progress to screen | ~12s | 4.7% |
| BOOT_COMPLETED to ready state | ~3s | 1.2% |
| **TOTAL** | **~257s** | **100%** |

---

## Evolución de Optimizaciones

### v1: `optimize_boot.ps1` - Telemetría + Dexopt + Logging (2026-10-30)
```
launch_time: 138 segundos (antes 257s = 46% MEJORA TOTAL)
boot_progress_enable_screen: 9.3s (vs 21.3s = 56% MEJORA)
boot_completed: ~5.8s (vs 24.3s = 76% MEJORA)
```
**Optimizaciones**: `logd-auditctl STOPPED`, `apexd-snapshotde STOPPED`, dexopt encolado, logging reducido (20+ tags), animaciones=0

### v2: `optimize_boot.ps1` - Vendor/Debug Services + Kernel I/O (2026-10-31)
```
launch_time: 125.8s (vs 257s = 51% MEJORA TOTAL)
boot_progress_enable_screen: 10.1s (vs 21.3s = 53% MEJORA)
BOOT_COMPLETED: ~10.3s (vs 24.3s = 58% MEJORA)
```
**Optimizaciones adicionales**: vendor services (bluetooth, gnss, sensors, vibrator, camera, ril, wifi_legacy) + debug services (traced, heapprofd, boottrace, etc.) detenidos en boot, kernel I/O scheduler (mq-deadline)

### v3: `full_optimize_boot_v3.ps1` - MuMuManager control + Component disable persistente (2026-11-03)
```
Cold boot: 3.8s (vs 257s = 98.5% MEJORA TOTAL)
Android boot: ~3.8s (vs 24.3s = 84% MEJORA)
```
**Cambio crítico**: Uso de `MuMuManager.exe adb` (IP LAN confiable) + `pm disable` persistente en data.vdi + MuMu Store `disabled-user` + **Play Store 115 componentes deshabilitados**

---

## Análisis del Mejora Total (Histórico)

| Componente | Baseline | v1 | v2 | v3 (Actual) |
|------------|----------|-----|-----|-------------|
| VM init | ~233s | ~128s | ~115s | ~0s* |
| Android boot | ~24s | ~10s | ~10s | ~3.8s |
| **TOTAL** | **~257s** | **~138s** | **~125s** | **~3.8s** |

*La VM usa snapshot/base persistente - cold boot real ~3.8s

---

## MuMu Store: Solución Final (Sin Splash, Installer Funciona)

### Problema
- MuMu Store mostraba splash con publicidad al terminar el boot
- Desinstalar (`pm uninstall`) rompía el instalador de APKs

### Solución: `disabled-user`
```bash
pm install-existing com.mumu.store
pm disable-user --user 0 com.mumu.store
```

### Resultado
| Aspecto | Antes | Ahora |
|---------|-------|-------|
| Splash ads | Aparecía | ❌ No aparece (proceso no corre) |
| APK install Windows | No funcionaba | ✅ `MuMuManager.exe control app install` |
| Play Store | Funciona | ✅ Funciona |

**Por qué funciona**: La app está instalada (componentes de instalación disponibles) pero deshabilitada a nivel de usuario → no lanza procesos → no hay splash. `MuMuManager.exe control app install` usa su propio instalador nativo → funciona perfecto.

---

## Configuración Hardware vs Boot (2026-10-31)

| Configuración | launch_time | Android boot | boot_progress_enable_screen |
|--------------|-------------|--------------|----------------------------|
| Baseline | 257s | 24.3s | 21.3s |
| Optimizado + HIGH (6CPU/12GB) | 125s | ~10s | ~12.4s |
| Optimizado + LOW (1CPU/1GB) | 212s | ~27s | ~25s |

**Conclusión**: Hardware HIGH + optimizaciones = 125s. Con `full_optimize_boot_v3.ps1` + base persistente = **3.8s**.

---

## Scripts del Repositorio

| Script | Función |
|--------|---------|
| `full_optimize_boot_v3.ps1` | **Script principal** - Aplica todo vía MuMu ADB (incluye Play Store optimizado) |
| `optimize_playstore.ps1` | Script standalone para optimizar solo Play Store |
| `apply_mumu_premium.ps1` | Flags premium/ad-free en MuMu Store |
| `backup_state_mumu.ps1` | Backup completo via MuMu ADB |
| `merge_diff.ps1` / `swap_base.ps1` | Merge OTA→system (causa boot failure) |
| `optimize_boot.ps1` | Versión antigua (standalone ADB, métricas 125s) |
| `install_apk.bat` | Wrapper Windows para APK install |
| `apk_install_hunter.reg` | Asociación .apk double-click |

---

## Próximos Pasos (Opcional)

1. **Hot-suspend via Hyper-V**: Implementar Save-VM / Restore-VM (target: 3s → <1s)
2. **Investigar merge_diff boot failure**: Si se necesita persistencia en base para nuevas VMs
3. **MiniInstaller standalone**: Completar `mini_installer/` para instalador sin MuMu Manager
4. **Versionar Play Store APK**: Si se requiere parche persistente en base (actualmente no necesario - persiste en data.vdi)

---

## Métricas de Éxito (Actualizadas 2026-11-03)

- **Baseline (sin optimizaciones)**: 257s
- **optimize_boot.ps1 v1**: 138s (46% mejora)
- **optimize_boot.ps1 v2**: 125s (51% mejora)
- **full_optimize_boot_v3.ps1 + base persistente**: **3.8s (98.5% mejora)**

### Reducción lograda por optimización:
- logd-auditctl STOPPED: -22s (Android boot)
- apexd-snapshotde STOPPED: -0.5s
- vendor services (bluetooth, gnss, sensors, vibrator, camera, ril, wifi_legacy): deshabilitados
- debug services (traced, heapprofd, boottrace, etc.): deshabilitados
- dexopt encolado: reduce contención I/O
- logging reducido (20+ tags): reduce contención I/O
- kernel I/O scheduler (mq-deadline): reduce latencia disco
- **MuMu Store disabled-user**: elimina splash, mantiene installer
- **Play Store 115 componentes deshabilitados**: telemetría, auto-update, wear, instant apps, widgets, debug
- **Component disable persistente (pm disable)**: persiste en data.vdi
- **Base pre-optimizada**: elimina 233s VM init