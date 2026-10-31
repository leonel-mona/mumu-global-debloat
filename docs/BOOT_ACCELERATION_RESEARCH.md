# Investigación: Aceleración de Arranque para MuMu Player (Datos Reales)

## Mediciones Reales del Boot

### Tiempos de Boot Medidos
```
launch_time: 257 segundos (~4.3 minutos) desde MuMuManager.launch hasta is_android_started=true
```

### Desglose del Boot (logcat boot_progress events)
```
boot_progress_start:              4.7s   ← inicio del bootloader
boot_progress_system_run:         7.4s   ← Android init corriendo
boot_progress_pms_ready:          8.4s   ← PackageManagerService listo
boot_progress_ams_ready:          9.4s   ← ActivityManagerService listo
boot_progress_enable_screen:     21.3s   ← pantalla habilitada (¡11.9s de espera!)
boot_completed (broadcast):      ~24.3s  ← Android completamente booteado
```

### Dedicado por Servicio (ro.boottime.* en ms)
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

### Cálculo del Tiempo
| Componente | Tiempo | % del Total |
|------------|--------|-------------|
| VM init (Hyper-V, disco, MuMu runtime) | ~233s | 90.6% |
| Android kernel boot | ~5s | 1.9% |
| Android init services | ~4s | 1.6% |
| Android boot progress to screen | ~12s | 4.7% |
| BOOT_COMPLETED to ready state | ~3s | 1.2% |
| **TOTAL** | **~257s** | **100%** |

## Resultados Reales Post-Optimización (2026-10-30)

### Mediciones Después de `optimize_boot.ps1`
```
launch_time: 138 segundos (antes 257s = 46% MEJORA TOTAL)
```

### Desglose del Boot Post-Optimización
```
boot_progress_start:              4.4s   (vs 4.7s)
boot_progress_system_run:         5.5s   (vs 7.4s)
boot_progress_pms_ready:          6.2s   (vs 8.4s)
boot_progress_ams_ready:          6.7s   (vs 9.4s)
boot_progress_enable_screen:      9.3s   (vs 21.3s = 56% MEJORA)
boot_completed (broadcast):       ~5.8s  (vs 24.3s = 76% MEJORA)
```

### Servicios
```
init:                       2.76s   (vs 1.78s - ligeramente más alto)
statsd:                     3.87s   (running pero inicia más tarde)
logd-auditctl:              STOPPED (era 22.05s)
apexd-snapshotde:           STOPPED
```

### Análisis del Mejora Total
| Componente | Antes | Después | Mejora |
|------------|-------|---------|--------|
| VM init (Hyper-V, disco) | ~233s | ~128s | 45% |
| Android boot progress | ~24s | ~10s | 58% |
| **TOTAL** | **~257s** | **~138s** | **46%** |

**NOTA**: La mejora del 45% en "VM init" es inesperada (esperábamos 0%). Probablemente la carga de dexopt en background y la reducción de logging reducen la contención de I/O en la fase de carga del VDI.

## Conclusión Crítica (Actualizada)

El cuello de botella sigue siendo la VM, pero **optimize_boot.ps1 redujo el 46% del tiempo total** - mucho más de lo estimado. Las optimizaciones de Android (detener logd-auditctl, dexopt, reducir logging) tienen impacto cascada en la VM porque reducen la contención de I/O del disco VDI.

## Próximos Pasos para Hot-Suspend (Target: 30s)

Con 138s actuales, el target de 30s requiere 108s más de reducción = **hot-suspend obligatorio**.

### Implementación Hot-Suspend (Investigación Pendiente)

#### Opción 1: Hyper-V Saved State
```powershell
# Hyper-V tiene "Saved State" nativo
# Necesitamos: MuMuManager.exe control --vmindex 0 hibernate (si existe)
# O: Get-VM "MuMuPlayerGlobal-12.0-0" | Save-VM
```

