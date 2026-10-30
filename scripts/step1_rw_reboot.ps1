# Step 1: Set system_vdi.sharable = ReadWrite
$cfg = "D:\MuMuPlayerGlobal-12.0\vms\MuMuPlayerGlobal-12.0-0\configs\vm_config.json"
$j = Get-Content $cfg -Raw | ConvertFrom-Json
$j.vm.system_vdi.sharable = "ReadWrite"
$j | ConvertTo-Json -Depth 20 | Set-Content $cfg -Encoding UTF8
Write-Host "Step 1: system_vdi.sharable = ReadWrite"

# Step 2: Reboot VM
Write-Host "Step 2: Rebooting VM..."
& "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe" control --vmindex 0 shutdown 2>&1 | Out-Null
Start-Sleep -Seconds 10
& "D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe" control --vmindex 0 launch 2>&1 | Out-Null

# Step 3: Wait for boot
Write-Host "Step 3: Waiting for boot..."
Start-Sleep -Seconds 45
& "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" kill-server 2>&1 | Out-Null
Start-Sleep -Seconds 3
$online = & "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" connect 192.168.1.149:5555 2>&1
Write-Host "ADB connect: $online"

# Step 4: Try remount
Write-Host "Step 4: Remounting /system..."
$remount = & "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" -s 192.168.1.149:5555 shell "su -c 'mount -o rw,remount /system'" 2>&1
Write-Host "Remount result: $remount"

# Step 5: Check mount status
$mount = & "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe" -s 192.168.1.149:5555 shell "cat /proc/mounts | grep system" 2>&1
Write-Host "Mount status: $mount"