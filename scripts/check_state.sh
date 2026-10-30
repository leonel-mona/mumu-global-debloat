#!/system/bin/sh
echo "=== pm path com.mumu.store ==="
pm path com.mumu.store
echo "=== dumpsys package (first 20 lines) ==="
dumpsys package com.mumu.store 2>/dev/null
echo "=== ls /data/app ==="
ls /data/app/ 2>&1
echo "=== ls /data/app store dirs ==="
ls -d /data/app/*mumu* 2>&1
echo "=== ls /system/priv-app/com.mumu.store_overseas ==="
ls -la /system/priv-app/com.mumu.store_overseas/ 2>&1
echo "=== ls /system/priv-app/com.mumu.store ==="
ls -la /system/priv-app/com.mumu.store/ 2>&1
echo "=== ls /data/user/0/com.mumu.store ==="
ls -la /data/user/0/com.mumu.store 2>&1
echo "=== getprop ro.build.version.release ==="
getprop ro.build.version.release
echo "=== whoami ==="
whoami
echo "=== id ==="
id