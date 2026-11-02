# 📋 RESULTADO FINAL - MuMu Player Global 12.0 Optimizado

**Fecha:** 02/11/2026  
**VM:** Index 1 — "Android Prueba"  
**Estado:** Estable y funcional

---

## 📊 Métricas de arranque

| Fase | Tiempo | Notas |
|------|--------|-------|
| Antes (baseline) | ~125s | Con barra búsqueda Lawnchair, render Adreno 530 |
| Después (optimizaciones) | ~25-41s | Con optimizaciones seguras aplicadas |
| **Mejora** | **-66% a -80%** | |

---

## ✅ Optimizaciones aplicadas (seguras, sin riesgo de bootloop)

### 1. Dalvik VM tuning (`persist.dalvik.vm.*`)
| Prop | Antes | Después |
|------|-------|---------|
| heapstartsize | 16m | 4m |
| heapgrowthlimit | 192m | 96m |
| heapsize | 512m | 192m |
| heapminfree | 512k | 512k (sin cambio) |
| heapmaxfree | 8m | 8m (sin cambio) |

### 2. Logcat / logging mínimo (`persist.logd.*`)
| Prop | Antes | Después |
|------|-------|---------|
| logd.size | default | 64K |
| logd.size.main | default | 64K |
| logd.size.system | default | 64K |
| logd.size.radio | default | 64K |
| logd.size.events | default | 64K |

### 3. GPU / SurfaceFlinger (runtime)
| Prop | Valor |
|------|-------|
| debug.sf.latch_unsignaled | 1 |
| debug.sf.early_gl_latch | 0 |
| debug.hwui.sync_buffer | 0 |
| debug.hwui.force_dark_mode | 0 |
| debug.sf.hwc_check | 0 |

### 4. Servicios no esenciales (stop)
- `thermal-engine` — parado
- `gatekeeperd` — parado  
- `dumpstate` — parado

### 5. APEX modules deshabilitados
- `android.ext.services` — `pm disable-user --user 0`

### 6. MuMu vm_config.json
- `vsync: false`
- `vertical_sync: false`
- `frame_rate: 30`

---

## 🛡️ Backup completo

**Ubicación:** `D:\MuMuPlayerGlobal-12.0\backup_debloat\state_20261101_232423\`

Incluye:
- settings (secure, global, system) — 306 entradas totales
- packages (all, enabled, disabled, system, user0)
- props (575 líneas)
- hosts.txt
- vm_config.json
- pm_dump de apps críticas (vending, gms, mumu.store, lawnchair, packageinstaller, settings, systemui)
- dumpsys: activity, window, activity activities, activity top, appwidget, wallpaper, input, display, power, battery, connectivity, netd, account, user, jobscheduler, notification, accessibility, meminfo, cpuinfo
- Total: 31 archivos, 3.56 MB

---

## 📁 Scripts creados

| Script | Ruta | Propósito |
|--------|------|-----------|
| `setup_install_handler.ps1` | `D:\mumu-global-debloat\scripts\` | Registrar PackageInstaller como default para .apk |
| `fix_apk_handler.ps1` | `D:\mumu-global-debloat\scripts\` | Reparar APK handler (habilitar PI, deshabilitar XApkInstallerActivity) |
| `merge_diff.ps1` | `D:\mumu-global-debloat\scripts\` | Fusionar ota.vdi → system.vdi |
| `swap_base.ps1` | `D:\mumu-global-debloat\scripts\` | Sustituir base + retirar diff + readonly |
| `reapply_final.ps1` | `D:\mumu-global-debloat\scripts\` | Reaplicar TODO en VM nueva (incluye APK handler fix) |
| `backup_state.ps1` | `D:\mumu-global-debloat\scripts\` | Backup completo del estado de la VM |
| `stop_services_safe.ps1` | `D:\mumu-global-debloat\scripts\` | Parar servicios init no esenciales |
| `optimize_apex_services.ps1` | `D:\mumu-global-debloat\scripts\` | Deshabilitar APEX y servicios mock |
| `phase5_disable_packages.ps1` | `D:\mumu-global-debloat\scripts\` | Deshabilitar paquetes bloat adicionales |
| `wait_boot.ps1` | `D:\mumu-global-debloat\scripts\` | Medir tiempo de boot (Android + ADB) |
| `optimizaciones_seguras.ps1` | `D:\mumu-global-debloat\scripts\` | Aplicar todas las optimizaciones seguras en una VM nueva |
| `remove_search_widget.ps1` | `D:\mumu-global-debloat\scripts\` | Deshabilitar widgets de búsqueda de Play Store |

---

## 🔧 Para aplicar en una VM nueva

```powershell
# 1. Backup del estado actual (antes de tocar nada)
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\backup_state.ps1

# 2. Optimizaciones seguras
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\optimizaciones_seguras.ps1 -VmIndex 1 -Serial "127.0.0.1:XXXX"

# 3. Reaplicación completa (debloat + APK handler + settings)
powershell -ExecutionPolicy Bypass -File D:\mumu-global-debloat\scripts\reapply_final.ps1 -VmIndex 1 -Serial "127.0.0.1:XXXX"

# 4. Para persistir en base (todas las VMs nuevas):
#    - Cerrar MuMu completamente
#    - merge_diff.ps1 -Base ... -Diff ota.vdi -Out system.merged.vdi
#    - swap_base.ps1 -Merged system.merged.vdi
```

---

## ⚠️ Notas importantes

1. **El adb standalone no se conecta** (intenta bind en 0.0.0.0). Usa el integrado:  
   `MuMuManager.exe adb --vmindex 1 --cmd "shell ..."`

2. **Los cambios en `/data` (settings, pm disable) persisten** entre reinicios de Android  
   **Pero NO sobreviven un factory reset de la VM**

3. **Para que todo sea permanente en nuevas VMs:** usar `merge_diff.ps1` + `swap_base.ps1`

4. **La barra de búsqueda de Lawnchair** está deshabilitada a nivel de widgets (SmartspaceAppWidgetProvider off) pero el launcher sigue siendo Lawnchair. Para quitarla completamente se necesitaría reemplazar Lawnchair por otro launcher.

5. **Rollback inmediato:** si algo falla, borrar `ota.vdi` → VM arranca con base original limpia.

---

## ✅ Verificación post-optimización

- [x] VM arranca (Android started = true, player_state = start_finished)
- [x] Home screen Lawnchair activo
- [x] `sys.boot_completed = 1`
- [x] Dalvik heap: 4m / 96m / 192m
- [x] Logcat buffers: 64K
- [x] Latch unsignaled: 1
- [x] MuMu Store deshabilitado
- [x] PackageInstaller como default para .apk
- [x] Hosts file con 217 dominios bloqueados (Google auth desbloqueado)
- [x] Play Store/login funciona