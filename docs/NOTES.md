# Notas técnicas

## Entorno de referencia
- MuMu Player Global **12.0** (shell `6.8.0.0`, engine `nemux 12`, Android 12 / SDK 32,
  `ro.product.model=SM-A217M`, x86_64), host Windows 11, renderer dx11.
- Ruta de instalación: `D:\MuMuPlayerGlobal-12.0`
- ADB: `nx_main\adb.exe -s 192.168.1.149:5555`

## Por qué hay que "hornear" los cambios en `system.vdi`
MuMu 12 monta el disco de sistema base como **Readonly** y redirige las escrituras
a un disco **diferencial** (`vms\<nombre-vm>\system-diff.vdi`). Si vuelves a poner
`system_disk_readonly = true`, MuMu **desconecta el diff** y vuelve al estado
original. Por eso el debloat en caliente no persiste: hay que **fusionar el diff
dentro del base**.

La forma de saber si se está usando el diff: con escrituras, aparece
`system-diff.vdi` en la carpeta de la VM; con `readonly=true`, no.

## Formato VDI (disco sistema de MuMu 12)
```
Version        = 0x00010001
Type           = 1 (dinamico)
cbBlock        = 1048576 (1 MiB)
cbBlockExtra   = 0
cBlocks        = 2794
cBlocksAlloc   = 2137 (base original)
offBlocks      = 0x100000   (mapa de bloques)
offData        = 0x200000   (inicio de datos)
cbSector       = 512
Size           = 2928744960
```
- **Mapa de bloques**: en `offBlocks`, `cBlocks` enteros little-endian.
  `mapa[i]` = índice de bloque físico de datos; `offset = offData + idx * cbBlock`.
  Valor `-1` = bloque no asignado (virtualmente cero).
- `cBlocks` en offset `0x180`; **`cBlocksAllocated` en `0x184`** (actualizar tras fusionar).
- UUID del base: `c8b6fb46-58ae-cb12-0000-100000000000`
  (`uuidCreation` del base = `...-0000-100000000000`; el diff tiene
  `uuidParent` = ese mismo, por eso el diff "cuelga" del base).

## Archivos de la imagen original (referencia)
| Archivo | Tamaño | MD5 |
|---|---|---|
| `system.vdi` (base) | 2,242,904,064 | `ca33731da8392959c00ec5a65020f093` |
| `system-diff.vdi` (parche de este repo) | 12,582,912 | – |

El parche `patch/system-diff.vdi` contiene **10 bloques asignados**, que
corresponden a: `/system/etc/hosts` (nuevo), y los renames de
`com.mumu.store_overseas`, `com.mumu.acc_overseas`, `com.nemu.oaidmanager`
(entradas de directorio ext4). La fusión copia esos 10 bloques al base y ajusta el
mapa + `cBlocksAllocated` (2137 → 2138).

## Verificación tras hornear (con `readonly=true`)
```
md5sum /system/etc/hosts        -> e6b9a273c0daa50bcfc37f8c014d9b87  (228 lineas)
pm path com.mumu.store_overseas -> (vacio)
pm path com.mumu.acc_overseas   -> (vacio)
pm path com.nemu.oaidmanager    -> (vacio)
ls /system/priv-app/*/*.apk.off -> los 3 renombrados
```
El `system.vdi` resultante tiene MD5 distinto al original (es la señal de que el
base cambió).

## Anuncios del host (splash de arranque)
- El frontend (`MuMuNxMain.exe`, CEF/QtWebEngine) muestra en la pantalla de carga
  ("mientras arranca" la VM) un anuncio de campaña: promoción de un juego + botón
  de "quitar anuncios" que lleva a pagar (upsell MuMu Pro). Las creatividades se
  cachean en `%APPDATA%\Netease\MuMuPlayerGlobal\data\startupImage\<campaignId>\*.jpeg`
  con manifiesto `imageManager.json` (enlaces `mumu://store/...`).
- Origen confirmado = **campaña servida por red**, no imagen embebida:
  `StartupImageManager::fetchImageInfos_` pide `v2/campaign/launcher/launching`
  (base `api.mumuglobal.com` / `pro-api.mumuplayer.com`) y lo vuelca en
  `imageManager.json`; `StartupImagePresenter::getLinkType: campaign`.
- MuMu vende la "eliminación de anuncios" como suscripción de pago
  (flujo `adRemoval` → `mumupro.webapp.easebar.com/#/recharge`).
