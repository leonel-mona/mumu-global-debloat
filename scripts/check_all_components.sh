#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E "com.mumu.store\." | grep -E "Activity|Service|Receiver|Provider|Widget" | head -60