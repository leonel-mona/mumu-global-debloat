import struct

# VDI structure
CBLOCK = 1048576
OFF_BLOCKS = 1048576
OFF_DATA = 2097152
CBLOCKS = 2794

# Read block map
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as f:
    f.seek(OFF_BLOCKS)
    buf = f.read(CBLOCKS * 4)
    block_map = struct.unpack(f'<{CBLOCKS}i', buf)
    
    # Search for ext4 magic (0x53EF) at offset 0x438 within each logical block
    # (ext4 superblock magic is at offset 0x38 from start of superblock, 
    # and superblock starts at 0x400 in block 0, or 0x0 in block 1024 for modern ext4)
    
    print("Searching for ext4 magic (0x53EF)...")
    found = []
    
    for log_block, phys_block in enumerate(block_map):
        if phys_block < 0:
            continue
        
        # Check at offset 0x400 + 0x38 = 0x438 (traditional superblock location)
        offset1 = OFF_DATA + phys_block * CBLOCK + 0x438
        f.seek(offset1)
        magic1 = f.read(2)
        if magic1 == b'\x53\xef':
            found.append(('traditional', log_block, offset1))
            print(f"  Found traditional superblock magic at logical block {log_block}, offset {offset1}")
        
        # Check at offset 0x400 (start of superblock area)
        offset2 = OFF_DATA + phys_block * CBLOCK + 0x400
        f.seek(offset2)
        magic2 = f.read(2)
        if magic2 == b'\x53\xef':
            found.append(('superblock_start', log_block, offset2))
            print(f"  Found superblock start magic at logical block {log_block}, offset {offset2}")
        
        # Check at offset 0x0 (modern ext4 with superblock at block 0)
        offset3 = OFF_DATA + phys_block * CBLOCK
        f.seek(offset3)
        # ext4 magic is at 0x438 within the superblock
        f.seek(offset3 + 0x438)
        magic3 = f.read(2)
        if magic3 == b'\x53\xef':
            found.append(('block_start', log_block, offset3 + 0x438))
            print(f"  Found block-start superblock magic at logical block {log_block}, offset {offset3 + 0x438}")
    
    if not found:
        print("  No ext4 magic found. Checking raw image...")
        
        # Also check the raw image
        with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as raw:
            # Search in first 100MB
            for i in range(0, 100 * 1024 * 1024, 4096):
                raw.seek(i + 0x438)
                magic = raw.read(2)
                if magic == b'\x53\xef':
                    print(f"  Found ext4 magic in RAW at offset {i + 0x438} (block {i // 1024})")
                    break