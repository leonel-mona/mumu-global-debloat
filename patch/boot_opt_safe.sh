#!/system/bin/sh
# Boot optimization - SAFE version (no freeze)
# Solo para servicios que NO afectan el boot

# HALs mock (seguros, no afectan boot)
setprop ctl.stop vendor.bluetooth-1-1 2>/dev/null
setprop ctl.stop vendor.camera-provider-2-4 2>/dev/null
setprop ctl.stop vendor.gnss-2-0 2>/dev/null
setprop ctl.stop vendor.sensors-hal-2-1-multihal 2>/dev/null
setprop ctl.stop vendor.vibrator-1-3 2>/dev/null
setprop ctl.stop vendor.power.stats-hal-1-0-mock 2>/dev/null

# GPU tuning
setprop debug.sf.latch_unsignaled 1
setprop debug.sf.early_gl_latch 0
setprop debug.sf.hwc_check 0
setprop debug.hwui.sync_buffer 0
setprop debug.hwui.force_dark_mode 0