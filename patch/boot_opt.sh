#!/system/bin/sh
# boot_opt.sh - SAFE boot optimization (no freeze)
# Solo para HALs mock de hardware inexistente en VM
# NO toca servicios del framework (statsd, traced, zygote_secondary, etc)
# Se ejecuta como /data/local/tmp/boot_opt.sh

# Solo HALs mock - hardware que NO existe en una VM
setprop ctl.stop vendor.bluetooth-1-1 2>/dev/null
setprop ctl.stop vendor.camera-provider-2-4 2>/dev/null
setprop ctl.stop vendor.gnss-2-0 2>/dev/null
setprop ctl.stop vendor.sensors-hal-2-1-multihal 2>/dev/null
setprop ctl.stop vendor.vibrator-1-3 2>/dev/null
setprop ctl.stop vendor.power.stats-hal-1-0-mock 2>/dev/null
setprop ctl.stop vendor.gatekeeper-1-0 2>/dev/null

# GPU tuning (seguro, no afecta boot)
setprop debug.sf.latch_unsignaled 1
setprop debug.sf.early_gl_latch 0
setprop debug.sf.hwc_check 0
setprop debug.hwui.sync_buffer 0
setprop debug.hwui.force_dark_mode 0