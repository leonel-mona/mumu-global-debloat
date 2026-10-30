@echo off
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider"
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider"
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.track.AdTrackingReceiver"
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.track.TrackingReceiver"
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.commerce.receiver.InstalledReceiver"
D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe -s 192.168.1.149:5555 shell su -c "pm disable com.mumu.store/com.mumu.store.BootReceiver"