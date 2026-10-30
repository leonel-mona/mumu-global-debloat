import struct

# Search for the REAL ext4 superblock in the RAW image
# A valid ext4 superblock has:
# - s_magic = 0xEF53 at offset 0x38
# - s_inodes_count > 1000
# - s_blocks_count_lo > 100000
# - s_log_block_size between 0 and 2
# - s_blocks_per_group > 1000
# - s_inodes_per_group > 100

with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    # Search every 1024 bytes for ext4 magic
    f.seek(0)
    offset = 0
    found = []
    
    while True:
        data = f.read(4096)
        if not data:
            break
        
        for i in range(0, len(data) - 1024, 1024):
            # Check magic at offset 0x38 within the 1KB block
            magic = data[i + 0x38:i + 0x3a]
            if magic == b'\x53\xef':
                # Read superblock
                sb = data[i:i + 1024]
                inodes_count = struct.unpack('<I', sb[0:4])[0]
                blocks_count = struct.unpack('<I', sb[4:8])[0]
                log_block_size = struct.unpack('<I', sb[24:28])[0]
                blocks_per_group = struct.unpack('<I', sb[32:36])[0]
                inodes_per_group = struct.unpack('<I', sb[40:44])[0]
                
                # Check if this looks like a valid ext4 superblock
                if (inodes_count > 1000 and 
                    blocks_count > 100000 and 
                    0 <= log_block_size <= 2 and
                    blocks_per_group > 1000 and
                    inodes_per_group > 100):
                    found.append({
                        'offset': offset + i,
                        'inodes_count': inodes_count,
                        'blocks_count': blocks_count,
                        'log_block_size': log_block_size,
                        'blocks_per_group': blocks_per_group,
                        'inodes_per_group': inodes_per_group
                    })
                    print(f"Found valid ext4 superblock at offset {offset + i} (0x{offset + i:x})")
                    print(f"  inodes_count: {inodes_count}")
                    print(f"  blocks_count: {blocks_count}")
                    print(f"  log_block_size: {log_block_size}")
                    print(f"  blocks_per_group: {blocks_per_group}")
                    print(f"  inodes_per_group: {inodes_per_group}")
                    print(f"  block_size: {1024 << log_block_size}")
                    print()
        
        offset += len(data)
    
    if not found:
        print("No valid ext4 superblock found!")
    else:
        print(f"Found {len(found)} valid ext4 superblocks")
        
        # The first one is likely the root
        first = found[0]
        print(f"\nUsing first superblock at offset {first['offset']}")
        print(f"Filesystem starts at offset: {first['offset'] - 0x400}")