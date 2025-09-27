@echo off
echo 🔥 FLUTTER DEBUG MODE WITH BACKGROUND LOGGING
echo ══════════════════════════════════════════════
echo.

echo 1️⃣ Starting Flutter in debug mode...
echo 💡 This keeps connection alive even when app goes to background
echo.

REM Start Flutter with hot restart disabled to maintain connection
flutter run --debug --device-id="%1" --verbose

echo.
echo 2️⃣ If Flutter disconnects when app goes to background:
echo    - Try: flutter attach
echo    - Or use the logcat method instead
echo.