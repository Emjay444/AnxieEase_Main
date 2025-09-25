const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxiease-main-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

console.log("🔧 DEBUGGING NOTIFICATION STORAGE ISSUE");
console.log("═".repeat(60));

async function debugNotificationStorage() {
  console.log("🔍 ISSUE ANALYSIS:");
  console.log("─".repeat(40));
  console.log("• FCM notifications showing as popups ✅");
  console.log("• In-app banners appearing ✅");
  console.log("• Navigation working (to notification screen) ✅");
  console.log("• BUT: Not stored in Supabase database ❌");
  console.log("• BUT: Not showing in homepage notifications ❌");
  console.log("• BUT: Not showing in notification screen lists ❌");

  console.log("\n🎯 TESTING ENHANCED NOTIFICATIONS:");
  console.log("─".repeat(40));

  // Send a single test notification with enhanced debugging
  try {
    const testNotification = {
      notification: {
        title: "🔴 DEBUG Critical Anxiety Alert",
        body: "This is a test to debug database storage. HR: 125 BPM",
      },
      data: {
        type: "anxiety_alert",
        messageType: "anxiety_alert", // Ensure FCM handler picks this up
        severity: "critical",
        heartRate: "125",
        baseline: "72",
        percentageAbove: "74",
        timestamp: Date.now().toString(),
        notificationId: `debug_critical_${Date.now()}`,
        // Add extra debug info
        debug: "true",
        source: "test_script",
      },
      topic: "anxiety_alerts",
    };

    console.log("📤 Sending DEBUG notification with data:");
    console.log(JSON.stringify(testNotification.data, null, 2));

    const response = await admin.messaging().send(testNotification);
    console.log("✅ DEBUG notification sent:", response);

    console.log("\n📱 WHAT TO CHECK IN YOUR APP:");
    console.log("─".repeat(40));
    console.log('1. Look for "🔴 DEBUG Critical Anxiety Alert" popup');
    console.log("2. Check if it appears in notification screen after popup");
    console.log("3. Check Flutter debug console for error messages");
    console.log("4. Look for these debug messages:");
    console.log('   - "⚠️ Navigating to notifications from anxiety alert tap"');
    console.log('   - "✅ Stored anxiety alert in Supabase"');
    console.log('   - "❌ Error storing anxiety alert notification"');

    console.log("\n🔧 POSSIBLE FIXES:");
    console.log("─".repeat(40));
    console.log("If still not working, the issue might be:");
    console.log("1. ❌ Supabase connection failure");
    console.log("2. ❌ _storeAnxietyAlertNotification function error");
    console.log("3. ❌ FCM message data format mismatch");
    console.log("4. ❌ Notification refresh not triggering");

    console.log("\n💡 NEXT STEPS:");
    console.log("─".repeat(40));
    console.log("1. Check Flutter debug console for error messages");
    console.log("2. If you see errors, I can fix the storage function");
    console.log(
      "3. If no errors but still not showing, I can enhance the FCM handler"
    );
  } catch (error) {
    console.error("❌ Error sending debug notification:", error.message);
  }
}

debugNotificationStorage().catch(console.error);
