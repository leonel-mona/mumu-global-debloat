import struct

# Let's check what's in the base system.vdi at the blocks corresponding to the diff blocks
# The diff has blocks at logical blocks 33, 34, 35, 65, 1634, 1663, etc.

with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as base_f:
    # Read base block map
    base_f.seek(0x100000)
    buf = base_f.read(2794 * 4)
    base_map = struct.unpack('<2794i', buf)
    
    # Check the same logical blocks in the base
    diff_blocks = [33, 34, 35, 65, 1634, 1663]
    for log_block in diff_blocks:
        phys_block = base_map[log_block]
        print(f"Base logical block {log_block} -> phys {phys_block}")
        
        if phys_block >= 0:
            base_f.seek(0x200000 + phys_block * 1048576)
            data = base_f.read(1024)
            # Check for ext4 magic
            if data[0x438:0x43a] == b'\x53\xef':
                print(f"  -> Contains ext4 superblock!")
            elif b'priv-app' in data[:1024]:
                print(f"  -> Contains priv-app")
            elif b'mumu' in data[:1024]:
                print(f"  -> Contains mumu")

# Now let's look at the RAW image to find where /system/priv-app is
# The filesystem starts at offset 168891392 in the RAW image
FS_START = 168891392

# Read superblock to find block size
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    f.seek(FS_START + 0x400)
    sb = f.read(1024)
    log_block_size = struct.unpack('<I', sb[24:28])[0]
    block_size = 1024 << log_block_size
    print(f"\nFilesystem block size: {block_size}")
    
    # Find inode table for root directory
    f.seek(FS_START + block_size * 1)  # group descriptor at block 1
    gd = f.read(64)
    inode_table_block = struct.unpack('<I', gd[8:12])[0]
    print(f"Inode table at block: {inode_table_block}")
    
    # Read root inode (inode 2)
    first_ino = struct.unpack('<I', sb[84:88])[0]
    inode_size = struct.unpack('<H', sb[88:90])[0]
    if inode_size == 0:
        inode_size = 128
    
    inode_offset = FS_START + inode_table_block * block_size + (2 - first_ino) * inode_size
    f.seek(inode_offset)
    root_inode = f.read(inode_size)
    
    # Get i_block[0] - first data block of root directory
    i_block0 = struct.unpack('<I', root_inode[40:44])[0]
    print(f"Root directory first block: {i_block0}")
    
    # Read root directory entries
    f.seek(FS_START + i_block0 * block_size)
    dir_data = f.read(block_size)
    
    # Parse directory entries
    offset = 0
    while offset < block_size:
        if offset + 8 > len(dir_data):
            break
        inode = struct.unpack('<I', dir_data[offset:offset+4])[0]
        rec_len = struct.unpack('<H', dir_data[offset+4:offset+6])[0]
        name_len = dir_data[offset+6]
        file_type = dir_data[offset+7]
        
        if inode == 0:
            break
        
        if offset + 8 + name_len > len(dir_data):
            break
        name = dir_data[offset+8:offset+8+name_len].decode('ascii', errors='replace')
        
        if name in ['system', 'priv-app', 'etc', 'vendor', 'product', 'apex']:
            print(f"  Found: {name}, inode: {inode}, rec_len: {rec_len}, type: {file_type}")
        
        if name == 'system':
            sys_inode = inode
        
        offset += rec_len
    
    # Now find /system/priv-app
    if 'sys_inode' in locals():
        # Read system inode
        inode_offset = FS_START + inode_table_block * block_size + (sys_inode - first_ino) * inode_size
        f.seek(inode_offset)
        sys_inode_data = f.read(inode_size)
        sys_block0 = struct.unpack('<I', sys_inode_data[40:44])[0]
        print(f"\nSystem directory first block: {sys_block0}")
        
        # Read system directory
        f.seek(FS_START + sys_block0 * block_size)
        sys_dir_data = f.read(block_size)
        
        offset = 0
        while offset < block_size:
            if offset + 8 > len(sys_dir_data):
                break
            inode = struct.unpack('<I', sys_dir_data[offset:offset+4])[0]
            rec_len = struct.unpack('<H', sys_dir_data[offset+4:offset+6])[0]
            name_len = sys_dir_data[offset+6]
            file_type = sys_dir_data[offset+7]
            
            if inode == 0:
                break
            
            if offset + 8 + name_len > len(sys_dir_data):
                break
            name = sys_dir_data[offset+8:offset+8+name_len].decode('ascii', errors='replace')
            
            if name in ['priv-app', 'bin', 'lib', 'lib64', 'etc', 'app']:
                print(f"  Found in /system: {name}, inode: {inode}, rec_len: {rec_len}, type: {file_type}")
            
            if name == 'priv-app':
                priv_inode = inode
            
            offset += rec_len
        
        # Now find /system/priv-app/com.mumu.store
        if 'priv_inode' in locals():
            inode_offset = FS_START + inode_table_block * block_size + (priv_inode - first_ino) * inode_size
            f.seek(inode_offset)
            priv_inode_data = f.read(inode_size)
            priv_block0 = struct.unpack('<I', priv_inode_data[40:44])[0]
            print(f"\nPriv-app directory first block: {priv_block0}")
            
            # Read priv-app directory
            f.seek(FS_START + priv_block0 * block_size)
            priv_dir_data = f.read(block_size)
            
            offset = 0
            while offset < block_size:
                if offset + 8 > len(priv_dir_data):
                    break
                inode = struct.unpack('<I', priv_dir_data[offset:offset+4])[0]
                rec_len = struct.unpack('<H', priv_dir_data[offset+4:offset+6])[0]
                name_len = priv_dir_data[offset+6]
                file_type = priv_dir_data[offset+7]
                
                if inode == 0:
                    break
                
                if offset + 8 + name_len > len(priv_dir_data):
                    break
                name = priv_dir_data[offset+8:offset+8+name_len].decode('ascii', errors='replace')
                
                if 'mumu' in name.lower():
                    print(f"  Found in /system/priv-app: {name}, inode: {inode}, rec_len: {rec_len}, type: {file_type}")
                
                offset += rec_len