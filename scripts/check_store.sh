#!/system/bin/sh
# Check current store package state
echo "=== pm path ==="
pm path com.mumu.store
echo "=== pm list (store) ==="
pm list packages com.mumu.store 2>&1
echo "=== dumpsys package com.mumu.store ==="
dumpsys package com.mumu.store 2>&1 | head -20
echo "=== /data/app store dirs ==="
ls -la /data/app/ 2>&1 | grep -i mumu
echo "=== /system/priv-app store ==="
ls -la /system/priv-app/com.mumu.store_overseas/ 2>&1
echo "=== stub check ==="
ls -la /system/priv-app/com.mumu.store/ 2>&1
ls -la /data/user/0/com.mumu.store 2>&1