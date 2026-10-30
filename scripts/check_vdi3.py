import struct

# Read VDI header
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as f:
    # VDI header structure
    header = f.read(1024)
    
    # Parse VDI header
    # offset 0x00: signature "VirtualDisk" (16 bytes)
    sig = header[0:16]
    print(f"Signature: {sig}")
    
    # offset 0x10: version
    version = struct.unpack('<I', header[0x10:0x14])[0]
    print(f"Version: 0x{version:08x}")
    
    # offset 0x18: header size
    header_size = struct.unpack('<I', header[0x18:0x1c])[0]
    print(f"Header size: {header_size}")
    
    # offset 0x20: block size
    block_size = struct.unpack('<I', header[0x20:0x24])[0]
    print(f"Block size: {block_size}")
    
    # offset 0x28: block count
    block_count = struct.unpack('<I', header[0x28:0x2c])[0]
    print(f"Block count: {block_count}")
    
    # offset 0x30: data size
    data_size = struct.unpack('<Q', header[0x30:0x38])[0]
    print(f"Data size: {data_size}")
    
    # offset 0x38: data offset
    data_offset = struct.unpack('<Q', header[0x38:0x40])[0]
    print(f"Data offset: {data_offset}")
    
    # offset 0x40: block offset
    block_offset = struct.unpack('<Q', header[0x40:0x48])[0]
    print(f"Block offset: {block_offset}")
    
    # offset 0x48: unused
    # offset 0x50: MD5 of the block map
    # offset 0x70: MD5 of the original data
    
    # Read block map
    f.seek(block_offset)
    block_map = []
    for i in range(block_count):
        phys_block = struct.unpack('<i', f.read(4))[0]
        block_map.append(phys_block)
    
    allocated = sum(1 for b in block_map if b != -1)
    print(f"\nAllocated blocks: {allocated}/{block_count}")
    
    # Find where the ext4 superblock is
    print("\nSearching for ext4 superblock in VDI...")
    for log_block, phys_block in enumerate(block_map):
        if phys_block < 0:
            continue
        
        # Check at offset 0x400 + 0x38 = 0x438 within the block
        offset = data_offset + phys_block * block_size + 0x438
        f.seek(offset)
        magic = f.read(2)
        if magic == b'\x53\xef':
            print(f"  Found ext4 magic at logical block {log_block}, physical block {phys_block}, VDI offset {offset}")
            
            # Read superblock
            f.seek(offset - 0x38)
            sb = f.read(1024)
            print(f"  s_magic: {struct.unpack('<H', sb[56:58])[0]}")
            print(f"  s_inodes_count: {struct.unpack('<I', sb[0:4])[0]}")
            print(f"  s_blocks_count_lo: {struct.unpack('<I', sb[4:8])[0]}")
            print(f"  s_log_block_size: {struct.unpack('<I', sb[24:28])[0]}")
            print(f"  s_blocks_per_group: {struct.unpack('<I', sb[32:36])[0]}")
            print(f"  s_inodes_per_group: {struct.unpack('<I', sb[40:44])[0]}")
            
            # The superblock is at offset 0x400 from the start of the filesystem
            # So filesystem starts at:
            fs_start = offset - 0x438
            print(f"  Filesystem start in VDI: {fs_start} (0x{fs_start:x})")
            break