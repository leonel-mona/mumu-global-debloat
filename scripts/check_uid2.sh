#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E "userId|codePath|versionCode|dataDir|flags" | head -10