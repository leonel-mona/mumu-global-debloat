#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E 'Provider|provider' | head -20