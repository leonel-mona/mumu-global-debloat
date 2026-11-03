@echo off
REM MuMu APK Installer - Windows integration
REM Use this to install APKs via double-click or drag-and-drop
REM This calls MuMuManager.exe control app install command

set "MUMU_MANAGER=D:\MuMuPlayerGlobal-12.0\nx_main\MuMuManager.exe"
set "VM_INDEX=1"
set "APK_PATH=%~1"

if "%APK_PATH%"=="" (
    echo Usage: install_apk.bat ^<apppath^>
    echo Drag an APK file onto this script to install it
    pause
    exit /b 1
)

if not exist "%APK_PATH%" (
    echo Error: File not found: %APK_PATH%
    pause
    exit /b 1
)

echo =============================================
echo   MuMu APK Installer (Custom Build)
echo =============================================
echo Installing: %APK_PATH%
"%MUMU_MANAGER%" control --vmindex %VM_INDEX% app install --apk "%APK_PATH%"
if %errorlevel% equ 0 (
    echo.
    echo SUCCESS - APK installed on MuMu VM %VM_INDEX%
) else (
    echo.
    echo FAILED - Could not install APK
)
pause