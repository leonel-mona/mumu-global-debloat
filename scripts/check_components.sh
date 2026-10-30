#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E "com.mumu\.(widget|receiver|service)" | head -20