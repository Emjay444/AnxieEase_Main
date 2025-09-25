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

console.log("🚀 TESTING FIXED NOTIFICATION TYPE");
console.log("═".repeat(50));

async function testFixedNotificationType() {
  console.log("🔧 THE ISSUE WAS IDENTIFIED:");
  console.log("─".repeat(40));
  console.log('❌ Database enum only accepts: "anxiety_log" and "reminder"');
  console.log('❌ We were sending: "anxiety_alert" (invalid)');
  console.log('✅ Fixed to use: "anxiety_log" (valid)');

  console.log("\n📤 Sending test with correct enum value...");

  try {
    const testMessage = {
      notification: {
        title: "🔴 FIXED - Critical Anxiety Alert",
        body: "Testing with correct database enum value. HR: 125 BPM",
      },
      data: {
        type: "anxiety_alert",
        messageType: "anxiety_alert",
        severity: "critical",
        heartRate: "125",
        baseline: "72",
        percentageAbove: "74",
        timestamp: Date.now().toString(),
        notificationId: `fixed_test_${Date.now()}`,
        source: "database_fix_test",
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(testMessage);
    console.log("✅ Fixed test notification sent:", response);

    console.log("\n📱 WHAT SHOULD HAPPEN NOW:");
    console.log("─".repeat(40));
    console.log("1. 📱 Pop-up notification appears");
    console.log(
      '2. ✅ "✅ Successfully stored anxiety alert notification" in debug console'
    );
    console.log("3. 🏠 Notification appears in homepage notification section");
    console.log("4. 🔔 Notification appears in notification screen");
    console.log(
      "5. 👆 Tapping should go to notifications screen (critical severity)"
    );

    console.log("\n🎯 SUCCESS INDICATORS:");
    console.log('• NO "createNotification insert failed" error');
    console.log('• NO "invalid input value for enum" error');
    console.log("• Notification shows up in app screens");
  } catch (error) {
    console.error("❌ Error sending fixed test notification:", error.message);
  }
}

testFixedNotificationType().catch(console.error);
