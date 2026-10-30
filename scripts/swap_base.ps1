<#
  swap_base.ps1
  Sustituye el system.vdi base por la imagen ya fusionada (merge_diff.ps1) y deja
  la VM arrancando SOLO con la base (sin disco diferencial). Hace backup del base
  original antes de tocar nada.

  Pasos:
    1. Backup del system.vdi actual -> <base>.bak
    2. Backup del system-diff.vdi actual -> <vm>.system-diff.vdi.disabled
    3. Copia la imagen fusionada encima de system.vdi
    4. Fija vm.system_vdi.sharable = Readonly en vm_config.json (equivalente a
       system_disk_readonly = true)

  Uso:
    powershell -ExecutionPolicy Bypass -File swap_base.ps1 `
        -Merged "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"
#>
param(
  [Parameter(Mandatory=$true)][string]$Merged,
  [string]$Base    = "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi",
  [string]$VmDir   = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0",
  [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Merged)) { throw "No existe la imagen fusionada: $Merged" }
if (-not (Test-Path -LiteralPath $Base))   { throw "No existe el base: $Base" }

if (-not $SkipBackup) {
  Write-Host "[*] Backup del base -> $Base.bak ..."
  Copy-Item -LiteralPath $Base -Destination "$Base.bak" -Force
}

$diff = Join-Path $VmDir "system-diff.vdi"
if (Test-Path -LiteralPath $diff) {
  Write-Host "[*] Retirando disco diferencial -> $diff.disabled"
  if (Test-Path -LiteralPath "$diff.disabled") { Remove-Item -LiteralPath "$diff.disabled" -Force }
  Move-Item -LiteralPath $diff -Destination "$diff.disabled" -Force
}

Write-Host "[*] Copiando imagen fusionada encima del base ..."
Copy-Item -LiteralPath $Merged -Destination $Base -Force

$cfg = Join-Path $VmDir "configs\vm_config.json"
if (Test-Path $cfg) {
  Write-Host "[*] system_vdi.sharable = Readonly en vm_config.json ..."
  $j = Get-Content $cfg -Raw | ConvertFrom-Json
  if (-not $j.vm.system_vdi) { $j.vm | Add-Member -NotePropertyName system_vdi -NotePropertyValue ([pscustomobject]@{}) }
  $j.vm.system_vdi | Add-Member -NotePropertyName sharable -NotePropertyValue "Readonly" -Force
  $j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
}

$md5 = (Get-FileHash -LiteralPath $Base -Algorithm MD5).Hash.ToLower()
Write-Host "[+] Base sustituido. MD5 actual: $md5"
Write-Host "[+] Listo. Arranca MuMu; los cambios deben persistir con la base en readonly."
