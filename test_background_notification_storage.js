const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

// Test background notification storage
async function testBackgroundNotificationStorage() {
  console.log("🧪 TESTING BACKGROUND NOTIFICATION STORAGE");
  console.log("═".repeat(55));
  console.log("📱 This sends a notification when app is closed");
  console.log("🎯 Should test: Notification appears in app after reopening");
  console.log("🔍 Instructions:");
  console.log("   1. Close the AnxieEase app completely");
  console.log("   2. Run this script");
  console.log("   3. Wait for notification to appear");
  console.log("   4. Reopen the app");
  console.log("   5. Check if notification appears in notifications screen");
  console.log("");

  const alertData = {
    userId: "user123",
    sessionId: `background_test_${Date.now()}`,
    severity: "mild",
    heartRate: 89,
    baseline: 73.2,
    duration: 45,
    timestamp: Date.now(),
    percentageAbove: "22", // 22% above baseline
  };

  const alertsRef = admin.database().ref("/anxiety_alerts");

  try {
    console.log("📤 Sending background notification test...");
    await alertsRef.push(alertData);

    console.log("✅ Background notification sent!");
    console.log("");
    console.log("🔍 WHAT TO TEST:");
    console.log("   • Notification pops up even when app is closed ✓");
    console.log("   • Custom mild_alert.mp3 sound plays ✓");
    console.log("   • After reopening app → Check notifications screen");
    console.log("   • Should see: '🟢 Mild Anxiety Alert'");
    console.log(
      "   • Should show: 'Heart rate: 89 BPM (22% above your baseline of 73.2 BPM)'"
    );
    console.log("");
    console.log("📱 Expected in App:");
    console.log("   🏠 Homepage: New notification indicator");
    console.log("   📋 Notifications Screen: New mild anxiety entry");
    console.log("   📊 Proper timestamp and details");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error sending background notification:", error);
    process.exit(1);
  }
}

testBackgroundNotificationStorage();
