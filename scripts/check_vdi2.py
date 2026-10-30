import struct

CBLOCK = 1048576
OFF_BLOCKS = 1048576
OFF_DATA = 2097152
CBLOCKS = 2794

# Read VDI block map
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as f:
    f.seek(OFF_BLOCKS)
    buf = f.read(CBLOCKS * 4)
    block_map = struct.unpack(f'<{CBLOCKS}i', buf)
    
    # The filesystem starts at offset 17563648 in the RAW image
    # That's 17563648 / 1048576 = 16.75 blocks
    # So the filesystem starts in logical block 16 (0-indexed)
    fs_start_block = 17563648 // CBLOCK
    fs_start_offset = 17563648 % CBLOCK
    print(f"Filesystem starts at logical block {fs_start_block}, offset {fs_start_offset} (0x{fs_start_offset:x})")
    
    # Check block map for this block
    phys_block = block_map[fs_start_block]
    print(f"Logical block {fs_start_block} -> Physical block {phys_block}")
    
    if phys_block >= 0:
        # Read the superblock from the VDI
        # Superblock is at fs_start_offset + 0x400 within the logical block
        sb_offset = OFF_DATA + phys_block * CBLOCK + fs_start_offset + 0x400
        f.seek(sb_offset)
        magic = f.read(2)
        print(f"Magic at VDI offset {sb_offset}: {magic.hex()}")
        
        # Read the full superblock
        f.seek(sb_offset)
        sb = f.read(1024)
        print(f"s_magic: {struct.unpack('<H', sb[56:58])[0]}")
        print(f"s_inodes_count: {struct.unpack('<I', sb[0:4])[0]}")
        print(f"s_blocks_count_lo: {struct.unpack('<I', sb[4:8])[0]}")
        print(f"s_log_block_size: {struct.unpack('<I', sb[24:28])[0]}")
        
        # The superblock is at offset 0x400 from the start of the filesystem
        # In the VDI, the filesystem starts at:
        #   OFF_DATA + phys_block * CBLOCK + fs_start_offset
        # So the superblock is at:
        #   OFF_DATA + phys_block * CBLOCK + fs_start_offset + 0x400
        fs_start_vdi = OFF_DATA + phys_block * CBLOCK + fs_start_offset
        print(f"Filesystem start in VDI: {fs_start_vdi} (0x{fs_start_vdi:x})")