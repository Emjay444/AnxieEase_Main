/**
 * Comprehensive Notification Test Script
 * Tests ALL notification types: anxiety alerts, wellness reminders, breathing reminders
 */

const admin = require("firebase-admin");

// Suppress Firebase warnings
process.env.FIREBASE_DATABASE_EMULATOR_HOST = undefined;

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
  console.log("✅ Firebase Admin initialized successfully\n");
}

const db = admin.database();
const messaging = admin.messaging();

const TEST_DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

// Test 1: Check FCM Token
async function checkFCMToken() {
  console.log("🔍 TEST 1: Checking FCM Token Setup");
  console.log("=".repeat(50));

  try {
    // Check assignment FCM token
    const assignmentSnapshot = await db
      .ref(`/devices/${TEST_DEVICE_ID}/assignment`)
      .once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      const fcmToken = assignment.fcmToken;
      const assignedUser = assignment.assignedUser;

      console.log(`✅ Assignment found`);
      console.log(`   User: ${assignedUser}`);
      console.log(`   FCM Token: ${fcmToken ? "EXISTS" : "MISSING"}`);

      if (fcmToken) {
        console.log(
          `   Token (first 30 chars): ${fcmToken.substring(0, 30)}...`
        );
        return fcmToken;
      } else {
        console.log(`❌ No FCM token found in assignment!`);
        return null;
      }
    } else {
      console.log(`❌ No assignment found for device ${TEST_DEVICE_ID}`);
      return null;
    }
  } catch (error) {
    console.error("❌ Error checking FCM token:", error);
    return null;
  }
}

// Test 2: Check Topic Subscriptions
async function checkTopicSubscriptions(token) {
  console.log("\n🔍 TEST 2: Checking Topic Subscriptions");
  console.log("=".repeat(50));

  try {
    // Subscribe to topics
    console.log("📱 Subscribing to anxiety_alerts topic...");
    const anxietyResult = await messaging.subscribeToTopic(
      [token],
      "anxiety_alerts"
    );
    console.log(
      `✅ Anxiety alerts subscription: ${anxietyResult.successCount} success, ${anxietyResult.failureCount} failures`
    );

    console.log("📱 Subscribing to wellness_reminders topic...");
    const wellnessResult = await messaging.subscribeToTopic(
      [token],
      "wellness_reminders"
    );
    console.log(
      `✅ Wellness reminders subscription: ${wellnessResult.successCount} success, ${wellnessResult.failureCount} failures`
    );

    return true;
  } catch (error) {
    console.error("❌ Error subscribing to topics:", error);
    return false;
  }
}

