#!/system/bin/sh
# Runtime optimization - apply at every boot

# GPU minimal
setprop debug.sf.latch_unsignaled 1
setprop debug.sf.early_gl_latch 0
setprop debug.sf.hwc_check 0
setprop debug.hwui.sync_buffer 0
setprop debug.hwui.disable_vsync true
setprop debug.hwui.renderer skiavk
setprop debug.hwui.use_gpu_pixel_buffers false
setprop debug.hwui.asset_atlas_max_size 512
setprop debug.hwui.gradient_cache_size 256
setprop debug.hwui.path_cache_size 8
setprop debug.hwui.drop_shadow_cache_size 8
setprop debug.hwui.r_buffer_cache_size 2
setprop debug.hwui.texture_cache_flushrate 0.1
setprop debug.hwui.texture_cache_size 4
setprop debug.hwui.layer_cache_size 8
setprop debug.egl.hw 0
setprop debug.composition.type gpu
setprop debug.sf.disable_backpressure 1

# Kernel memory (if root available)
# sysctl -w vm.swappiness=0
# sysctl -w vm.vfs_cache_pressure=500
# sysctl -w vm.dirty_ratio=5
# sysctl -w vm.dirty_background_ratio=2
# swapoff -a 2>/dev/null