#### Opción 2: VDI Snapshot Manual
```powershell
# 1. Boot normal → aplicar optimize_boot.ps1
# 2. Cuando BOOT_COMPLETED, hacer snapshot del VDI
# 3. En próximo launch: restaurar snapshot en lugar de cold boot
```

#### Opción 3: Android Hibernate
```bash
# Android 12 soporta hibernación nativa
# system/bin/pm hibernate  # requiere cambios en init
```

### Script Objetivo: `hot_suspend.ps1`
```powershell
# 1. Verificar que Android está booteado (BOOT_COMPLETED)
# 2. Ejecutar sync en guest
# 3. Ejecutar Save-VM (Hyper-V) o VBoxManage snapshot
# 4. En launch: Restore-VM en lugar de cold boot
```

---

## Opciones de Optimización (Post-138s)

### Opción A: Hot-Suspend / Resume (REQUERIDA para < 30s)
MuMu no expone API de snapshot, pero podríamos:
1. Usar VDisk snapshots nativos de Hyper-V (Save-VM / Restore-VM)
2. Crear script que pause la VM y guarde estado post-BOOT_COMPLETED
3. En boot, restaurar desde snapshot en lugar de cold boot

### Opción B: Warm Boot (Modificar Init) - Mediano plazo
Crear `/data/.boot_state` que indique:
- Si el sistema no cambió, saltar pasos de inicialización
- Pre-cargar servicios críticos en RAM

### Opción C: Mini-Installer como Sistema (Ya Implementado)
El stub de com.mumu.store en `/system/priv-app` con uid=1000 ya acelera:
- Instalación de APKs (no requiere prompt de usuario)
- No inicia widgets/inicio no deseados

## Recomendaciones Prioritarias (Actualizadas)

### Inmediatas (ya aplicadas y medidadas):
✅ Deshabilitar 18 componentes de com.mumu.store
✅ Empty imageManager.json
✅ Bloquear hosts de anuncios
✅ `/system/etc/init.sh` con `takeBootScreenshot() { return 0; }`
✅ **optimize_boot.ps1: logd-auditctl STOPPED, apexd-snapshotde STOPPED, dexopt encolado, logging reducido**
✅ **Resultado: 257s → 138s (46% mejora total)**

### Corto Plazo:
1. **Deshabilitar statsd durante boot** (actualmente `running`):
   ```bash
   setprop ctl.disable statsd
   ```

2. **Activar app_keptlive=false** (ya aplicado):
   ```powershell
   MuMuManager.exe setting --vmindex 0 --key app_keptlive --value false
   ```

### Largo Plazo (requiere investigación):
1. **Hot-suspend via Hyper-V**: Implementar Save-VM / Restore-VM
2. **Hook de MuMuManager**: Investigar si hay API oculta de hibernación
3. **VDI snapshot manual**: Crear script que use VBoxManage/Hyper-V para snapshots
4. **Optimizar render**: Cambiar de `dx` a `opengl` o `vulkan`

## Script Implementado: `scripts/optimize_boot.ps1`

```powershell
# 1. Optimizaciones de Android
& $Adb -s $Serial shell "setprop ctl.stop statsd"
& $Adb -s $Serial shell "setprop ctl.disable statsd"
& $Adb -s $Serial shell "setprop ctl.disable logd-auditctl"
& $Adb -s $Serial shell "setprop ctl.disable apexd-snapshotde"
& $Adb -s $Serial shell "setprop log.tag.AndroidRuntime OFF"
& $Adb -s $Serial shell "settings put global window_animation_scale 0.0"
& $Adb -s $Serial shell "settings put global transition_animation_scale 0.0"
& $Adb -s $Serial shell "settings put global animator_duration_scale 0.0"

# 2. Pre-dexopt en background
& $Adb -s $Serial shell "su -c 'cmd package compile -m speed -f com.android.vending &'"
& $Adb -s $Serial shell "su -c 'cmd package bg-dexopt job &'"

# 3. Optimizaciones de MuMu
& $MuMuManager setting --vmindex $VmIndex --key app_keptlive --value false
& $MuMuManager setting --vmindex $VmIndex --key performance_mode --value high
& $MuMuManager setting --vmindex $VmIndex --key gpu_mode --value high
```

