#!/system/bin/sh
# Reemplazar el APK original de com.mumu.store en /system/priv-app por nuestro stub
# y limpiar las entradas en /data/app para que sea app de sistema (uid 1000)

echo "=== Paso 1: Eliminar directorio com.mumu.store que creamos en /system/priv-app ==="
su -c 'rm -rf /system/priv-app/com.mumu.store'

echo "=== Paso 2: Reemplazar APK original por nuestro stub ==="
su -c 'cp /sdcard/com.mumu.store.apk /system/priv-app/com.mumu.store_overseas/com.mumu.store_overseas.apk'
su -c 'chmod 644 /system/priv-app/com.mumu.store_overseas/com.mumu.store_overseas.apk'

echo "=== Paso 3: Limpiar entradas en /data/app ==="
su -c 'rm -rf /data/app/~~4I57SOnDe2Ginb_LdDAHuA=='
su -c 'rm -rf /data/app/~~4I57SOnDe2Ginb_LdDAHuA==*'
su -c 'rm -rf /data/data/com.mumu.store'
su -c 'rm -rf /data/user/0/com.mumu.store'

echo "=== Paso 4: Limpiar cache de package manager ==="
su -c 'rm -rf /data/system/packages.xml'
su -c 'rm -rf /data/system/packages.list'
su -c 'rm -rf /data/system/package.xml'

echo "Hecho. Reboot necesario."