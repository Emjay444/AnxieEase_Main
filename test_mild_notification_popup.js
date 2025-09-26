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

// Simple test to trigger mild anxiety notification
async function testMildNotificationPopup() {
  console.log("🧪 TESTING MILD NOTIFICATION POPUP & SOUND");
  console.log("═".repeat(50));
  console.log("📱 This sends a single mild anxiety notification");
  console.log("🎯 Should test: Popup display + Custom sound");
  console.log("🔍 Check: Does it pop up? Does it use mild_alert.mp3?");
  console.log("");

  const alertData = {
    userId: "user123",
    sessionId: `test_session_${Date.now()}`,
    severity: "mild",
    heartRate: 88,
    baseline: 73.2,
    duration: 30,
    timestamp: Date.now(),
  };

  const alertsRef = admin.database().ref("/anxiety_alerts");

  try {
    console.log("📤 Sending mild anxiety notification...");
    await alertsRef.push(alertData);

    console.log("✅ Mild notification sent!");
    console.log("");
    console.log("🔍 WHAT TO CHECK:");
    console.log("   • Does notification pop up on screen?");
    console.log("   • Does it play mild_alert.mp3 sound?");
    console.log("   • Does it show 'Mild Anxiety Alerts V2' channel?");
    console.log(
      "   • Does it appear immediately (not just in notification bar)?"
    );
    console.log("");
    console.log("📋 Expected Behavior:");
    console.log("   🟢 Popup notification with green color");
    console.log("   🔊 Custom mild_alert.mp3 sound (not default phone sound)");
    console.log("   ⚡ Immediate screen display (heads-up notification)");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error sending notification:", error);
    process.exit(1);
  }
}

testMildNotificationPopup();
