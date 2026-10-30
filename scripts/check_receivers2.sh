#!/system/bin/sh
dumpsys package com.mumu.store 2>&1 | grep -E "BootReceiver|TrackingReceiver|AdTrackingReceiver|InstallationReceiver|WidgetOperateReceiver|AdBannerWidgetProvider"