import ext4
import io

# Open the base system.raw image
with open('D:\\MuMuPlayerGlobal-12.0\\nx_device\\12.0\\vms\\MuMuPlayerGlobal-12.0-base\\system.raw', 'rb') as f:
    # Create a simple stream wrapper
    class RawStream:
        def __init__(self, f):
            self.f = f
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
            self.f.seek(pos, whence)

    stream = RawStream(f)
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