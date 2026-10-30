import struct

FS_START = 168891392

with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    # Read superblock
    f.seek(FS_START + 0x400)
    sb = f.read(1024)
    
    block_size = 1024 << struct.unpack('<I', sb[24:28])[0]
    blocks_per_group = struct.unpack('<I', sb[32:36])[0]
    inodes_per_group = struct.unpack('<I', sb[40:44])[0]
    feature_incompat = struct.unpack('<I', sb[96:100])[0]
    first_ino = struct.unpack('<I', sb[84:88])[0]
    inode_size = struct.unpack('<H', sb[88:90])[0]
    if inode_size == 0:
        inode_size = 128
    
    print(f"Block size: {block_size}")
    print(f"Blocks per group: {blocks_per_group}")
    print(f"Inodes per group: {inodes_per_group}")
    print(f"First inode: {first_ino}")
    print(f"Inode size: {inode_size}")
    print(f"Feature incompat: 0x{feature_incompat:08x}")
    
    # Check for 64bit feature
    has_64bit = bool(struct.unpack('<I', sb[100:104])[0] & 0x20)
    print(f"Has 64bit: {has_64bit}")
    
    # Group descriptor size
    if has_64bit:
        gd_size = 64
    else:
        gd_size = 32
    print(f"Group descriptor size: {gd_size}")
    
    # Number of groups
    blocks_count = struct.unpack('<I', sb[4:8])[0]
    num_groups = (blocks_count + blocks_per_group - 1) // blocks_per_group
    print(f"Number of groups: {num_groups}")
    
    # Read ALL group descriptors
    for g in range(num_groups):
        gd_offset = FS_START + block_size + g * gd_size  # block 1 is first group descriptor
        f.seek(gd_offset)
        gd = f.read(gd_size)
        
        if has_64bit:
            bg_block_bitmap = struct.unpack('<Q', gd[0:8])[0]
            bg_inode_bitmap = struct.unpack('<Q', gd[8:16])[0]
            bg_inode_table = struct.unpack('<Q', gd[16:24])[0]
        else:
            bg_block_bitmap = struct.unpack('<I', gd[0:4])[0]
            bg_inode_bitmap = struct.unpack('<I', gd[4:8])[0]
            bg_inode_table = struct.unpack('<I', gd[8:12])[0]
        
        print(f"\nGroup {g}:")
        print(f"  bg_block_bitmap: {bg_block_bitmap}")
        print(f"  bg_inode_bitmap: {bg_inode_bitmap}")
        print(f"  bg_inode_table: {bg_inode_table}")
        
        # Check if inode table is valid (not 0)
        if bg_inode_table > 0:
            print(f"  -> Valid inode table at block {bg_inode_table}")
            
            # Read inode 2 (root) from this group
            inode_offset = FS_START + bg_inode_table * block_size + (2 - first_ino) * inode_size
            f.seek(inode_offset)
            root_inode = f.read(inode_size)
            
            i_mode = struct.unpack('<H', root_inode[0:2])[0]
            if i_mode & 0xF000 == 0x4000:
                print(f"  -> Inode 2 is a DIRECTORY!")
                i_block0 = struct.unpack('<I', root_inode[40:44])[0]
                print(f"  -> Root block: {i_block0}")
            elif i_mode & 0xF000 == 0x1000:
                print(f"  -> Inode 2 is a FIFO")
            else:
                print(f"  -> Inode 2 type: {(i_mode >> 12) & 0xF:04x}")