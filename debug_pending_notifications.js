// Debug script to check what notifications are stored locally
const { exec } = require("child_process");
const path = require("path");

console.log("📱 Debug: Checking pending notifications in SharedPreferences");
console.log("═══════════════════════════════════════════════════════════");

// For Android, we can use adb to check SharedPreferences
// This is a simplified check - in reality SharedPreferences are in app's private data

const packageName = "com.anxieease.app"; // Your Flutter app package name
const prefsFile = `shared_prefs/FlutterSecureStorage.xml`;

console.log("🔍 Checking if we can access SharedPreferences via adb...");

exec("adb devices", (error, stdout, stderr) => {
  if (error) {
    console.log("❌ ADB not available or no device connected");
    console.log("💡 To manually check pending notifications:");
    console.log("   1. Add debug logs in your Flutter app");
    console.log("   2. Check flutter logs during app startup");
    console.log('   3. Look for "_syncPendingNotifications" logs');
    return;
  }

  console.log("📱 Connected devices:");
  console.log(stdout);

  // Try to check if app is installed
  exec(
    `adb shell pm list packages | grep ${packageName}`,
    (error, stdout, stderr) => {
      if (stdout.trim()) {
        console.log(`✅ App ${packageName} is installed`);
        console.log("💡 For SharedPreferences data, check Flutter debug logs");
        console.log(
          '   The pending notifications are stored with key "pending_notifications"'
        );
      } else {
        console.log(`❌ App ${packageName} not found on device`);
      }
    }
  );
});

console.log("\n📝 Expected SharedPreferences structure:");
console.log('Key: "pending_notifications"');
console.log("Value: List of strings in format:");
console.log('  "title|message|severity|timestamp"');
console.log("\n🔍 Check Flutter logs for these debug messages:");
console.log('  - "📥 Found X pending notifications:"');
console.log('  - "💾 Syncing notification: [title]"');
console.log('  - "✅ Synced: [title]"');
