su -c 'mkdir -p /system/priv-app/com.mumu.store'
su -c 'cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store/com.mumu.store.apk'
su -c 'chmod 644 /system/priv-app/com.mumu.store/com.mumu.store.apk'
su -c 'chmod 755 /system/priv-app/com.mumu.store'
echo "Done"