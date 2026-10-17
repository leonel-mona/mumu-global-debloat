<#
  merge_diff.ps1
  Fusiona un disco diferencial de MuMu (system-diff.vdi) dentro de la imagen base
  (system.vdi), hornenado los cambios para que el emulador los use con la base
  montada en READONLY y sin discos diferenciales.

  Esto es lo que convierte el debloat "en caliente" (que solo vive en el diff)
  en un cambio permanente en system.vdi.

  Formato VDI soportado: Version 0x00010001, cbBlock=1MB.
    offBlocks = 0x100000, offData = 0x200000, cBlocks = 2794
    mapa: valor = indice de bloque fisico (offset = offData + idx*1MB); -1 = no asignado

  Uso:
    powershell -ExecutionPolicy Bypass -File merge_diff.ps1 `
        -Base "D:\MuMuPlayerGlobal-12.0\nx_device\12.0\vms\MuMuPlayerGlobal-12.0-base\system.vdi" `
        -Diff "D:\mumu-global-debloat\patch\system-diff.vdi" `
        -Out  "D:\MuMuPlayerGlobal-12.0\backup_debloat\system.merged.vdi"

  Salida: escribe -Out y ademas .out.md5. NO modifica el base (lo copia).
#>
param(
  [Parameter(Mandatory=$true)][string]$Base,
  [Parameter(Mandatory=$true)][string]$Diff,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$ExpectedBaseMd5 = "ca33731da8392959c00ec5a65020f093"
)

$ErrorActionPreference = 'Stop'

$cbBlock   = 1048576
$offBlocks = 1048576
$offData   = 2097152
$cBlocks   = 2794

if (-not (Test-Path -LiteralPath $Base)) { throw "No existe el base: $Base" }
if (-not (Test-Path -LiteralPath $Diff)) { throw "No existe el diff: $Diff" }

if ($ExpectedBaseMd5) {
  Write-Host "[*] Verificando MD5 del base ..."
  $md5 = (Get-FileHash -LiteralPath $Base -Algorithm MD5).Hash.ToLower()
  if ($md5 -ne $ExpectedBaseMd5) {
    Write-Warning "MD5 del base = $md5 (esperado $ExpectedBaseMd5)."
    Write-Warning "El parche se genero contra ese build exacto; si tu base difiere, los bloques"
    Write-Warning "pueden no corresponder. Continua solo si sabes lo que haces."
  } else {
    Write-Host "[+] Base coincide con el build esperado."
  }
}

function Read-Map($fs, $off, $n) {
  $fs.Position = $off
  $buf = New-Object byte[] ($n * 4)
  $r = 0
  while ($r -lt $n * 4) { $k = $fs.Read($buf, $r, $n * 4 - $r); if ($k -le 0) { break }; $r += $k }
  $m = New-Object 'int[]' $n
  for ($i = 0; $i -lt $n; $i++) { $m[$i] = [BitConverter]::ToInt32($buf, $i * 4) }
  return $m
}

Write-Host "[*] Copiando base -> $Out ..."
Copy-Item -LiteralPath $Base -Destination $Out -Force

$fsD = [System.IO.File]::Open($Diff, 'Open', 'Read', 'Read')
$fsB = [System.IO.File]::Open($Out,  'Open', 'ReadWrite', 'ReadWrite')

try {
  $mapD = Read-Map $fsD $offBlocks $cBlocks
  $mapB = Read-Map $fsB $offBlocks $cBlocks

  $allocD = 0
  for ($i = 0; $i -lt $cBlocks; $i++) { if ($mapD[$i] -ne -1) { $allocD++ } }
  Write-Host "[*] diff: bloques asignados = $allocD"
  if ($allocD -eq 0) { Write-Warning "El diff no tiene bloques asignados; nada que fusionar." }

  $nextFree = 0
  for ($i = 0; $i -lt $cBlocks; $i++) { if ($mapB[$i] -ge $nextFree) { $nextFree = $mapB[$i] + 1 } }

  $buf = New-Object byte[] $cbBlock
  $copied = 0; $newly = 0
  for ($i = 0; $i -lt $cBlocks; $i++) {
    $d = $mapD[$i]
    if ($d -eq -1) { continue }
    $fsD.Position = [int64]$offData + [int64]$d * $cbBlock
    $r = 0
    while ($r -lt $cbBlock) { $k = $fsD.Read($buf, $r, $cbBlock - $r); if ($k -le 0) { break }; $r += $k }

    if ($mapB[$i] -ne -1) {
      $dst = [int64]$offData + [int64]$mapB[$i] * $cbBlock
    } else {
      $mapB[$i] = $nextFree
      $dst = [int64]$offData + [int64]$nextFree * $cbBlock
      $nextFree++; $newly++
    }
    $fsB.Position = $dst
    $fsB.Write($buf, 0, $cbBlock)
    $copied++
  }

  # Reescribir mapa y cBlocksAllocated (offset 0x184)
  $mb = New-Object byte[] ($cBlocks * 4)
  for ($i = 0; $i -lt $cBlocks; $i++) { [Array]::Copy([BitConverter]::GetBytes([int]$mapB[$i]), 0, $mb, $i * 4, 4) }
  $fsB.Position = $offBlocks
  $fsB.Write($mb, 0, $mb.Length)

  $fsB.Position = 0x184
  $allocBytes = [BitConverter]::GetBytes([int]$nextFree)
  $fsB.Write($allocBytes, 0, 4)
}
finally {
  $fsD.Close(); $fsB.Close()
}

$md5out = (Get-FileHash -LiteralPath $Out -Algorithm MD5).Hash.ToLower()
Set-Content -LiteralPath "$Out.md5" -Value $md5out -Encoding ASCII
Write-Host "[+] copiados: $copied  (bloques nuevos en base: $newly)"
Write-Host "[+] cBlocksAllocated = $nextFree"
Write-Host "[+] escrito: $Out"
Write-Host "[+] md5: $md5out"