- Endpoints a bloquear (hosts de Windows): `mumu-global.fp.ps.easebar.com`
  (CDN de creatividades), `adl.guinfra.com` + `stardesk.net`/`www.stardesk.net`
  (stardesk campaign delivery), `event.sc.gearupportal.com` (tracking),
  `shence-api.mumu.163.com`, `fcount-api.webapp.easebar.com` + `fcount-api.webapp.163.com`
  (gate de features/campañas), `api.mumu.nie.netease.com`, `sentry.netease.com`,
  `report-api.mumuplayer.com`, `api.mumuglobal.com`.
- **No** bloquear: `user-center.mumuplayer.com` (login), `pro-api.mumuplayer.com`
  (API de cuenta/Pro; bloquearlo puede romper funciones Pro y dar timeouts).
- Verificación: con los bloqueos aplicados + caché vacía + manifiesto en readonly,
  `imageManager.json` permanece en `{"info": []}` (nunca se rellena) y el splash de
  arranque ya no muestra anuncio. Es la señal de que la campaña no se descarga.

### Descartado (para no repetir el trabajo)
- No es la **animación de arranque de Android**: el guest tiene
  `debug.sf.nobootanimation=1`; `/system/etc/mumu-configs` es solo el traductor ARM.
- No está **embebido en el frontend**: `MuMuNxMain.exe` no contiene imágenes (sin
  cabeceras `qres`/rcc ni bloques JPEG).
- Los **dos JPEG 680x510** de `NxMainResource.rcc` (file offsets `0x5054579` =
  92 184 B y `0x506C935` = 97 122 B, ambos exactos hasta EOI) son **fondos casi
  planos** (uno oscuro, otro blanco con marca de agua; 0 texto por OCR) → **no** son
  el anuncio.
- Los **paquetes de terceros del guest** instalados por `host-file-mumu-app-store`
  (`mu.origin.ro.ggplay.qjmu`, `v8.ragezone.hhdev`, …) **no** son el origen del
  splash (el home por defecto es `app.lawnchair/.LawnchairLauncher` y el anuncio se
  dibuja en el host, no en el guest).

## Anuncios dentro del launcher (widgets de `com.mumu.store`)
- El home (Lawnchair, `app.lawnchair/.LawnchairLauncher`, build de sistema
  `/system/priv-app/app.lawnchair_overseas`) NO trae los anuncios en su APK: los
  añade en runtime el paquete **`com.mumu.store`** ("Tienda MuMu"), que MuMu instala
  en **`/data/app`** (no en `/system`) y por eso **reaparece** aunque se desactive el
  `com.mumu.store_overseas` del sistema.
- Ese store declara dos **widgets** que se fijan en la pantalla 0, celdas X=0 y X=2
  (lado a lado):
  | Widget | Contenido |
  |---|---|
  | `com.mumu.store/.widget.appWidgetProvider.AdBannerWidgetProvider` | publicidad de juegos (banner) |
  | `com.mumu.store/.widget.appWidgetProvider.DailyDiscoveryWidgetProvider` | "sugerencias" (Daily Discovery, rejilla de juegos) |
- **Solución (sin desinstalar la tienda):** deshabilitar los dos proveedores. El
  sistema desliga los widgets automáticamente.
  ```
  su -c 'pm disable com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider'
  su -c 'pm disable com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider'
  ```
- Verificación: `dumpsys appwidget` → `widgets.size=0`; `uiautomator dump` de la home
  sin ids `com.mumu.store:id/widgetAdBanner*` ni `widgetDailyDiscovery*`; la lista de
  disabled-components queda en
  `/data/system/users/0/package-restrictions.xml`. **Persiste tras reiniciar** la VM
  (vive en userdata, no requiere hornear en `system.vdi`; sí conviene re-aplicarlo si
  se resetea el emulador — va en `debloat-guest.ps1`).

## Arranque rápido (`fast_start`)
Probado: cerrar MuMu con la X y reabrir **no** guarda snapshot (apagado limpio,
sin carpeta `Snapshots`). No hay arranque "instantáneo" por suspensión en 12.0; la
ganancia real viene de subir recursos (4 CPU / 6 GB).

## Herramientas útiles
- `nx_main\MuMuManager.exe` — `info`, `control`, `setting`.
- `nx_device\12.0\hypervisor\vbox-img.exe` — `info` de los VDI (cabeceras/mapa).
- `nx_main\adb.exe` — ADB (usar `-s 192.168.1.149:5555`).
- `MuMuManager control --vmindex 0 reboot` NO funciona ("not handle cmd"); usar
  `adb -s <serial> reboot`.
