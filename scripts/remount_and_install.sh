setenforce 0
mount -o rw,remount /system
echo "Mount status:"
mount | grep system

mkdir -p /system/priv-app/com.mumu.store
cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store/com.mumu.store.apk
chmod 644 /system/priv-app/com.mumu.store/com.mumu.store.apk
chmod 755 /system/priv-app/com.mumu.store

echo "Done"