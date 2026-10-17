# MuMu Player Global 12.0 — Debloat & Anti-ads

Quita los **anuncios de arranque**, la **telemetría** y el **bloat ad-tech** de
MuMu Player Global 12.0 (Android 12), y acelera el arranque — dejando Google Play
totalmente funcional.

Los cambios se **hornean dentro de `system.vdi`** para que sobrevivan aunque el
emulador monte el disco base en modo *read-only* (que es como funciona MuMu 12 por
defecto). No hay que hacer root cada vez ni tocar el sistema en caliente.

---

## Qué elimina / arregla

### Dentro de Android (`/system`)
| Paquete | Qué es |
|---|---|
| `com.mumu.store_overseas` | MuMu Store (promos, widgets, comercio) |
| `com.mumu.acc_overseas` | "Booster"/VPN + SDK Sentry |
| `com.nemu.oaidmanager` | OAID (ID publicitario) |

Se renombran a `*.apk.off` (no se borran directorios: es reversible y no rompe el
selector de apps del sistema).

Además se reemplaza `/system/etc/hosts` por una lista anti-anuncios (dominios de
NetEase/MuMu → `0.0.0.0`).

### En el host de Windows
- **Splash sin anuncios**: se vacía la caché de creatividades
  (`%APPDATA%\Netease\MuMuPlayerGlobal\data\startupImage`) y se bloquean los
  endpoints que sirven campañas de arranque.
- **Telemetría** bloqueada en el `hosts` de Windows (shence, sentry, report-api, …).
- Puntos rojos de promoción desactivados.

### Rendimiento
- 4 CPU / 6 GB (`performance_mode = middle`).
- `app_keptlive = false`.
- Animaciones de Android a 0.

Resultado medido: arranque en frío **~15–17 s** (antes ~32–39 s con 1 CPU / 2 GB).

---

## Requisitos
- Windows 10/11 con MuMu Player Global **12.0** instalado.
- PowerShell 5.1.
- **Permisos de administrador** (para editar el `hosts` de Windows).
- Para la vía guest via ADB: MuMu con **ROOT activado** (Ajustes → Otros → Root).
- Ruta de instalación por defecto: `D:\MuMuPlayerGlobal-12.0`
  (si es distinta, ajusta los `-Base` / `-MuMuManager` / `-Adb`).

> ⚠️ **Compatibilidad del parche `system-diff.vdi`**: se generó contra un build
> concreto de MuMu Player Global 12.0, cuyo `system.vdi` base tiene
> **MD5 `ca33731da8392959c00ec5a65020f093`** y UUID
> `c8b6fb46-58ae-cb12-0000-100000000000`. Si tu base no coincide, usa la vía
> "solo scripts" (deja tu propio diff) en lugar de aplicar este parche.

---

## Estructura

```
mumu-global-debloat/
├─ scripts/
│  ├─ optimize.ps1        # host: perf + hosts de Windows + caché del splash
│  ├─ debloat-guest.ps1   # Android via ADB: hosts + rename APKs (genera el diff)
│  ├─ merge_diff.ps1      # fusiona un system-diff.vdi dentro de la base
│  ├─ swap_base.ps1       # sustituye system.vdi por la imagen fusionada
│  └─ revert.ps1          # rollback completo del host
├─ patch/
│  ├─ system-diff.vdi     # parche diferencial (~12 MB) listo para fusionar
│  ├─ hosts                # lista anti-anuncios para /system/etc/hosts
│  └─ imageManager.json    # manifiesto vacío del splash
└─ docs/NOTES.md           # notas técnicas (formato VDI, mapa de bloques, UUIDs)
```

---

## Uso

### Vía rápida — aplicar el parche listo (recomendada)

Requiere que tu `system.vdi` base coincida con el build esperado (ver aviso).

```powershell
# 0) Cierra MuMu por completo.

# 1) Fusiona el diff provisto dentro de una copia de tu base.
powershell -ExecutionPolicy Bypass -File scripts\merge_diff.ps1 `
  -Base "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi" `
  -Diff ".\patch\system-diff.vdi" `
  -Out  "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"

# 2. Backups + sustituye el base por la imagen fusionada (horneado) y deja la base en readonly:
powershell -ExecutionPolicy Bypass -File .\scripts\swap_base.ps1 `
  -Merged "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"

# 3. Optimizacion + anti-ads del host (acepta el UAC):
powershell -ExecutionPolicy Bypass -File .\scripts\optimize.ps1
```

Luego arranca MuMu. Verificación en el Android:

```powershell
& "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" -s 192.168.1.149:5555 shell "md5sum /system/etc/hosts"
# -> e6b9a273c0daa50bcfc37f8c014d9b87  /system/etc/hosts
& "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" -s 192.168.1.149:5555 shell "pm path com.mumu.store_overseas"
# -> (vacio)
```

---

## Vía "solo scripts" (multi-versión)

Si tu build no coincide, genera tu **propio** diff en lugar de usar el parche:

1. Pon el disco base en *Writable* para que MuMu cree un `system-diff.vdi`:
   ```powershell
   & "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe" setting --vmindex 0 --key system_disk_readonly --value false
   ```
2. Arranca MuMu y aplica el debloat dentro del Android:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\debloat-guest.ps1
   ```
3. Reinicia el emulador y confirma que los paquetes desaparecieron.
4. Apaga MuMu. Fusiona **tu** diff y hornéalo:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\merge_diff.ps1 `
       -Base "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi" `
       -Diff "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0\system-diff.vdi" `
       -Out  "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi" `
       -ExpectedBaseMd5 ""
   powershell -ExecutionPolicy Bypass -File .\scripts\swap_base.ps1 -Merged "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"
   ```

---

## Rollback

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\revert.ps1
```

Restaura el `system.vdi.bak`, el `system-diff.vdi`, el `hosts` de Windows y la
caché del splash. (Los backups también quedan en `D:\MuMuPlayerGlobal-12.0\backup_debloat`.)

---

## Notas y avisos
- **Google Play / GMS NO se tocan** (Play Store, Play Games, GMS siguen intactos).
- Bloquear `api.mumuglobal.com` corta telemetría *crashrpt/geoip*; si alguna
  función propia de MuMu dejara de funcionar, elimina esa línea del `hosts`.
- Hacer *merge diff → base* es **irreversible sin backup**: `swap_base.ps1` guarda
  `system.vdi.bak` automáticamente. No lo borres hasta validar.
- El emulador debe estar **apagado** durante el merge/swap (los VDI no se pueden
  escribir mientras están montados).

### Legal
Este repositorio distribuye únicamente **scripts** y un **parche diferencial**
(12 MB) que se aplica sobre *tu propia* instalación legal de MuMu Player. No
incluye ni redistribuye la imagen completa del sistema (que contiene binarios de
MuMu/Google). Úsalo bajo tu responsabilidad y respetando los términos de MuMu.
