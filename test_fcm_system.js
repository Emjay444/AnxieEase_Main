// Test script to check if FCM notifications are working
const admin = require("firebase-admin");

// Initialize Firebase Admin with service account
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.firebaseio.com",
});

async function testFCMNotifications() {
  console.log("🧪 Testing FCM notification system...");

  try {
    // Test 1: Send anxiety alert notification
    console.log("\n1️⃣ Testing anxiety alert notification...");
    const anxietyMessage = {
      data: {
        type: "anxiety_alert",
        severity: "moderate",
        heartRate: "85",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🟠 Moderate Alert (Test)",
        body: "Testing anxiety alert system. HR: 85 bpm",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "anxiety_alerts",
          priority: "default",
          defaultSound: true,
        },
      },
      topic: "anxiety_alerts",
    };

    const anxietyResponse = await admin.messaging().send(anxietyMessage);
    console.log("✅ Anxiety alert sent successfully:", anxietyResponse);

    // Test 2: Send wellness reminder notification
    console.log("\n2️⃣ Testing wellness reminder notification...");
    const wellnessMessage = {
      data: {
        type: "wellness_reminder",
        category: "afternoon",
        messageType: "mindfulness",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "Afternoon Check-in 💭 (Test)",
        body: "Testing wellness reminder system. Take a deep breath.",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "wellness_reminders",
          priority: "default",
          defaultSound: true,
        },
      },
      topic: "wellness_reminders",
    };

    const wellnessResponse = await admin.messaging().send(wellnessMessage);
    console.log("✅ Wellness reminder sent successfully:", wellnessResponse);

    // Test 3: Check topic subscription count
    console.log("\n3️⃣ Checking topic subscription status...");
    // Note: Topic management requires FCM tokens, this is just a placeholder

    console.log("\n🎉 All FCM tests completed successfully!");
    console.log("📱 Check your device for notifications");
  } catch (error) {
    console.error("❌ FCM test failed:", error);
  }
}

// Run the test
testFCMNotifications();
