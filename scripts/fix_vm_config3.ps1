$cfg = 'D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0\configs\vm_config.json'
$j = Get-Content $cfg -Raw | ConvertFrom-Json
$j.vm.system_vdi.sharable = 'Readonly'
$j.vm.nat.port_forward.adb | Add-Member -NotePropertyName guest_ip -NotePropertyValue '192.168.1.149' -Force
$j.vm.nat.port_forward.adb | Add-Member -NotePropertyName host_port -NotePropertyValue '16384' -Force
$j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
Write-Host 'Done'