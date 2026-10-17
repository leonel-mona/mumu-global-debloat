<#
  debloat-guest.ps1
  Aplica el debloat dentro del Android de MuMu (via ADB): reemplaza /system/etc/hosts
  por la lista anti-anuncios y renombra los APKs ad-tech de /system/priv-app a *.apk.off.

  Requisitos:
    - MuMu abierto con ROOT activado (Ajustes -> Otros -> Root).
    - ADB de MuMu disponible.

  Uso:
    powershell -ExecutionPolicy Bypass -File .\debloat-guest.ps1
    .\debloat-guest.ps1 -Serial "192.168.1.149:5555"

  Nota: los cambios caen en el disco diferencial. Para que sean permanentes y
  "quemados" en la imagen base, ejecuta luego merge-diff.ps1 + replace-base.ps1
  (ver README). Sin ese paso, al reiniciar con system_disk_readonly=true se revierten.
#>
[CmdletBinding()]
param(
  [string]$Adb      = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe",
  [string]$Serial   = "192.168.1.149:5555",
  $HostsFile        = (Join-Path $PSScriptRoot "..\patch\hosts"),
  [string[]]$AdTech  = @(
    "/system/priv-app/com.mumu.store_overseas/com.mumu.store_overseas.apk",
    "com.mumu.acc_overseas",
    "com.nemu.oaidmanager"
  )
)

$ErrorActionPreference = 'Stop'

function Adb { param([Parameter(ValueFromRemainingArguments)]$a) & $adbExe -s $serial @a }
$adbExe = $adb
$serial = $serial

Write-Host "[*] Conectando ADB a $serial ..."
& $adbExe connect $serial | Out-Null
Start-Sleep -Seconds 2

if (-not (Test-Path $hostsFile)) { throw "No encuentro el archivo hosts: $hostsFile" }

Write-Host "[*] Montando /system en rw ..."
& $adbExe -s $serial shell "su -c 'mount -o rw,remount /system'"
if ($LASTEXITCODE -ne 0) { Write-Warning "El remount devolvio $LASTEXITCODE (puede ser normal si ya estaba rw)" }

Write-Host "[*] Subiendo hosts anti-anuncios ..."
& $adbExe -s $serial push $hostsFile /data/local/tmp/hosts.antiad | Out-Null
& $adbExe -s $serial shell "su -c 'cp /data/local/tmp/hosts.antiad /system/etc/hosts'"
& $adbExe -s $serial shell "su -c 'chmod 644 /system/etc/hosts'"
& $adbExe -s $serial shell "su -c 'rm -f /data/local/tmp/hosts.antiad'"

Write-Host "[*] Renombrando APKs ad-tech a .apk.off ..."
$apks = @("com.mumu.store_overseas", "com.mumu.acc_overseas", "com.nemu.oaidmanager")
foreach ($p in $apks) {
  & $adbExe -s $serial shell "su -c 'p=/system/priv-app/$p/$p.apk; [ -f \$p ] && mv \$p \$p.off; ls -l /system/priv-app/$p/ 2>/dev/null'"
}

Write-Host ""
Write-Host "[+] Verificacion:"
& $adbExe -s $serial shell "md5sum /system/etc/hosts; wc -l /system/etc/hosts"
foreach ($p in $apks) { "  pm path $p -> " + ((& $adbExe -s $serial shell "pm path $p 2>&1" | Out-String).Trim()) }

Write-Host ""
Write-Host "[i] NOTA: para que los cambios sobrevivan a system_disk_readonly=true hay que"
Write-Host "    hornearlos en la imagen base. Ver README (flujo con system-diff.vdi + merge)."
