#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E 'state: (enabled|disabled)' | head -30