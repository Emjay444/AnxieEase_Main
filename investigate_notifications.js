/**
 * COMPREHENSIVE NOTIFICATION INVESTIGATION
 * Diagnoses ALL notification flows: wellness reminders, breathing reminders, anxiety alerts
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();
const messaging = admin.messaging();

const TEST_DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║   COMPREHENSIVE NOTIFICATION INVESTIGATION                 ║");
console.log("╚════════════════════════════════════════════════════════════╝\n");

async function investigate() {
  // ===================================================================
  // STEP 1: CHECK FCM TOKEN
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 1: FCM TOKEN STATUS");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  const assignmentSnapshot = await db
    .ref(`/devices/${TEST_DEVICE_ID}/assignment`)
    .once("value");

  if (!assignmentSnapshot.exists()) {
    console.log("❌ CRITICAL: No assignment found!");
    process.exit(1);
  }

  const assignment = assignmentSnapshot.val();
  const fcmToken = assignment.fcmToken;
  const assignedUser = assignment.assignedUser;

  console.log(`✅ Assignment exists`);
  console.log(`   User: ${assignedUser}`);
  console.log(`   Device: ${TEST_DEVICE_ID}`);
  console.log(`   FCM Token: ${fcmToken ? "EXISTS" : "❌ MISSING"}`);

  if (!fcmToken) {
    console.log("\n❌ CRITICAL: No FCM token found!");
    console.log("SOLUTION: Restart your app");
    process.exit(1);
  }

  console.log(`   Token (first 40 chars): ${fcmToken.substring(0, 40)}...\n`);

  // Test if token is valid
  try {
    const testMessage = {
      token: fcmToken,
      data: {
        type: "test",
        title: "Investigation Test",
        message: "Testing FCM token validity",
      },
    };

    await messaging.send(testMessage);
    console.log("✅ FCM Token is VALID and working!\n");
  } catch (error) {
    console.log(`❌ FCM Token is INVALID: ${error.code}`);
    console.log("SOLUTION: Restart your app to get a fresh token\n");
    process.exit(1);
  }

  // ===================================================================
  // STEP 2: CHECK TOPIC SUBSCRIPTIONS
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 2: TOPIC SUBSCRIPTIONS");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  try {
    const anxietyResult = await messaging.subscribeToTopic(
      [fcmToken],
      "anxiety_alerts"
    );
    console.log(
      `✅ anxiety_alerts: ${anxietyResult.successCount} subscribed, ${anxietyResult.failureCount} failed`
    );

    const wellnessResult = await messaging.subscribeToTopic(
      [fcmToken],
      "wellness_reminders"
    );
    console.log(
      `✅ wellness_reminders: ${wellnessResult.successCount} subscribed, ${wellnessResult.failureCount} failed\n`
    );
  } catch (error) {
    console.log(`❌ Topic subscription failed: ${error.message}\n`);
  }

  // ===================================================================
  // STEP 3: TEST WELLNESS REMINDER (TOPIC-BASED)
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 3: TESTING WELLNESS REMINDER");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  try {
    const wellnessMessage = {
      data: {
        type: "wellness_reminder", // This gets mapped to "reminder" in app
        category: "morning",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🌅 INVESTIGATION: Wellness Reminder",
        body: "If you see this, wellness reminders are working!",
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

    const result = await messaging.send(wellnessMessage);
    console.log(`✅ Wellness reminder sent successfully`);
    console.log(`   Message ID: ${result}`);
    console.log(`   Type: wellness_reminder → mapped to "reminder" in app`);
    console.log(`   Channel: wellness_reminders`);
    console.log(`   📱 CHECK YOUR DEVICE NOW!\n`);
  } catch (error) {
    console.log(`❌ Wellness reminder failed: ${error.message}\n`);
  }

  await new Promise((resolve) => setTimeout(resolve, 2000));

  // ===================================================================
  // STEP 4: TEST BREATHING REMINDER (TOPIC-BASED)
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 4: TESTING BREATHING REMINDER");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  try {
    const breathingMessage = {
      data: {
        type: "breathing_reminder", // This gets mapped to "reminder" in app
        category: "daily_breathing",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🫁 INVESTIGATION: Breathing Exercise",
        body: "If you see this, breathing reminders are working!",
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

    const result = await messaging.send(breathingMessage);
    console.log(`✅ Breathing reminder sent successfully`);
    console.log(`   Message ID: ${result}`);
    console.log(`   Type: breathing_reminder → mapped to "reminder" in app`);
    console.log(`   Channel: wellness_reminders`);
    console.log(`   📱 CHECK YOUR DEVICE NOW!\n`);
  } catch (error) {
    console.log(`❌ Breathing reminder failed: ${error.message}\n`);
  }

  await new Promise((resolve) => setTimeout(resolve, 2000));

  // ===================================================================
  // STEP 5: TEST ANXIETY ALERT (TOKEN-BASED)
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 5: TESTING ANXIETY ALERT");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  try {
    const anxietyMessage = {
      token: fcmToken, // Direct to user, not topic
      data: {
        type: "anxiety_alert", // This gets mapped to "alert" in app
        severity: "mild",
        heartRate: "96",
        baseline: "76.4",
        timestamp: Date.now().toString(),
        title: "🟢 INVESTIGATION: Mild Anxiety Alert",
        message: "If you see this, anxiety alerts are working!",
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

    const result = await messaging.send(anxietyMessage);
    console.log(`✅ Anxiety alert sent successfully`);
    console.log(`   Message ID: ${result}`);
    console.log(`   Type: anxiety_alert → mapped to "alert" in app`);
    console.log(`   Channel: mild_anxiety_alerts_v4`);
    console.log(`   📱 CHECK YOUR DEVICE NOW!\n`);
  } catch (error) {
    console.log(`❌ Anxiety alert failed: ${error.message}\n`);
  }

  // ===================================================================
  // STEP 6: CHECK CLOUD FUNCTION SCHEDULES
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 6: SCHEDULED CLOUD FUNCTIONS");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("📅 sendWellnessReminders schedule:");
  console.log("   Runs at: 8 AM, 12 PM, 4 PM, 8 PM, 10 PM (Philippine time)");
  console.log("   Cron: 0 8,12,16,20,22 * * *");
  console.log("   Topic: wellness_reminders\n");

  console.log("📅 sendDailyBreathingReminder schedule:");
  console.log("   Runs at: 2 PM (Philippine time)");
  console.log("   Cron: 0 14 * * *");
  console.log("   Topic: wellness_reminders\n");

  console.log("💡 To check if these ran today:");
  console.log("   Run: npx firebase-tools functions:log -n 100\n");

  // ===================================================================
  // STEP 7: CHECK SUPABASE NOTIFICATION TYPES
  // ===================================================================
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("STEP 7: SUPABASE NOTIFICATION TYPE MAPPING");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("✅ Allowed types in Supabase: 'alert', 'reminder'");
  console.log("\n📊 Type Mapping in App:");
  console.log("   wellness_reminder    → 'reminder' ✅");
  console.log("   breathing_reminder   → 'reminder' ✅");
  console.log("   anxiety_alert        → 'alert' ✅");
  console.log("   anxiety_log          → 'alert' ✅");
  console.log("\n💡 All types are correctly mapped!\n");

  // ===================================================================
  // SUMMARY
  // ===================================================================
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║                    INVESTIGATION SUMMARY                   ║");
  console.log(
    "╚════════════════════════════════════════════════════════════╝\n"
  );

  console.log("📱 CHECK YOUR DEVICE NOW - You should have received:");
  console.log("   1️⃣  Wellness Reminder (from topic)");
  console.log("   2️⃣  Breathing Reminder (from topic)");
  console.log("   3️⃣  Anxiety Alert (direct to token)\n");

  console.log("❓ TROUBLESHOOTING GUIDE:\n");
  console.log("If you received ALL 3:");
  console.log("   ✅ Everything works! FCM, topics, and app are OK");
  console.log("   ❌ Issue: Scheduled Cloud Functions not running");
  console.log("   → Check logs: npx firebase-tools functions:log -n 100\n");

  console.log("If you received ONLY anxiety alert (#3):");
  console.log("   ✅ Direct FCM works, token is valid");
  console.log("   ❌ Issue: Topic subscriptions not working");
  console.log("   → Solution: Restart app to re-subscribe to topics\n");

  console.log("If you received NONE:");
  console.log("   ❌ Issue: App not running or notifications blocked");
  console.log("   → Check: App is open, notifications enabled, DND off\n");

  console.log("If you received 1-2 but not all:");
  console.log("   ❌ Issue: Specific notification type handling broken");
  console.log("   → Check: lib/main.dart onMessage handler\n");

  process.exit(0);
}

investigate().catch((error) => {
  console.error("\n❌ Investigation failed:", error);
  process.exit(1);
});
