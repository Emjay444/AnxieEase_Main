const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testReminderReliability() {
  console.log("🧪 TESTING REMINDER SYSTEM RELIABILITY");
  console.log("");
  console.log("This test will help you understand the difference between:");
  console.log("✅ Anxiety alerts (FCM-based, work when app closed)");
  console.log(
    "❌ Prevention reminders (local scheduling, may fail when app closed)"
  );
  console.log("");

  try {
    console.log("📱 STEP 1: Test anxiety alert (FCM-based)");
    console.log("💡 This should work even if your app is COMPLETELY CLOSED");

    // Simulate an anxiety alert by updating Firebase
    await admin
      .database()
      .ref("devices/AnxieEase001/Metrics")
      .update({
        heartRate: 85,
        anxietyDetected: {
          severity: "moderate",
          timestamp: Date.now(),
          confidence: 0.8,
        },
        timestamp: Date.now(),
      });

    console.log(
      "✅ Firebase data updated - Cloud Function should trigger FCM notification"
    );
    console.log(
      "📱 CHECK YOUR DEVICE: You should see 'Moderate Alert' notification"
    );

    await new Promise((resolve) => setTimeout(resolve, 10000));

    console.log(
      "\n🧘 STEP 2: Test prevention reminder (Manual FCM simulation)"
    );
    console.log("💡 Let's simulate what reminders SHOULD be like (FCM-based)");

    const reminderMessage = {
      notification: {
        title: "🧘 Prevention Reminder Test",
        body: "This is how reminders SHOULD work when app is closed - via FCM",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "anxiety_alerts",
          priority: "default",
          sound: "default",
          tag: "prevention_reminder_test",
        },
      },
      data: {
        type: "prevention_reminder_test",
        timestamp: Date.now().toString(),
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(reminderMessage);
    console.log("✅ Manual prevention reminder (FCM) sent:", response);
    console.log(
      "📱 CHECK YOUR DEVICE: You should see 'Prevention Reminder Test'"
    );

    console.log("\n🔍 ANALYSIS:");
    console.log("If you received BOTH notifications, it proves:");
    console.log("✅ FCM-based notifications work when app is closed");
    console.log("❌ Your current local reminders rely on app being alive");
    console.log("");
    console.log("💡 SOLUTION: Convert anxiety prevention reminders to use");
    console.log("   scheduled Cloud Functions + FCM (like anxiety alerts)");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testReminderReliability();
