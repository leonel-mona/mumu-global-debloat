import ext4
import io

# The filesystem starts at offset 168,891,392 in the RAW image
FS_START = 168891392

class RawStream:
    def __init__(self, filepath, fs_start):
        self.f = open(filepath, 'rb')
        self.fs_start = fs_start
        self.f.seek(fs_start)
    
    def read(self, n):
        return self.f.read(n)
    
    def peek(self, n):
        pos = self.f.tell()
        data = self.f.read(n)
        self.f.seek(pos)
        return data
    
    def tell(self):
        return self.f.tell() - self.fs_start
    
    def seek(self, pos, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.f.seek(self.fs_start + pos)
        elif whence == io.SEEK_CUR:
            self.f.seek(pos, io.SEEK_CUR)
        elif whence == io.SEEK_END:
            self.f.seek(pos, io.SEEK_END)
    
    def __len__(self):
        return 2928744960 - self.fs_start

# Open the RAW image
stream = RawStream('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', FS_START)
vol = ext4.Volume(stream)

print(f"Block size: {vol.block_size}")
print(f"Superblock: {vol.superblock}")
print(f"First inode: {vol.superblock.s_first_ino}")
print(f"Inode size: {vol.superblock.s_inode_size}")
print(f"Feature incompat: 0x{vol.superblock.s_feature_incompat:08x}")
print(f"Feature ro_compat: 0x{vol.superblock.s_feature_ro_compat:08x}")

# Check inode 2 manually
print("\n=== Checking inode 2 ===")
inode2 = vol.inodes[2]
print(f"Inode 2 type: {type(inode2)}")
print(f"Inode 2 i_mode: {inode2.i_mode}")
print(f"Inode 2 i_block: {list(inode2.i_block)}")

# Check if it's a directory
i_mode = inode2.i_mode
if i_mode & 0xF000 == 0x4000:
    print("Inode 2 IS A DIRECTORY (correct)")
elif i_mode & 0xF000 == 0x1000:
    print("Inode 2 IS A FIFO (wrong!)")
else:
    print(f"Inode 2 type: {(i_mode >> 12) & 0xF:04x}")

# Try to force cast to Directory
print("\n=== Trying to force cast inode 2 to Directory ===")
from ext4.inode import Directory
try:
    root_dir = Directory(vol, inode2.offset, inode2)
    print(f"Root dir: {root_dir}")
    for entry in root_dir.opendir():
        name = entry[0].name
        print(f"  {name}, inode: {entry[0].inode_no}, type: {entry[0].file_type}")
        if name == 'system':
            sys_dir = entry[1].open()
            print(f"    System dir: {sys_dir}")
            for entry2 in sys_dir.opendir():
                name2 = entry2[0].name
                if name2 == 'priv-app':
                    print(f"    Found priv-app, inode: {entry2[0].inode_no}")
                    priv_dir = entry2[1].open()
                    for entry3 in priv_dir.opendir():
                        name3 = entry3[0].name
                        if 'mumu' in name3.lower():
                            print(f"      Found: {name3}, inode: {entry3[0].inode_no}, type: {entry3[0].file_type}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()