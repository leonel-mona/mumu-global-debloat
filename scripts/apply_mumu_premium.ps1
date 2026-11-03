<#
  apply_mumu_premium.ps1
  Aplica flags de "Premium" / "Sin anuncios" en MuMu Store
#>
param(
  [Parameter(Mandatory=$true)][int]$VmIndex
)

$ErrorActionPreference = 'Stop'
$MuMu = "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"

function Run-Su {
  param([string]$cmd)
  $out = & $MuMu adb --vmindex $VmIndex --cmd "shell su -c '$cmd'" 2>&1
  return $out.Trim()
}

Write-Host "=== Aplicando flags Premium en MuMu Store ==="

# 1. prefs.xml - ad_removal_config con exclude_fchannels=["*"]
$prefsXml = '<?xml version=''1.0'' encoding=''utf-8'' standalone=''yes'' ?><map><string name="startup_last_device_launch">1793670983</string><string name="host_device_id">aeawqlidrmabjihz</string><string name="ad_removal_config">{"modules":[{"module":"launcher_launching_campaign","exclude_fchannels":["*"]},{"module":"launcher_popup","exclude_fchannels":["*"]}]}</string><string name="popup_ad_record">{"ad_id":"","ad_last_time":0,"ad_show_times":0}</string></map>'

$prefsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($prefsXml))
Run-Su "echo $prefsB64 | base64 -d > /data/data/com.mumu.store/shared_prefs/com.mumu.store.prefs.xml && chmod 660 /data/data/com.mumu.store/shared_prefs/com.mumu.store.prefs.xml && chown system:system /data/data/com.mumu.store/shared_prefs/com.mumu.store.prefs.xml"
Write-Host "[1/2] com.mumu.store.prefs.xml actualizado"

# 2. settings.xml - flags premium
$settingsXml = '<?xml version=''1.0'' encoding=''utf-8'' standalone=''yes'' ?><map><boolean name="splash_ad_disabled" value="true" /><boolean name="premium_user" value="true" /><boolean name="ads_disabled" value="true" /></map>'

$settingsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($settingsXml))
Run-Su "echo $settingsB64 | base64 -d > /data/data/com.mumu.store/shared_prefs/settings.xml && chmod 660 /data/data/com.mumu.store/shared_prefs/settings.xml && chown system:system /data/data/com.mumu.store/shared_prefs/settings.xml"
Write-Host "[2/2] settings.xml actualizado"

Write-Host ""
Write-Host "Verificando..."
Run-Su "cat /data/data/com.mumu.store/shared_prefs/com.mumu.store.prefs.xml"
Run-Su "cat /data/data/com.mumu.store/shared_prefs/settings.xml"

Write-Host ""
Write-Host "=== COMPLETADO ==="