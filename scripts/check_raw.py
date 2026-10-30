import struct

# Check what's at the beginning of the RAW image
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    # Read first 1MB
    data = f.read(1024 * 1024)
    
    # Check for GPT signature
    print("Checking for GPT...")
    if data[512:520] == b'EFI PART':
        print("  GPT signature found at offset 512")
    else:
        print(f"  No GPT at 512: {data[512:520].hex()}")
    
    # Check for MBR signature
    print("Checking for MBR...")
    if data[510:512] == b'\x55\xaa':
        print("  MBR signature found at offset 510")
    else:
        print(f"  No MBR at 510: {data[510:512].hex()}")
    
    # Check for ext4 magic at various offsets
    print("Checking for ext4 magic at various offsets...")
    for offset in [0x400, 0x438, 0x400 + 0x400, 0x400 + 0x438, 0x800, 0x838, 0x1000, 0x1038, 0x1000 + 0x438]:
        if offset + 2 <= len(data):
            magic = data[offset:offset+2]
            if magic == b'\x53\xef':
                print(f"  Found ext4 magic at offset {offset} (0x{offset:x})")
    
    # Check what's at offset 17564728
    f.seek(17564728)
    magic_at_17564728 = f.read(2)
    print(f"Magic at 17564728: {magic_at_17564728.hex()}")
    
    # Read the superblock at that location
    f.seek(17564728 - 0x38)  # superblock starts 0x38 before magic
    sb = f.read(1024)
    print(f"Superblock at offset {17564728 - 0x38}:")
    print(f"  s_inodes_count: {struct.unpack('<I', sb[0:4])[0]}")
    print(f"  s_blocks_count_lo: {struct.unpack('<I', sb[4:8])[0]}")
    print(f"  s_log_block_size: {struct.unpack('<I', sb[24:28])[0]}")
    print(f"  s_blocks_per_group: {struct.unpack('<I', sb[32:36])[0]}")
    print(f"  s_inodes_per_group: {struct.unpack('<I', sb[40:44])[0]}")
    print(f"  s_magic: {struct.unpack('<H', sb[56:58])[0]}")
    
    # Calculate where the filesystem starts
    # The superblock is at offset 17564728 - 0x38 = 17564680
    # In ext4, the superblock is at offset 0x400 from the start of the filesystem
    # So filesystem starts at 17564680 - 0x400 = 17562680
    fs_start = 17564680 - 0x400
    print(f"Filesystem start offset: {fs_start} (0x{fs_start:x})")
    print(f"Filesystem start block (1KB blocks): {fs_start // 1024}")