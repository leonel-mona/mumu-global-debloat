import struct

FS_START = 168891392

# Read the superblock
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    f.seek(FS_START + 0x400)
    sb = f.read(1024)
    
    blocks_count = struct.unpack('<I', sb[4:8])[0]
    log_block_size = struct.unpack('<I', sb[24:28])[0]
    blocks_per_group = struct.unpack('<I', sb[32:36])[0]
    inodes_per_group = struct.unpack('<I', sb[40:44])[0]
    feature_incompat = struct.unpack('<I', sb[96:100])[0]
    feature_ro_compat = struct.unpack('<I', sb[100:104])[0]
    first_ino = struct.unpack('<I', sb[84:88])[0]
    inode_size = struct.unpack('<H', sb[88:90])[0]
    if inode_size == 0:
        inode_size = 128
    
    block_size = 1024 << log_block_size
    
    print(f"Block size: {block_size}")
    print(f"Blocks count: {blocks_count}")
    print(f"Blocks per group: {blocks_per_group}")
    print(f"Inodes per group: {inodes_per_group}")
    print(f"First inode: {first_ino}")
    print(f"Inode size: {inode_size}")
    print(f"Feature incompat: 0x{feature_incompat:08x}")
    print(f"Feature ro_compat: 0x{feature_ro_compat:08x}")
    
    # Calculate number of block groups
    num_groups = (blocks_count + blocks_per_group - 1) // blocks_per_group
    print(f"Number of block groups: {num_groups}")
    
    # Group descriptors are at block 1 (since first_data_block = 1)
    # Each group descriptor is 64 bytes (or 32 for ext2)
    # With 8000 inodes per group and 128 byte inodes:
    # Inode table size per group = 8000 * 128 = 1,024,000 bytes = 250 blocks (4KB each)
    
    # Read group descriptor 0
    gd_offset = FS_START + block_size * 1 + 0  # first group descriptor
    f.seek(gd_offset)
    gd = f.read(64)  # 64 bytes for ext4
    
    print(f"\nGroup 0 descriptor:")
    print(f"  bg_block_bitmap_lo: {struct.unpack('<I', gd[0:4])[0]}")
    print(f"  bg_inode_bitmap_lo: {struct.unpack('<I', gd[4:8])[0]}")
    print(f"  bg_inode_table_lo: {struct.unpack('<I', gd[8:12])[0]}")
    print(f"  bg_free_blocks_count_lo: {struct.unpack('<H', gd[12:14])[0]}")
    print(f"  bg_free_inodes_count_lo: {struct.unpack('<H', gd[14:16])[0]}")
    print(f"  bg_used_dirs_count_lo: {struct.unpack('<H', gd[16:18])[0]}")
    
    inode_table_block = struct.unpack('<I', gd[8:12])[0]
    print(f"\nInode table starts at block: {inode_table_block}")
    
    # Read inode 2 (root)
    inode_offset = FS_START + inode_table_block * block_size + (2 - first_ino) * inode_size
    print(f"Root inode offset: {inode_offset}")
    
    f.seek(inode_offset)
    root_inode = f.read(inode_size)
    
    print(f"Root inode:")
    print(f"  i_mode: {struct.unpack('<H', root_inode[0:2])[0]} (0x{struct.unpack('<H', root_inode[0:2])[0]:04x})")
    print(f"  i_uid: {struct.unpack('<H', root_inode[2:4])[0]}")
    print(f"  i_size: {struct.unpack('<I', root_inode[4:8])[0]}")
    print(f"  i_atime: {struct.unpack('<I', root_inode[8:12])[0]}")
    print(f"  i_ctime: {struct.unpack('<I', root_inode[12:16])[0]}")
    print(f"  i_mtime: {struct.unpack('<I', root_inode[16:20])[0]}")
    print(f"  i_dtime: {struct.unpack('<I', root_inode[20:24])[0]}")
    print(f"  i_gid: {struct.unpack('<H', root_inode[24:26])[0]}")
    print(f"  i_links_count: {struct.unpack('<H', root_inode[26:28])[0]}")
    print(f"  i_blocks_lo: {struct.unpack('<I', root_inode[28:32])[0]}")
    print(f"  i_flags: {struct.unpack('<I', root_inode[32:36])[0]}")
    
    # Check i_mode for directory type (S_IFDIR = 0x4000)
    i_mode = struct.unpack('<H', root_inode[0:2])[0]
    if i_mode & 0xF000 == 0x4000:
        print("  -> IS A DIRECTORY!")
    elif i_mode & 0xF000 == 0x1000:
        print("  -> IS A FIFO!")
    else:
        print(f"  -> Type: {(i_mode >> 12) & 0xF:04x}")
    
    # Read the block pointer
    if hasattr(struct, 'unpack_from'):
        block_ptr = struct.unpack('<I', root_inode[40:44])[0]
        print(f"  i_block[0]: {block_ptr}")