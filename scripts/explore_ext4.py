import ext4
# Explore the API
bd = ext4.BlockDevice
print("BlockDevice methods:", [m for m in dir(bd) if not m.startswith('_')])
print()
vol = ext4.Volume
print("Volume methods:", [m for m in dir(vol) if not m.startswith('_')])
print()
d = ext4.Directory
print("Directory methods:", [m for m in dir(d) if not m.startswith('_')])
print()
f = ext4.File
print("File methods:", [m for m in dir(f) if not m.startswith('_')])