import ext4
import inspect

# Check if Volume has write methods
print("=== Volume write methods ===")
for name in dir(ext4.Volume):
    if 'write' in name.lower() or 'create' in name.lower() or 'mkdir' in name.lower() or 'add' in name.lower():
        obj = getattr(ext4.Volume, name)
        if callable(obj):
            try:
                sig = inspect.signature(obj)
                print(f"  {name}{sig}")
            except:
                print(f"  {name} (no signature)")

# Check Directory for create methods
print("\n=== Directory create methods ===")
for name in dir(ext4.Directory):
    if 'create' in name.lower() or 'mkdir' in name.lower() or 'add' in name.lower() or 'write' in name.lower():
        obj = getattr(ext4.Directory, name)
        if callable(obj):
            try:
                sig = inspect.signature(obj)
                print(f"  {name}{sig}")
            except:
                print(f"  {name} (no signature)")

# Check Inodes
print("\n=== Inodes methods ===")
for name in dir(ext4.Volume.inodes.fget(None)):
    obj = getattr(ext4.Volume.inodes.fget(None), name)
    if callable(obj):
        try:
            sig = inspect.signature(obj)
            print(f"  {name}{sig}")
        except:
            print(f"  {name} (no signature)")