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
print(f"Feature incompat: {vol.superblock.s_feature_incompat}")
print(f"Feature ro_compat: {vol.superblock.s_feature_ro_compat}")

# Check root inode directly
root_inode = vol.inodes[2]
print(f"Root inode type: {type(root_inode)}")
print(f"Root inode mode: {root_inode.i_mode}")
print(f"Root inode i_block: {root_inode.i_block}")

# Try to open root
try:
    root = vol.root
    print(f"Root directory: {root}")
except Exception as e:
    print(f"Error opening root: {e}")

# Try to navigate manually
print("\nTrying to open root directory via inode...")
root_dir = root_inode.open()
print(f"Root dir type: {type(root_dir)}")

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
                        if name3 == 'com.mumu.store':
                            store_dir = entry3[1].open()
                            print(f"      Store dir contents:")
                            for entry4 in store_dir.opendir():
                                print(f"        {entry4[0].name}, inode: {entry4[0].inode_no}")