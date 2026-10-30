import struct

# Examine the blocks with mumu content
with open('D:\\MuMuPlayerGlobal-12.0\\vms\\MuMuPlayerGlobal-12.0-0\\system-diff.vdi', 'rb') as f:
    # Block 65 (phys 4)
    print("=== Block 65 (phys 4) ===")
    f.seek(0x200000 + 4 * 1048576)
    data = f.read(1048576)
    
    # Find "mumu"
    idx = data.find(b'mumu')
    if idx >= 0:
        print(f"Found 'mumu' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+64]}")
    
    idx = data.find(b'priv-app')
    if idx >= 0:
        print(f"Found 'priv-app' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+64]}")
    
    # Check for com.mumu.store
    idx = data.find(b'com.mumu.store')
    if idx >= 0:
        print(f"Found 'com.mumu.store' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+128]}")
    
    # Block 1663 (phys 5)
    print("\n=== Block 1663 (phys 5) ===")
    f.seek(0x200000 + 5 * 1048576)
    data = f.read(1048576)
    
    idx = data.find(b'mumu')
    if idx >= 0:
        print(f"Found 'mumu' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+64]}")
    
    idx = data.find(b'priv-app')
    if idx >= 0:
        print(f"Found 'priv-app' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+64]}")
    
    idx = data.find(b'com.mumu.store')
    if idx >= 0:
        print(f"Found 'com.mumu.store' at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+128]}")
    
    # Also check block 33 (phys 1) - might be superblock
    print("\n=== Block 33 (phys 1) ===")
    f.seek(0x200000 + 1 * 1048576)
    data = f.read(1048576)
    
    idx = data.find(b'\x53\xef')
    if idx >= 0:
        print(f"Found ext4 magic at offset {idx}")
        print(f"Context: {data[max(0,idx-32):idx+64].hex()}")