#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -A2 'com.mumu.store.widget'