#!/usr/bin/env python3
"""
Reempaqueta el APK base (generado por aapt2 link) añadiendo classes.dex
SIN comprimir resources.arsc (requisito Android 12+ / targetSdk 30+).
"""
import zipfile, os, sys, shutil

base_apk = sys.argv[1]
dex_file = sys.argv[2]
out_apk  = sys.argv[3]

# Leer base.apk
with zipfile.ZipFile(base_apk, 'r') as zin:
    entries = zin.infolist()
    data = {n.filename: zin.read(n.filename) for n in entries}

# Añadir classes.dex como STORED (sin comprimir)
if 'classes.dex' in data:
    del data['classes.dex']
with open(dex_file, 'rb') as f:
    data['classes.dex'] = f.read()

# Escribir nuevo APK: resources.arsc y demas sin comprimir, classes.dex tambien STORED
with zipfile.ZipFile(out_apk, 'w', zipfile.ZIP_STORED) as zout:
    for name in sorted(data.keys()):
        zout.writestr(name, data[name])

print(f"[+] APK reempaquetado: {out_apk} ({os.path.getsize(out_apk)} bytes)")