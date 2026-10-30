import struct

FS_START = 17563648

# Read the superblock
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    f.seek(FS_START + 0x400)
    sb = f.read(1024)
    
    print(f"s_magic: {struct.unpack('<H', sb[56:58])[0]} (expected: 0xEF53)")
    print(f"s_inodes_count: {struct.unpack('<I', sb[0:4])[0]}")
    print(f"s_blocks_count_lo: {struct.unpack('<I', sb[4:8])[0]}")
    print(f"s_r_blocks_count_lo: {struct.unpack('<I', sb[8:12])[0]}")
    print(f"s_free_blocks_count_lo: {struct.unpack('<I', sb[12:16])[0]}")
    print(f"s_free_inodes_count: {struct.unpack('<I', sb[16:20])[0]}")
    print(f"s_first_data_block: {struct.unpack('<I', sb[20:24])[0]}")
    print(f"s_log_block_size: {struct.unpack('<I', sb[24:28])[0]}")
    print(f"s_log_cluster_size: {struct.unpack('<I', sb[28:32])[0]}")
    print(f"s_blocks_per_group: {struct.unpack('<I', sb[32:36])[0]}")
    print(f"s_inodes_per_group: {struct.unpack('<I', sb[40:44])[0]}")
    print(f"s_mtime: {struct.unpack('<I', sb[44:48])[0]}")
    print(f"s_wtime: {struct.unpack('<I', sb[48:52])[0]}")
    print(f"s_mnt_count: {struct.unpack('<H', sb[52:54])[0]}")
    print(f"s_max_mnt_count: {struct.unpack('<H', sb[54:56])[0]}")
    print(f"s_magic: {struct.unpack('<H', sb[56:58])[0]}")
    print(f"s_state: {struct.unpack('<H', sb[58:60])[0]}")
    print(f"s_errors: {struct.unpack('<H', sb[60:62])[0]}")
    print(f"s_minor_rev_level: {struct.unpack('<H', sb[62:64])[0]}")
    print(f"s_lastcheck: {struct.unpack('<I', sb[64:68])[0]}")
    print(f"s_checkinterval: {struct.unpack('<I', sb[68:72])[0]}")
    print(f"s_creator_os: {struct.unpack('<I', sb[72:76])[0]}")
    print(f"s_rev_level: {struct.unpack('<I', sb[76:80])[0]}")
    print(f"s_def_resuid: {struct.unpack('<H', sb[80:82])[0]}")
    print(f"s_def_resgid: {struct.unpack('<H', sb[82:84])[0]}")
    print(f"s_first_ino: {struct.unpack('<I', sb[84:88])[0]}")
    print(f"s_inode_size: {struct.unpack('<H', sb[88:90])[0]}")
    print(f"s_block_group_nr: {struct.unpack('<H', sb[90:92])[0]}")
    print(f"s_feature_compat: {struct.unpack('<I', sb[92:96])[0]}")
    print(f"s_feature_incompat: {struct.unpack('<I', sb[96:100])[0]}")
    print(f"s_feature_ro_compat: {struct.unpack('<I', sb[100:104])[0]}")
    
    # UUID
    print(f"UUID: {sb[104:120].hex()}")
    
    # Volume name
    print(f"Volume name: {sb[120:136].decode('ascii', errors='replace')}")
    
    # Last mounted
    print(f"Last mounted: {sb[136:200].decode('ascii', errors='replace')}")
    
    # Algorithm usage bitmap
    print(f"s_algo_bitmap: {struct.unpack('<I', sb[200:204])[0]}")
    
    # Block size calculation
    log_block_size = struct.unpack('<I', sb[24:28])[0]
    block_size = 1024 << log_block_size
    print(f"\nCalculated block size: {block_size}")
    
    # Inode size
    inode_size = struct.unpack('<H', sb[88:90])[0]
    if inode_size == 0:
        inode_size = 128
    print(f"Inode size: {inode_size}")
    
    # First inode
    first_ino = struct.unpack('<I', sb[84:88])[0]
    print(f"First inode: {first_ino}")
    
    # Blocks per group
    blocks_per_group = struct.unpack('<I', sb[32:36])[0]
    print(f"Blocks per group: {blocks_per_group}")
    
    # Inodes per group
    inodes_per_group = struct.unpack('<I', sb[40:44])[0]
    print(f"Inodes per group: {inodes_per_group}")
    
    # Feature flags
    feature_compat = struct.unpack('<I', sb[92:96])[0]
    feature_incompat = struct.unpack('<I', sb[96:100])[0]
    feature_ro_compat = struct.unpack('<I', sb[100:104])[0]
    print(f"\nFeature compat: 0x{feature_compat:08x}")
    print(f"Feature incompat: 0x{feature_incompat:08x}")
    print(f"Feature ro_compat: 0x{feature_ro_compat:08x}")
    
    # Check for extents (bit 6 of incompat)
    has_extents = bool(feature_incompat & 0x40)
    print(f"Has extents: {has_extents}")
    
    # Check for 64bit (bit 5 of ro_compat)
    has_64bit = bool(feature_ro_compat & 0x20)
    print(f"Has 64bit: {has_64bit}")
    
    # Check for flex_bg (bit 9 of ro_compat)
    has_flex_bg = bool(feature_ro_compat & 0x200)
    print(f"Has flex_bg: {has_flex_bg}")