const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

async function testBackgroundNotifications() {
  console.log("🚀 Testing background notifications when app is closed...\n");

  try {
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
    const fcmToken =
      "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

    console.log("📱 Step 1: Sending background push notification...");

    // Simulate anxiety detection trigger
    const anxietyNotification = {
      notification: {
        title: "🚨 AnxieEase Anxiety Alert",
        body: "Your heart rate is elevated (92 BPM). Are you feeling anxious or stressed?",
      },
      data: {
        type: "anxiety",
        severity: "mild",
        heartRate: "92",
        baseline: "73.2",
        timestamp: Date.now().toString(),
        requiresConfirmation: "true",
        deviceId: "AnxieEase001",
        alertId: `alert_${Date.now()}`,
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    const pushResponse = await admin.messaging().send(anxietyNotification);
    console.log("✅ Background push notification sent!");
    console.log(`📱 Message ID: ${pushResponse}`);

    // Step 2: Save to all possible database paths for homepage/notification screen
    console.log(
      "\n💾 Step 2: Saving to Firebase database for in-app display..."
    );

    const notificationData = {
      id: `notif_${Date.now()}`,
      title: "🚨 AnxieEase Anxiety Alert",
      message:
        "Your heart rate is elevated (92 BPM). Are you feeling anxious or stressed?",
      type: "anxiety",
      severity: "mild",
      heartRate: 92,
      baseline: 73.2,
      timestamp: Date.now(),
      created_at: new Date().toISOString(),
      read: false,
      dismissed: false,
      requiresConfirmation: true,
      deviceId: "AnxieEase001",
      source: "background_test",
      priority: "high",
      category: "anxiety_detection",
    };

    // Save to multiple paths to ensure app picks it up
    console.log("📝 Saving to users/{userId}/notifications...");
    const notifRef = await db
      .ref(`users/${userId}/notifications`)
      .push(notificationData);
    console.log(`✅ Saved with key: ${notifRef.key}`);

    console.log("📝 Saving to users/{userId}/anxietyAlerts...");
    await db.ref(`users/${userId}/anxietyAlerts`).push(notificationData);
    console.log("✅ Saved to anxiety alerts");

    console.log("📝 Saving to devices/AnxieEase001/userNotifications...");
    await db
      .ref(`devices/AnxieEase001/userNotifications/${userId}`)
      .push(notificationData);
    console.log("✅ Saved to device-specific notifications");

    // Step 3: Create a wellness reminder too
    console.log("\n🌟 Step 3: Adding wellness reminder notification...");

    const wellnessNotification = {
      notification: {
        title: "💚 AnxieEase Wellness Check",
        body: "How are you feeling today? Take a moment to check your mental wellness.",
      },
      data: {
        type: "wellness",
        subtype: "reminder",
        timestamp: Date.now().toString(),
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: "wellness_reminders",
          priority: "default",
        },
      },
    };

    await admin.messaging().send(wellnessNotification);

    const wellnessData = {
      id: `wellness_${Date.now()}`,
      title: "💚 AnxieEase Wellness Check",
      message:
        "How are you feeling today? Take a moment to check your mental wellness.",
      type: "wellness",
      subtype: "reminder",
      timestamp: Date.now(),
      created_at: new Date().toISOString(),
      read: false,
      priority: "normal",
      category: "wellness",
    };

    await db.ref(`users/${userId}/notifications`).push(wellnessData);
    console.log("✅ Wellness notification sent and saved");

    // Step 4: Trigger real anxiety detection function
    console.log("\n🔥 Step 4: Triggering real anxiety detection function...");

    // Update device current data to simulate elevated heart rate
    const deviceData = {
      heartRate: 94,
      accelX: 2.1,
      accelY: 1.8,
      accelZ: 8.2,
      gyroX: 0.02,
      gyroY: -0.01,
      gyroZ: 0.01,
      timestamp: Date.now(),
      worn: 1,
      bodyTemp: 36.8,
      spo2: 98,
      battPerc: 85,
      deviceId: "AnxieEase001",
      sessionId: `session_${Date.now()}`,
    };

    await db.ref("devices/AnxieEase001/current").set(deviceData);
    console.log("✅ Updated device data with elevated heart rate (94 BPM)");

    // This should trigger the detectAnxietyMultiParameter function
    console.log(
      "⚡ This should trigger the anxiety detection Firebase Function..."
    );

    console.log("\n🎯 TEST SUMMARY:");
    console.log("================");
    console.log("✅ Background push notifications sent (anxiety + wellness)");
    console.log("✅ Notifications saved to Firebase database");
    console.log("✅ Multiple database paths populated");
    console.log("✅ Device data updated to trigger real detection");
    console.log("✅ FCM tokens configured for background delivery");

    console.log("\n📱 WHAT TO EXPECT:");
    console.log("==================");
    console.log("1. 🔔 Android notification tray should show:");
    console.log('   - "AnxieEase Anxiety Alert" (HR elevated 92 BPM)');
    console.log('   - "AnxieEase Wellness Check" (mental wellness reminder)');
    console.log("");
    console.log("2. 📱 When you open your Flutter app:");
    console.log("   - Homepage should show notification badges/alerts");
    console.log("   - Notification screen should display both notifications");
    console.log("   - Anxiety alert should have confirmation buttons");
    console.log("");
    console.log("3. 🤖 Real-time detection:");
    console.log(
      "   - Firebase Function should detect HR 94 > 88.2 (mild threshold)"
    );
    console.log("   - Additional automatic notification may be sent");

    console.log("\n🚨 TESTING INSTRUCTIONS:");
    console.log("=========================");
    console.log("1. Make sure your Flutter app is COMPLETELY CLOSED");
    console.log("2. Wait 10-15 seconds for notifications to arrive");
    console.log("3. Check Android notification tray for alerts");
    console.log("4. Open Flutter app and check:");
    console.log("   - Homepage notification indicators");
    console.log("   - Notification screen content");
    console.log("   - Anxiety alert confirmation options");
    console.log("5. Test interaction with notifications");
  } catch (error) {
    console.error("❌ Error testing background notifications:", error);
  }

  process.exit(0);
}

testBackgroundNotifications();
