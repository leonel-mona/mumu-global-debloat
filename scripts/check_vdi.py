import struct

# VDI structure
CBLOCK = 1048576
OFF_BLOCKS = 1048576
OFF_DATA = 2097152
CBLOCKS = 2794

# Read block map
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi', 'rb') as f:
    f.seek(OFF_BLOCKS)
    buf = f.read(CBLOCKS * 4)
    block_map = struct.unpack(f'<{CBLOCKS}i', buf)
    
    # First logical block (where superblock should be at 0x400)
    first_logical = block_map[0]
    print(f"Logical block 0 -> Physical block {first_logical}")
    
    if first_logical >= 0:
        # Read the first 0x400 bytes of the logical block (should contain ext4 superblock)
        offset = OFF_DATA + first_logical * CBLOCK + 0x400
        f.seek(offset)
        magic = f.read(2)
        print(f"Magic bytes at 0x400: {magic.hex()} (expected: 53ef)")
        
        # Read more superblock data
        f.seek(offset)
        sb = f.read(1024)
        print(f"First 64 bytes of superblock: {sb[:64].hex()}")
        
        # s_magic is at offset 0x38 in superblock structure (0x400 + 0x38 = 0x438)
        f.seek(offset + 0x38)
        s_magic = f.read(2)
        print(f"s_magic at 0x438: {s_magic.hex()}")
    else:
        print("First logical block is not allocated!")