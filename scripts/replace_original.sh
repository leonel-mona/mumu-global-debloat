#!/system/bin/sh
su -c 'cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store_overseas/com.mumu.store_overseas.apk'
su -c 'chmod 644 /system/priv-app/com.mumu.store_overseas/com.mumu.store_overseas.apk'
echo "Done"