import struct

FS_START = 168891392

with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    # Check backup superblocks at each block group
    # First superblock at offset 168891392 + 0x400 = 168892416 (we already found this)
    # Backup superblocks at blocks 32768, 2*32768, etc. (every blocks_per_group)
    
    # Read first superblock to get parameters
    f.seek(FS_START + 0x400)
    sb = f.read(1024)
    
    block_size = 1024 << struct.unpack('<I', sb[24:28])[0]
    blocks_per_group = struct.unpack('<I', sb[32:36])[0]
    feature_ro_compat = struct.unpack('<I', sb[100:104])[0]
    has_sparse_super = bool(feature_ro_compat & 0x1)
    has_flex_bg = bool(feature_ro_compat & 0x200)
    print(f"Block size: {block_size}")
    print(f"Blocks per group: {blocks_per_group}")
    print(f"Has sparse_super: {has_sparse_super}")
    print(f"Has flex_bg: {has_flex_bg}")
    
    # Check superblocks at group 0, 1, 3, 5, 7, etc. (sparse superblock algorithm)
    # With sparse_super=1, backups are at groups 0, 1, 3, 5, 7, 9...
    # With flex_bg=1, groups are grouped in flex_bg_size (2^s_log_groups_per_flex)
    
    # Let's check the superblock at the start of each group
    for g in range(18):
        group_start = FS_START + g * blocks_per_group * block_size
        f.seek(group_start + 0x400)
        sb_data = f.read(1024)
        magic = sb_data[0x38:0x3a]
        if magic == b'\x53\xef':
            inodes_count = struct.unpack('<I', sb_data[0:4])[0]
            blocks_count = struct.unpack('<I', sb_data[4:8])[0]
            log_block_size = struct.unpack('<I', sb_data[24:28])[0]
            blocks_per_group_check = struct.unpack('<I', sb_data[32:36])[0]
            inodes_per_group_check = struct.unpack('<I', sb_data[40:44])[0]
            first_ino_check = struct.unpack('<I', sb_data[84:88])[0]
            inode_size_check = struct.unpack('<H', sb_data[88:90])[0]
            
            print(f"\nGroup {g} superblock:")
            print(f"  Offset: {group_start + 0x400}")
            print(f"  inodes_count: {inodes_count}")
            print(f"  blocks_count: {blocks_count}")
            print(f"  log_block_size: {log_block_size}")
            print(f"  blocks_per_group: {blocks_per_group_check}")
            print(f"  inodes_per_group: {inodes_per_group_check}")
            print(f"  first_ino: {first_ino_check}")
            print(f"  inode_size: {inode_size_check}")
            
            # Read group descriptor for this group
            if g == 0:
                # Group 0 descriptor is at block 1
                gd_offset = FS_START + block_size
            else:
                # Other groups have their descriptor at the start of the group
                gd_offset = group_start
            f.seek(gd_offset)
            gd = f.read(64)  # 64 bytes for 64bit
            bg_block_bitmap = struct.unpack('<Q', gd[0:8])[0]
            bg_inode_bitmap = struct.unpack('<Q', gd[8:16])[0]
            bg_inode_table = struct.unpack('<Q', gd[16:24])[0]
            print(f"  bg_block_bitmap: {bg_block_bitmap}")
            print(f"  bg_inode_bitmap: {bg_inode_bitmap}")
            print(f"  bg_inode_table: {bg_inode_table}")
            
            if bg_inode_table > 0:
                # Check inode 2 in this group
                if inode_size_check == 0:
                    inode_size_check = 128
                inode_offset = FS_START + bg_inode_table * block_size + (2 - first_ino_check) * inode_size_check
                f.seek(inode_offset)
                root_inode = f.read(inode_size_check)
                i_mode = struct.unpack('<H', root_inode[0:2])[0]
                if i_mode & 0xF000 == 0x4000:
                    print(f"  -> Inode 2 is DIRECTORY! i_block0: {struct.unpack('<I', root_inode[40:44])[0]}")
                elif i_mode & 0xF000 == 0x1000:
                    print(f"  -> Inode 2 is FIFO")
                else:
                    print(f"  -> Inode 2 type: {(i_mode >> 12) & 0xF:04x}, mode: 0x{i_mode:04x}")