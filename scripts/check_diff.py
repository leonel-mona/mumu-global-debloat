import struct

# Check what blocks are modified in the existing diff VDI
with open('D:\\MuMuPlayerGlobal-12.0\\vms\\MuMuPlayerGlobal-12.0-0\\system-diff.vdi', 'rb') as f:
    # Read block map
    f.seek(0x100000)
    buf = f.read(2794 * 4)
    block_map = struct.unpack('<2794i', buf)
    
    allocated = [(i, b) for i, b in enumerate(block_map) if b != -1]
    print(f"Allocated blocks: {len(allocated)}")
    
    # Check each allocated block for priv-app content
    for log_block, phys_block in allocated:
        # Read the block
        f.seek(0x200000 + phys_block * 1048576)
        block_data = f.read(1048576)
        
        # Search for "priv-app" or "mumu"
        if b'priv-app' in block_data or b'mumu.store' in block_data:
            print(f"  Block {log_block} (phys {phys_block}) contains priv-app/mumu!")
        elif b'hosts' in block_data:
            print(f"  Block {log_block} (phys {phys_block}) contains hosts")
        elif b'system' in block_data[:100]:  # check beginning
            print(f"  Block {log_block} (phys {phys_block}) might be system area")
    
    # Also check what's in the first few allocated blocks
    print("\nFirst 5 allocated blocks:")
    for log_block, phys_block in allocated[:5]:
        f.seek(0x200000 + phys_block * 1048576)
        data = f.read(256)
        print(f"  Block {log_block} (phys {phys_block}): {data[:64].hex()}")