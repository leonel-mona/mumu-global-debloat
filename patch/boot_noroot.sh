#!/system/bin/sh
# Simplified boot script - only sysctls

su -c 'sysctl -w vm.swappiness=0'
su -c 'sysctl -w vm.vfs_cache_pressure=500'
