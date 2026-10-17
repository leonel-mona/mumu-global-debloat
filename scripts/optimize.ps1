<#
  optimize.ps1
  Ajustes de rendimiento + anti-anuncios del HOST (no toca el Android):
    - performance_mode = middle (4 CPU / 6 GB) y app_keptlive = false
    - animaciones de Android a 0 (via ADB)
    - quita puntos rojos de promocion de MuMu (nx_main.json)
    - bloquea dominios de anuncios/telemetria en el hosts de Windows
    - vacia la cache de creatividades del splash (startupImage)

  El bloqueo del hosts y la edicion de archivos del sistema requieren permisos de
  administrador (aparecera un UAC).

  Uso:
    powershell -ExecutionPolicy Bypass -File optimize.ps1
#>
param(
  [string]$MuMuManager = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe",
  [string]$Adb = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe",
  [string]$Serial = "192.168.1.149:5555",
  [string]$VmIndex = "0"
)

$ErrorActionPreference = 'Stop'
$roaming = Join-Path $env:APPDATA "Netease\MuMuPlayerGlobal"

Write-Host "[*] Performance = middle (4 CPU / 6 GB) y app_keptlive = false ..."
& $MuMuManager setting --vmindex $VmIndex --key performance_mode --value middle | Out-Null
& $MuMuManager setting --vmindex $VmIndex --key app_keptlive --value false | Out-Null

Write-Host "[*] Animaciones de Android a 0 ..."
& $Adb connect $Serial | Out-Null; Start-Sleep -Seconds 2
& $Adb -s $Serial shell "settings put global window_animation_scale 0.0; settings put global transition_animation_scale 0.0; settings put global animator_duration_scale 0.0"

Write-Host "[*] Quitando puntos rojos de promocion ..."
$nxcfg = Join-Path $roaming "configs\nx_main.json"
if (Test-Path $nxcfg) {
  $j = Get-Content $nxcfg -Raw | ConvertFrom-Json
  $j.nxmain.deskshort_redpoint = "0"
  $j.nxmain.devicemenu_redpoint = "0"
  ($j | ConvertTo-Json -Depth 10) | Set-Content $nxcfg -Encoding UTF8
}

Write-Host "[*] Vaciando cache de anuncios del splash ..."
$si = Join-Path $roaming "data\startupImage"
if (Test-Path $si) {
  Get-ChildItem $nxcfg -ErrorAction SilentlyContinue | Out-Null
  Get-ChildItem $si -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
  $manifest = Join-Path $si "imageManager.json"
  Set-Content -LiteralPath $manif -Value "{`r`n  `"info`": []`r`n}" -Encoding UTF8 -NoNewline
  attrib +R $imagemanager
}

Write-Host "[*] Bloqueando dominios de anuncios/telemetria en hosts de Windows (UAC) ..."
$domains = @(
  "mumu-global.fp.ps.easebar.com",
  "adl.guinfra.com",
  "shence-api.mumu.163.com",
  "fcount-api.webapp.easebar.com",
  "fcount-api.webapp.163.com",
  "api.mumu.nie.netease.com",
  "sentry.netease.com",
  "report-api.mumuplayer.com",
  "api.mumuglobal.com"
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
  Write-Host "[+] hosts actualizado."
} else {
  Write-Host "[i] Los dominios ya estaban bloqueados."
}

Write-Host ""
Write-Host "[+] Optimizacion aplicada. Reinicia MuMu para que 4 CPU/6 GB tomen efecto."
