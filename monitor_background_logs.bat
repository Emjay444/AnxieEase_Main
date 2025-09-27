@echo off
echo 📱 ANXIEEASE BACKGROUND NOTIFICATION DEBUG
echo ═════════════════════════════════════════
echo.

echo 1️⃣ Checking if device is connected...
adb devices
if %errorlevel% neq 0 (
    echo ❌ No device connected or ADB not found
    echo 💡 Make sure your phone is connected via USB with USB Debugging enabled
    pause
    exit /b 1
)

echo.
echo 2️⃣ Starting background log monitoring...
echo 🔍 This will capture logs even when app is closed
echo 💡 Leave this running and test notifications in another terminal
echo ⏹️  Press Ctrl+C to stop logging
echo.
echo 📋 Looking for these keywords:
echo    - FCM (Firebase Cloud Messaging)
echo    - AnxieEase (your app)
echo    - BACKGROUND (background handler)
echo    - flutter (Flutter runtime)
echo    - anxiety (notification content)
echo.

REM Filter for relevant logs with timestamp
adb logcat -v time | findstr /i "AnxieEase FCM flutter BACKGROUND anxiety severe mild moderate critical"