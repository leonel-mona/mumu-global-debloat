#!/system/bin/sh
logcat -d 2>&1 | grep -i "store\|install" | tail -20