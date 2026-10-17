<#
  revert.ps1
  Revierte los cambios en el HOST:
    - Restaura system.vdi desde su .bak
    - Restaura system-diff.vdi desde su .disabled
    - Re-activa system_vdi.sharable = Writable en vm_config.json
    - Elimina las lineas de bloqueo de MuMu del hosts de Windows
    - Restaura la cache del splash (startupImage.bak) si existe

  Uso:
    powershell -ExecutionPolicy Bypass -File revert.ps1
#>
param(
  [string]$Base  = "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi",
  [string]$VmDir = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0",
  [string]$BackupDir = "D:\MuMuPlayerGlobal-12.0\backup_debloat"
)

$ErrorActionPreference = 'Stop'

if (Test-Path "$Base.bak") {
  Write-Host "[*] Restaurando base desde $Base.bak ..."
  Copy-Item -LiteralPath "$Base.bak" -Destination $Base -Force
} else { Write-Warning "No hay backup del base ($Base.bak). Se omite." }

$diffDisabled = Join-Path $VmDir "system-diff.vdi.disabled"
$diff = Join-Path $VmDir "system-diff.vdi"
if (Test-Path $diffDisabled) {
  Write-Host "[*] Restaurando disco diferencial ..."
  Move-Item -LiteralPath $diffDisabled -Destination $diff -Force
}

$cfg = Join-Path $VmDir "configs\vm_config.json"
if (Test-Path $cfg) {
  $j = Get-Content $cfg -Raw | ConvertFrom-Json
  if ($j.vm.system_vdi) { $j.vm.system_vdi | Add-Member -NotePropertyName sharable -NotePropertyValue "Writable" -Force }
  $j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
}

Write-Host "[*] Quitando lineas de bloqueo del hosts de Windows ..."
$hosts = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$lines = Get-Content $hosts
$clean = $lines | Where-Object { $_ -notmatch '0\.0\.0\.0\s+(mumu|adl\.guinfra|shence|fcount|api\.mumu\.nie|sentry\.netease|report-api|api\.mumuglobal)' -and $_ -notmatch 'MuMu debloat|MuMu Player ad/telemetry' }
$tmp = Join-Path $env:TEMP "mumu_hosts_clean.txt"
Set-Content -LiteralPath $tmp -Value ($clean -join "`r`n") -Encoding ASCII
Start-Process -FilePath "cmd.exe" -ArgumentList "/c copy /y `"$tmp`" `"$(Join-Path $env:SystemRoot 'System32\drivers\etc\hosts')`"" -Verb RunAs -Wait
ipconfig /flushdns | Out-Null

$si = Join-Path $env:APPDATA "Netease\MuMuPlayerGlobal\data\startupImage"
if (Test-Path (Join-Path $BackupDir "startupImage.bak")) {
  Write-Host "[*] Restaurando cache del splash ..."
  attrib -R (Join-Path $si "imageManager.json") 2>$null
  Copy-Item (Join-Path $BackupDir "startupImage.bak\*") $si -Recurse -Force
}

Write-Host "[+] Revertido. Reinicia MuMu."