// Test 3: Send Direct Anxiety Alert
async function testAnxietyAlert(token) {
  console.log("\n🔍 TEST 3: Testing Anxiety Alert (Direct to Token)");
  console.log("=".repeat(50));

  try {
    const message = {
      token: token,
      data: {
        type: "anxiety_alert",
        severity: "mild",
        heartRate: "96",
        baseline: "76.4",
        timestamp: Date.now().toString(),
        title: "🟢 TEST Mild Alert",
        message:
          "This is a test anxiety alert. If you see this, direct alerts work!",
        channelId: "mild_anxiety_alerts_v4",
        sound: "mild_alerts.mp3",
        color: "#4CAF50",
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    };

    console.log("📤 Sending anxiety alert to token...");
    const response = await messaging.send(message);
    console.log(`✅ Anxiety alert sent successfully!`);
    console.log(`   Message ID: ${response}`);
    return true;
  } catch (error) {
    console.error("❌ Error sending anxiety alert:", error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      console.error("⚠️  FCM TOKEN IS INVALID OR EXPIRED!");
      console.error("   Solution: Restart your app to get a fresh token");
    }
    return false;
  }
}

// Test 4: Send Wellness Reminder to Topic
async function testWellnessReminder() {
  console.log("\n🔍 TEST 4: Testing Wellness Reminder (Topic)");
  console.log("=".repeat(50));

  try {
    const message = {
      data: {
        type: "wellness_reminder",
        category: "morning",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🌅 TEST Morning Wellness",
        body: "This is a test wellness reminder. If you see this, topic notifications work!",
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

    console.log("📤 Sending wellness reminder to topic...");
    const response = await messaging.send(message);
    console.log(`✅ Wellness reminder sent successfully!`);
    console.log(`   Message ID: ${response}`);
    return true;
  } catch (error) {
    console.error("❌ Error sending wellness reminder:", error);
    return false;
  }
}

// Test 5: Send Breathing Reminder to Topic
async function testBreathingReminder() {
  console.log("\n🔍 TEST 5: Testing Breathing Reminder (Topic)");
  console.log("=".repeat(50));

  try {
    const message = {
      data: {
        type: "breathing_reminder",
        category: "daily_breathing",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🫁 TEST Daily Breathing Exercise",
        body: "This is a test breathing reminder. If you see this, breathing notifications work!",
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

    console.log("📤 Sending breathing reminder to topic...");
    const response = await messaging.send(message);
    console.log(`✅ Breathing reminder sent successfully!`);
    console.log(`   Message ID: ${response}`);
    return true;
  } catch (error) {
    console.error("❌ Error sending breathing reminder:", error);
    return false;
  }
}

// Test 6: Trigger Cloud Function Alert
async function testCloudFunctionAlert() {
  console.log("\n🔍 TEST 6: Testing Cloud Function (onNativeAlertCreate)");
  console.log("=".repeat(50));

  try {
    const alertData = {
      severity: "mild",
      heartRate: 96,
      timestamp: Date.now(),
      confidence: 85,
      baseline: 76.4,
      alertType: "comprehensive_test",
      deviceId: TEST_DEVICE_ID,
      userId: TEST_USER_ID,
      source: "test", // Required for Cloud Function
    };

    console.log("📝 Writing alert to Firebase RTDB...");
    const alertRef = db.ref(`/devices/${TEST_DEVICE_ID}/alerts`).push();
    await alertRef.set(alertData);

    console.log(`✅ Alert written to RTDB`);
    console.log(`   Alert ID: ${alertRef.key}`);
    console.log(`   Path: /devices/${TEST_DEVICE_ID}/alerts/${alertRef.key}`);
    console.log(`   Wait 3-5 seconds for Cloud Function to process...`);
    return true;
  } catch (error) {
    console.error("❌ Error triggering Cloud Function:", error);
    return false;
  }
}

// Main test runner
async function runAllTests() {
  console.log("╔════════════════════════════════════════════════╗");
  console.log("║   COMPREHENSIVE NOTIFICATION TEST SUITE        ║");
  console.log("╚════════════════════════════════════════════════╝\n");

  let fcmToken = null;

  // Test 1: Check FCM Token
  fcmToken = await checkFCMToken();
  if (!fcmToken) {
    console.log(
      "\n❌ CRITICAL: No FCM token found. Cannot proceed with tests."
    );
    console.log("\n💡 SOLUTIONS:");
    console.log("   1. Make sure your app is running");
    console.log("   2. Restart the app to generate a fresh FCM token");
    console.log("   3. Check main.dart FCM initialization code");
    console.log("   4. Verify Google Play Services is updated");
    process.exit(1);
  }

  // Test 2: Subscribe to Topics
  await checkTopicSubscriptions(fcmToken);

  // Wait a moment for subscriptions to propagate
  console.log("\n⏳ Waiting 2 seconds for subscriptions to propagate...");
  await new Promise((resolve) => setTimeout(resolve, 2000));

  // Test 3: Direct Anxiety Alert
  const test3 = await testAnxietyAlert(fcmToken);

  // Test 4: Wellness Reminder
  const test4 = await testWellnessReminder();

  // Test 5: Breathing Reminder
  const test5 = await testBreathingReminder();

  // Test 6: Cloud Function Alert
  const test6 = await testCloudFunctionAlert();

  // Summary
  console.log("\n╔════════════════════════════════════════════════╗");
  console.log("║              TEST RESULTS SUMMARY              ║");
  console.log("╚════════════════════════════════════════════════╝");
  console.log(`✅ FCM Token: ${fcmToken ? "FOUND" : "MISSING"}`);
  console.log(
    `${test3 ? "✅" : "❌"} Direct Anxiety Alert: ${test3 ? "SENT" : "FAILED"}`
  );
  console.log(
    `${test4 ? "✅" : "❌"} Wellness Reminder: ${test4 ? "SENT" : "FAILED"}`
  );
  console.log(
    `${test5 ? "✅" : "❌"} Breathing Reminder: ${test5 ? "SENT" : "FAILED"}`
  );
  console.log(
    `${test6 ? "✅" : "❌"} Cloud Function Alert: ${
      test6 ? "TRIGGERED" : "FAILED"
    }`
  );

  console.log("\n📱 CHECK YOUR DEVICE NOW!");
  console.log("   You should see 3-4 notifications within 10 seconds");
  console.log("\n💡 If you don't see notifications:");
  console.log("   1. Check notification permissions in Settings");
  console.log("   2. Check Do Not Disturb is OFF");
  console.log("   3. Restart the app");
  console.log("   4. Check Firebase Cloud Functions logs:");
  console.log("      npx firebase-tools functions:log -n 20");

  process.exit(0);
}

// Run all tests
runAllTests().catch((error) => {
  console.error("\n❌ Test suite failed:", error);
  process.exit(1);
});
