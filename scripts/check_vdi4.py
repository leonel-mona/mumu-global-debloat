import struct

# Read VDI block map
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as f:
    # Read block map from offset 0x100000
    f.seek(0x100000)
    buf = f.read(2794 * 4)
    block_map = struct.unpack('<2794i', buf)
    
    # Count allocated
    allocated = sum(1 for b in block_map if b != -1)
    print(f"Allocated blocks: {allocated}/2794")
    
    # The ext4 superblock is at offset 17564728 in the RAW image
    # In the VDI, this is at some logical block offset
    # Let's find which logical block contains this offset
    
    target_offset = 17564728
    log_block = target_offset // 1048576
    offset_in_block = target_offset % 1048576
    print(f"Target offset {target_offset} is in logical block {log_block}, offset {offset_in_block}")
    
    phys_block = block_map[log_block]
    print(f"Physical block: {phys_block}")
    
    if phys_block >= 0:
        vdi_offset = 0x200000 + phys_block * 1048576 + offset_in_block
        print(f"VDI file offset: {vdi_offset}")
        
        # Read the magic at this offset
        f.seek(vdi_offset)
        magic = f.read(2)
        print(f"Magic at VDI offset {vdi_offset}: {magic.hex()} (expected: 53ef)")
        
        # Read the superblock
        f.seek(vdi_offset - 0x38)
        sb = f.read(1024)
        print(f"s_magic: {struct.unpack('<H', sb[56:58])[0]}")
        print(f"s_inodes_count: {struct.unpack('<I', sb[0:4])[0]}")
        print(f"s_blocks_count_lo: {struct.unpack('<I', sb[4:8])[0]}")
        print(f"s_log_block_size: {struct.unpack('<I', sb[24:28])[0]}")
        print(f"s_blocks_per_group: {struct.unpack('<I', sb[32:36])[0]}")
        print(f"s_inodes_per_group: {struct.unpack('<I', sb[40:44])[0]}")
        
        # The superblock is at offset 0x400 from the start of the filesystem
        # So filesystem starts at:
        fs_start_vdi = vdi_offset - 0x438
        print(f"Filesystem start in VDI: {fs_start_vdi} (0x{fs_start_vdi:x})")
        
        # Now let's verify by reading the root inode
        # Root inode is inode 2
        # Inode size is typically 128 or 256 bytes
        # Inodes start at block 1 (or wherever s_first_ino points)
        # Actually, inode table location is in the group descriptor
        # Let's just read block 0 of the filesystem (which is at fs_start_vdi)
        # and check the magic
        
        # Block 0 of ext4 filesystem is at fs_start_vdi
        f.seek(fs_start_vdi)
        block0 = f.read(1024)
        print(f"Block 0 first 16 bytes: {block0[:16].hex()}")
        
        # The superblock is at offset 0x400 within block 0
        f.seek(fs_start_vdi + 0x400)
        sb_check = f.read(2)
        print(f"Superblock magic at fs_start + 0x400: {sb_check.hex()}")