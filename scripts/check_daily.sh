#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -A5 -B5 "DailyDiscovery"