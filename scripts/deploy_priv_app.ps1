$Adb = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$Serial = "192.168.1.149:5555"

# Try to copy the APK using the same pattern as debloat-final.ps1
$cmds = @(
    "mkdir -p /system/priv-app/com.mumu.store",
    "cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store/com.mumu.store.apk",
    "chmod 644 /system/priv-app/com.mumu.store/com.mumu.store.apk",
    "chmod 755 /system/priv-app/com.mumu.store"
)

foreach ($c in $cmds) {
    Write-Host "Running: $c"
    $result = & $Adb -s $Serial shell "su -c `"$c`""
    Write-Host "Result: $result"
}