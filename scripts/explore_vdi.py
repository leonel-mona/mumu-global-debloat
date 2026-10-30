import ext4
import io
import struct

# VDI structure (from merge_diff.ps1):
# cbBlock = 1048576 (1MB)
# offBlocks = 1048576 (1MB) - start of block map
# offData = 2097152 (2MB) - start of data area
# cBlocks = 2794
# Block map: array of int32, each value is physical block index or -1

CBLOCK = 1048576
OFF_BLOCKS = 1048576
OFF_DATA = 2097152
CBLOCKS = 2794

class VDIStream:
    def __init__(self, filepath):
        self.f = open(filepath, 'rb')
        # Read block map
        self.f.seek(OFF_BLOCKS)
        buf = self.f.read(CBLOCKS * 4)
        self.block_map = struct.unpack(f'<{CBLOCKS}i', buf)
        # Count allocated blocks
        self.allocated = sum(1 for b in self.block_map if b != -1)
        print(f"VDI: {self.allocated}/{CBLOCKS} blocks allocated")
        # Map logical block -> physical offset
        self.logical_to_phys = {}
        phys_block = 0
        for i, b in enumerate(self.block_map):
            if b != -1:
                self.logical_to_phys[i] = OFF_DATA + b * CBLOCK
    
    def _logical_to_offset(self, logical_block):
        """Convert logical block number to file offset"""
        if logical_block not in self.logical_to_phys:
            return None
        return self.logical_to_phys[logical_block]
    
    def read(self, n):
        return self.f.read(n)
    
    def peek(self, n):
        pos = self.f.tell()
        data = self.f.read(n)
        self.f.seek(pos)
        return data
    
    def tell(self):
        return self.f.tell()
    
    def seek(self, pos, whence=io.SEEK_SET):
        # ext4 library seeks to absolute positions within the filesystem
        # We need to convert logical block positions to file offsets
        if whence == io.SEEK_SET:
            # pos is a logical block number * block_size
            # Convert to file offset
            block_num = pos // CBLOCK
            offset_in_block = pos % CBLOCK
            file_offset = self._logical_to_offset(block_num)
            if file_offset is None:
                # Block is not allocated, seek to a dummy position
                self.f.seek(OFF_DATA)
            else:
                self.f.seek(file_offset + offset_in_block)
        elif whence == io.SEEK_CUR:
            self.f.seek(pos, io.SEEK_CUR)
        elif whence == io.SEEK_END:
            self.f.seek(pos, io.SEEK_END)
    
    def __len__(self):
        return OFF_DATA + self.allocated * CBLOCK

# Open the base system.vdi
stream = VDIStream('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.vdi')
vol = ext4.Volume(stream)

print(f"Block size: {vol.block_size}")
print(f"Root inode: {vol.root}")

# Navigate to /system
root = vol.root
for entry in root.opendir():
    name = entry[0].name
    if name == 'system':
        print(f"Found system, inode: {entry[0].inode_no}")
        sys_dir = entry[1].open()
        print(f"System dir: {sys_dir}")

        # Navigate to /system/priv-app
        for entry2 in sys_dir.opendir():
            name2 = entry2[0].name
            if name2 == 'priv-app':
                print(f"Found priv-app, inode: {entry2[0].inode_no}")
                priv_dir = entry2[1].open()

                # Look for com.mumu.store
                for entry3 in priv_dir.opendir():
                    name3 = entry3[0].name
                    if 'mumu' in name3.lower():
                        print(f"  Found: {name3}, inode: {entry3[0].inode_no}, type: {entry3[0].file_type}")
                        if name3 == 'com.mumu.store':
                            store_dir = entry3[1].open()
                            print(f"  Store dir contents:")
                            for entry4 in store_dir.opendir():
                                print(f"    {entry4[0].name}, inode: {entry4[0].inode_no}")