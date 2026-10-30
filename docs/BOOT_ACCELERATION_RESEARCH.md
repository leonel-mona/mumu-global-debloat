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

## Conclusión Crítica

**El cuello de botella NO es Android, es la VM.** El 90% del tiempo se gasta en:
1. Inicialización de Hyper-V
2. Carga del disco VDI (2.2GB, aunque sparse)
3. Inicialización del runtime de MuMu
4. Setup de red (NAT + ADB port-forward)
5. Carga de la UI del emulador (renderer dx, surface flinger)

## Análisis de cada Fase

### Fase 1: VM Hyper-V Init (~200-220s)
- Hypervisor carga el kernel x86_64
- Kernel monta /system desde VDI readonly
- Carga de módulos virtuales (nEMU)
- **Posible optimización**: Hot-suspend/hibernation de VM

### Fase 2: Android Boot (~24s)
- `boot_progress_enable_screen` toma 11.9s (principal gasto)
- STATS y audit logging tardan mucho
- **Ya deshabilitamos**: 18 componentes de com.mumu.store

### Fase 3: MuMu Runtime (~13s)
- Renderer inicializa
- Red se configura
- ADB se conecta
- Frontend muestra pantalla

## Opciones de Optimización Vi

[...continúa en el archivo completo...]

## Opciones de Optimización

### Opción A: Hot-Suspend / Resume (RECOMENDADA)
MuMu no expone API de snapshot, pero podríamos:
1. Usar VDisk snapshots nativos de VirtualBox/Hyper-V
2. Crear script que pause la VM y guarde estado
3. En boot, restaurar desde snapshot en lugar de cold boot

### Opción B: Warm Boot (Modificar Init)
Crear `/data/.boot_state` que indique:
- Si el sistema no cambió, saltar pasos de inicialización
- Pre-cargar servicios críticos en RAM

### Opción C: Mini-Installer como Sistema (Ya Implementado)
El stub de com.mumu.store en `/system/priv-app` con uid=1000 ya acelera:
- Instalación de APKs (no requiere prompt de usuario)
- No inicia widgets/inicio no deseados

## Recomendaciones Prioritarias

### Inmediatas (ya aplicadas):
✅ Deshabilitar 18 componentes de com.mumu.store
✅ Empty imageManager.json
✅ Bloquear hosts de anuncios
✅ `/system/etc/init.sh` con `takeBootScreenshot() { return 0; }`

### Corto Plazo:
1. **Deshabilitar statsd durante boot**:
   ```bash
   stop statsd
   ```

2. **Reducir logging de auditoría**:
   ```bash
   setprop log.tag.AndroidRuntime OFF
   ```

3. **Activar app_keptlive=false** (ya aplicado):
   ```powershell
   MuMuManager.exe setting --vmindex 0 --key app_keptlive --value false
   ```

### Largo Plazo (requiere investigación):
1. **Hook de MuMuManager para hot-suspend**: Investigar si hay API oculta
2. **VDI snapshot manual**: Crear script que use VBoxManage para snapshots
3. **Optimizar render**: Cambiar de `dx` a `opengl` o `vulkan`

## Script Propuesto: `optimize_boot.ps1`

```powershell
# 1. Optimizaciones de Android
& $adb shell "su -c 'stop statsd'"
& $adb shell "su -c 'stop logd-auditctl'"
& $adb shell "setprop persist.sys.ooui.enable false"
& $adb shell "settings put global window_animation_scale 0.0"
& $adb shell "settings put global transition_animation_scale 0.0"
& $adb shell "settings put global animator_duration_scale 0.0"

# 2. Optimizaciones de MuMu
& MuMuManager.exe setting --vmindex $VmIndex --key app_keptlive --value false
& MuMuManager.exe setting --vmindex $VmIndex --key performance_mode --value high
& MuMuManager.exe setting --vmindex $VmIndex --key renderer_mode --value opengl

# 3. Post-dexopt (una vez al inicio)
& $adb shell "su -c 'cmd package bg-dexopt job'"
```

## Métricas de Éxito
- **Tiempo objetivo**: < 90 segundos (actual: 257s)
- **Reducción esperada**:
  - Statsd disabled: -5s
  - Renderer optimizado: -10s
  - Dexopt pre-completado: -15s
  - **Total estimado**: 257s → 227s (12% mejora)
  - Con hot-suspend: 257s → 30s (88% mejora) - REQUIERE IMPLEMENTAR

## Próximos Pasos
1. Investigar si MuMu tiene API de sleep/hibernate
2. Probar cambiar renderer de dx a opengl
3. Deshabilitar servicios de telemetría adicionalmente
4. Medir impacto de cada cambio individualmente
