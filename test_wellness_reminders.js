const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testAnxietyPreventionReminders() {
  console.log("🔍 TESTING ANXIETY PREVENTION REMINDERS");
  console.log("");
  console.log("📋 What this test checks:");
  console.log("✅ If wellness reminders work when app is closed");
  console.log("✅ If reminders are properly scheduled");
  console.log("✅ If background notifications deliver");
  console.log("");

  try {
    // Test 1: Send a manual wellness reminder to test if it works when app is closed
    console.log("🧪 TEST 1: Manual Wellness Reminder (App Closed)");
    console.log("📱 CLOSE YOUR APP COMPLETELY!");
    console.log("⏳ Waiting 10 seconds for you to close the app...");

    await new Promise((resolve) => setTimeout(resolve, 10000));

    const wellnessMessage = {
      notification: {
        title: "🌱 Wellness Check-in",
        body: "Take a moment to breathe deeply and check how you're feeling.",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "anxiety_alerts", // Using existing channel
          priority: "default",
          sound: "default",
          tag: "wellness_reminder",
        },
      },
      data: {
        type: "wellness_reminder",
        timestamp: Date.now().toString(),
      },
      topic: "anxiety_alerts",
    };

    const response1 = await admin.messaging().send(wellnessMessage);
    console.log("✅ Manual wellness reminder sent:", response1);
    console.log("📱 Check your device - you should see a wellness reminder!");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 2: Send a breathing reminder
    console.log("\n🧪 TEST 2: Breathing Exercise Reminder");

    const breathingMessage = {
      notification: {
        title: "🫁 Breathing Reminder",
        body: "Try the 4-7-8 technique: Inhale 4, hold 7, exhale 8",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "anxiety_alerts",
          priority: "default",
          sound: "default",
          tag: "breathing_reminder",
        },
      },
      data: {
        type: "breathing_reminder",
        timestamp: Date.now().toString(),
      },
      topic: "anxiety_alerts",
    };

    const response2 = await admin.messaging().send(breathingMessage);
    console.log("✅ Breathing reminder sent:", response2);
    console.log("📱 Check your device for breathing reminder!");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 3: Send a mindfulness reminder
    console.log("\n🧪 TEST 3: Mindfulness Reminder");

    const mindfulnessMessage = {
      notification: {
        title: "🧘 Mindfulness Moment",
        body: "Remember to take short breaks and practice mindfulness throughout your day.",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "anxiety_alerts",
          priority: "default",
          sound: "default",
          tag: "mindfulness_reminder",
        },
      },
      data: {
        type: "mindfulness_reminder",
        timestamp: Date.now().toString(),
      },
      topic: "anxiety_alerts",
    };

    const response3 = await admin.messaging().send(mindfulnessMessage);
    console.log("✅ Mindfulness reminder sent:", response3);
    console.log("📱 Check your device for mindfulness reminder!");

    console.log("\n🎯 === TEST RESULTS ===");
    console.log("📱 You should have received 3 wellness reminders:");
    console.log("   1. 🌱 Wellness Check-in");
    console.log("   2. 🫁 Breathing Reminder");
    console.log("   3. 🧘 Mindfulness Moment");
    console.log("");
    console.log(
      "✅ If you received all 3: Wellness reminders work when app is closed!"
    );
    console.log("❌ If you received none: Check device notification settings");
    console.log(
      "⚠️ If you received some: Partial success - check notification channels"
    );
    console.log("");
    console.log(
      "💡 Note: These are manual tests. The actual app reminders are scheduled"
    );
    console.log(
      "   by AwesomeNotifications and should work automatically when enabled"
    );
    console.log("   in your Settings > Anxiety Prevention Reminders");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testAnxietyPreventionReminders();
