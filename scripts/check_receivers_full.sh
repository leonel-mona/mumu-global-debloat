#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E "Receiver|receiver|Widget|widget|DailyDiscovery|Suggestion|Promotion|AdBanner"