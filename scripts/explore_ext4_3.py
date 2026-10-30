import ext4
import inspect

# Look at Volume class
print("=== Volume class ===")
print(inspect.getsource(ext4.Volume.__init__))
print()

# Look at Volume.root
print("=== Volume.root ===")
print(inspect.getsource(ext4.Volume.root.fget))
print()

# Look at Volume.cursor
print("=== Volume.cursor ===")
print(inspect.getsource(ext4.Volume.cursor.fget))
print()

# Look at Volume.block_read
print("=== Volume.block_read ===")
print(inspect.getsource(ext4.Volume.block_read))
print()

# Look at Volume.inode_at
print("=== Volume.inode_at ===")
print(inspect.getsource(ext4.Volume.inode_at))
print()

# Look at Volume.stream
print("=== Volume.stream ===")
print(inspect.getsource(ext4.Volume.stream.fget))
print()

# Look at Volume.seek
print("=== Volume.seek ===")
print(inspect.getsource(ext4.Volume.seek))
print()

# Look at Volume.read
print("=== Volume.read ===")
print(inspect.getsource(ext4.Volume.read))
print()

# Look at Volume.write
print("=== Volume.write ===")
print(inspect.getsource(ext4.Volume.write))
print()

# Look at Volume.inodes
print("=== Volume.inodes ===")
print(inspect.getsource(ext4.Volume.inodes))
print()

# Look at Volume.path_tuple
print("=== Volume.path_tuple ===")
print(inspect.getsource(ext4.Volume.path_tuple))
print()

# Look at Volume.peek
print("=== Volume.peek ===")
print(inspect.getsource(ext4.Volume.peek))