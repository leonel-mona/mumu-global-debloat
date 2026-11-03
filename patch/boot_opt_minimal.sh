#!/system/bin/sh
# Boot optimization - MINIMAL (no service stops, no freeze)
# Solo GPU tuning - seguro

setprop debug.sf.latch_unsignaled 1
setprop debug.sf.early_gl_latch 0
setprop debug.sf.hwc_check 0
setprop debug.hwui.sync_buffer 0
setprop debug.hwui.force_dark_mode 0