#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -i "Suggest|Recommend|Promotion|Daily|Ad"