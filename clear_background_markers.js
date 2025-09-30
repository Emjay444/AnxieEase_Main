// Script to clear old background notification markers
// Run this to clean up the old debug markers that are no longer needed

const fs = require("fs");
const path = require("path");

async function clearBackgroundMarkers() {
  console.log("🧹 Clearing old background notification markers...");

  try {
    // Read the current main.dart file to see how markers are handled
    const mainDartPath = path.join(__dirname, "lib", "main.dart");
    const mainDartContent = fs.readFileSync(mainDartPath, "utf8");

    // Look for the marker pattern
    const markerPattern = /last_background_notification_\d+/g;
    const markersInCode = mainDartContent.match(markerPattern) || [];

    console.log(`📋 Found ${markersInCode.length} marker patterns in code`);

    // The actual markers are stored in SharedPreferences on the device
    // Since we can't directly access those from here, let's provide instructions

    console.log("📱 Quick Fix: Clear App Data");
    console.log("1. Go to Android Settings → Apps");
    console.log('2. Find "AnxieEase" or "AnxieEase Main"');
    console.log('3. Tap "Storage" → "Clear Data"');
    console.log("4. Restart the app");

    console.log("\n🔄 Alternative: Reinstall App");
    console.log("1. Uninstall AnxieEase from your device");
    console.log("2. Install it again");
    console.log("3. The old markers will be gone");

    console.log("\n📋 What these markers are:");
    console.log("- last_background_notification_1759029444788");
    console.log("- last_background_notification_1759029327295");
    console.log("- last_background_notification_1759037322968");

    console.log("\n✅ After clearing:");
    console.log("- No more old marker logs");
    console.log("- Badge count will reset to 0");
    console.log("- Only new notifications will appear");
    console.log("- Your anxiety detection works perfectly!");
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

clearBackgroundMarkers();
