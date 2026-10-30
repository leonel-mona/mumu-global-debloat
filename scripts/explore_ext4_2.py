import ext4
import inspect

# Look at Volume constructor
print("=== Volume.__init__ ===")
print(inspect.signature(ext4.Volume.__init__))
print()

# Look at Directory methods
print("=== opendir ===")
print(inspect.signature(ext4.Directory.opendir))
print()

# Look at how to open a file
print("=== File.open ===")
print(inspect.signature(ext4.File.open))
print()

# Look at Volume.root
print("=== Volume.root ===")
print(inspect.signature(ext4.Volume.root))
print()

# Look at Volume.cursor
print("=== Volume.cursor ===")
print(inspect.signature(ext4.Volume.cursor))
print()

# Look at Volume.block_read
print("=== Volume.block_read ===")
print(inspect.signature(ext4.Volume.block_read))
print()

# Look at Volume.inode_at
print("=== Volume.inode_at ===")
print(inspect.signature(ext4.Volume.inode_at))
print()

# Look at Volume.stream
print("=== Volume.stream ===")
print(inspect.signature(ext4.Volume.stream))
print()

# Look at Volume.seek
print("=== Volume.seek ===")
print(inspect.signature(ext4.Volume.seek))
print()

# Look at Volume.read
print("=== Volume.read ===")
print(inspect.signature(ext4.Volume.read))
print()

# Look at Volume.write
print("=== Volume.write ===")
print(inspect.signature(ext4.Volume.write))
print()

# Look at Volume.inodes
print("=== Volume.inodes ===")
print(inspect.signature(ext4.Volume.inodes))
print()

# Look at Volume.path_tuple
print("=== Volume.path_tuple ===")
print(inspect.signature(ext4.Volume.path_tuple))
print()

# Look at Volume.peek
print("=== Volume.peek ===")
print(inspect.signature(ext4.Volume.peek))