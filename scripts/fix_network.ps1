$cfg = 'D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0\configs\vm_config.json'
$j = Get-Content $cfg -Raw | ConvertFrom-Json
$j.vm.system_vdi.sharable = 'ReadWrite'
$j.vm.nat.port_forward.adb.guest_ip = '192.168.1.149'
$j.vm.nat.port_forward.adb.host_port = '16384'
$j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
Write-Host 'Done'