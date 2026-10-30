<#
  debloat-store-popups-only.ps1
  Alternativa a 'debloat-guest.ps1'. Desactiva los elementos publicitarios de
  'com.mumu.store' (widgets, splash de inicio, notificaciones), pero deja la tienda
  instalada y funcional para que puedas seguir instalando aplicaciones via doble click.

  Requisitos:
    - MuMu abierto con ROOT activado (Ajustes -> Otros -> Root)
    - ADB de MuMu disponible

  Uso:
    powershell -ExecutionPolicy Bypass -File .\debloat-store-popups-only.ps1
    .\debloat-store-popups-only.ps1 -Serial "192.168.1.149:5555"

  Nota: los cambios caen en el disco diferencial. Para que sean permanentes y
  "quemados" en la imagen base, ejecuta luego merge-diff.ps1 + replace-base.ps1
  (ver README). Sin ese paso, al reiniciar con system_disk_readonly=true se
  revierten.
#>
[CmdletBinding()]
param(
  [string]$Adb      = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe",
  [string]$Serial   = "192.168.1.149:5555",
  [string[]]$AdTech  = @(
    "com.mumu.store_overseas",
    "com.mumu.acc_overseas",
    "com.nemu.oaidmanager"
  )
)

$ErrorActionPreference = 'Stop'

function Adb { param([Parameter(ValueFromRemainingArguments)]$a) & $ADB_EXE -s $Serial @a }

Write-Host "[*] Conectando ADB a $Serial ..."
& $ADB_EXE connect $Serial | Out-Null
Start-Sleep -Seconds 2

if (-not (Test-Path $ADB_PATH)) { throw "No encuentro el ejecutable ADB: $ADB_PATH" }