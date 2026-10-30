#!/system/bin/sh
# Install the stub com.mumu.store as a SYSTEM app in /system/priv-app
# so it runs as uid 1000 (su whitelist allows 0, 1000, 2000)
# Run as: adb shell su -c sh /data/local/tmp/install_stub_system.sh

echo "=== Step 1: Uninstall current user-app stub ==="
pm uninstall com.mumu.store 2>&1

echo "=== Step 2: Disable original store ==="
pm disable-user com.mumu.store_overseas 2>&1 || true

echo "=== Step 3: Create /system/priv-app/com.mumu.store and copy stub ==="
mkdir -p /system/priv-app/com.mumu.store
cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store/com.mumu.store.apk
chmod 644 /system/priv-app/com.mumu.store/com.mumu.store.apk
chmod 755 /system/priv-app/com.mumu.store

echo "=== Step 4: Verify ==="
ls -la /system/priv-app/com.mumu.store/

echo "=== Step 5: Register as system app ==="
pm install -r /system/priv-app/com.mumu.store/com.mumu.store.apk 2>&1

echo "=== Step 6: Verify uid ==="
dumpsys package com.mumu.store 2>&1 | grep -E "userId|codePath|versionCode|uid"

echo "=== DONE ==="