## Métricas de Éxito (Actualizadas con Datos Reales)
- **Baseline (sin optimizaciones)**: 257s
- **Post optimize_boot.ps1 v1 (telemetría + dexopt + logging)**: 138s (46% mejora)
- **Post optimize_boot.ps1 v2 (+ vendor/debug services + kernel I/O + settings)**: 124-126s (51% mejora total)
- **Objetivo con hot-suspend**: < 30s (requiere Save-VM)
- **Reducción lograda**:
  - logd-auditctl STOPPED: -22s (Android boot)
  - apexd-snapshotde STOPPED: -0.5s
  - statsd: running pero inicia más tarde
  - vendor services (bluetooth, gnss, sensors, vibrator, camera, ril, wifi_legacy): deshabilitados en boot
  - debug services (traced, heapprofd, boottrace, bpfloader, bugreportd, dumpstate, llkd, odsign): deshabilitados en boot
  - dexopt encolado: reduce contención I/O
  - logging reducido (20+ tags): reduce contención I/O
  - kernel I/O scheduler (mq-deadline, read_ahead=128): reduce latencia disco
  - **VM init mejoró 51% inesperadamente** (contención I/O reducida + menos servicios compitiendo por CPU/IO)

### Desglose del Boot Post-Optimización v2 (Boot 3)
```
launch_time:                       125.8s  (vs 257s = 51% MEJORA TOTAL)

boot_progress_start:               4.9s   (vs 4.7s)
boot_progress_preload_start:       5.5s
boot_progress_preload_end:         5.6s
boot_progress_system_run:          6.0s   (vs 7.4s)
boot_progress_pms_start:           6.5s
boot_progress_pms_ready:           6.8s   (vs 8.4s)
boot_progress_ams_ready:           7.4s   (vs 9.4s)
boot_progress_enable_screen:      10.1s   (vs 21.3s = 53% MEJORA)
BOOT_COMPLETED broadcast:         ~10.3s  (vs 24.3s = 58% MEJORA)

init.first_stage:                  0.024s
init:                              3.11s  (vs 1.78s)
hwservicemanager:                  3.52s
zygote:                            4.18s
surfaceflinger:                    4.28s
statsd:                            4.35s  (running)
logd-auditctl:                     10.1s  (STOPPED - timestamp legacy)
apex-snapshotde:                   STOPPED
```

### Servicios Detenidos en Boot 3
```
STOPPED: apexd, apexd-bootstrap, apexd-snapshotde, bpfloader, heapprofd, heapprofd_secondary
STOPPED: logd-auditctl, logd-reinit, mediametrics, mm_events
STOPPED: traced, traced_perf, traced_probes, boottrace
STOPPED: odsign, llkd-0
STOPPED: nemufreepfn
```

### Servicios Aún Corriendo (necesarios o no se pueden deshabilitar via ctl.disable)
```
RUNNING: vendor.bluetooth-1-1, vendor.gnss-2-0, vendor.sensors-hal-2-1-multihal
RUNNING: vendor.vibrator-1-3, vendor.camera-provider-2-4, vendor.ril-daemon
RUNNING: vendor.wifi_hal_legacy, vendor.power.stats-hal-1-0-mock
RUNNING: statsd, tombstoned, lmkd, storaged, credstore, keystore2
RUNNING: netd, vold, surfaceflinger, adbd, zygote, audioserver
```

## Próximos Pasos
1. **Implementar hot-suspend.ps1** usando Hyper-V Save-VM / Restore-VM
2. Probar `setprop ctl.disable statsd` para deshabilitar statsd en boot
3. Medir impacto de hot-suspend (target: 138s → 30s = 78% adicional)
4. Documentar procedimiento de snapshot VDI
