/**
 * Simple Direct Notification Test
 * Sends a basic notification directly to your FCM token
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

async function sendSimpleNotification() {
  try {
    console.log("🔍 Getting FCM token...\n");

    const assignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");

    if (!assignmentSnapshot.exists()) {
      console.error("❌ No assignment found!");
      process.exit(1);
    }

    const fcmToken = assignmentSnapshot.val().fcmToken;
    if (!fcmToken) {
      console.error("❌ No FCM token found!");
      process.exit(1);
    }

    console.log(`✅ FCM Token found: ${fcmToken.substring(0, 40)}...\n`);

    // Test 1: Data-only message (like anxiety alerts)
    console.log(
      "📤 Test 1: Sending DATA-ONLY message (like anxiety alerts)..."
    );
    const dataOnlyMessage = {
      token: fcmToken,
      data: {
        type: "anxiety_alert",
        severity: "mild",
        title: "🟢 TEST Data-Only Alert",
        message:
          "This is a DATA-ONLY notification. Your app should display it.",
        heartRate: "96",
        channelId: "mild_anxiety_alerts_v4",
        sound: "mild_alerts.mp3",
      },
      android: {
        priority: "high",
      },
    };

    const result1 = await messaging.send(dataOnlyMessage);
    console.log(`✅ Data-only message sent: ${result1}`);
    console.log("   → Your app MUST create a local notification from this\n");

    // Wait 3 seconds
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Test 2: Notification + Data message (like wellness reminders)
    console.log(
      "📤 Test 2: Sending NOTIFICATION + DATA message (like wellness)..."
    );
    const notificationMessage = {
      token: fcmToken,
      notification: {
        title: "🌅 TEST Notification Message",
        body: "This is a NOTIFICATION message. Android should display it automatically.",
      },
      data: {
        type: "wellness_reminder",
        category: "morning",
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "wellness_reminders",
          defaultSound: true,
        },
      },
    };

    const result2 = await messaging.send(notificationMessage);
    console.log(`✅ Notification message sent: ${result2}`);
    console.log("   → Android OS should display this automatically\n");

    // Summary
    console.log("╔════════════════════════════════════════════════════════╗");
    console.log("║              CHECK YOUR DEVICE NOW!                    ║");
    console.log("╚════════════════════════════════════════════════════════╝");
    console.log("\n📱 You should see TWO notifications:");
    console.log("   1️⃣  Data-Only Alert (if your app handled it)");
    console.log("   2️⃣  Notification Message (Android displays automatically)");
    console.log("\n");
    console.log("❓ TROUBLESHOOTING:");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("If you see NEITHER:");
    console.log("   ❌ App is force-closed or not running");
    console.log("   ❌ Notification permissions denied");
    console.log("   ❌ Do Not Disturb is ON");
    console.log("   ❌ Battery optimization killing your app");
    console.log("\nIf you see ONLY #2 (Notification Message):");
    console.log(
      "   ❌ Your app's onMessage handler is not creating local notifications"
    );
    console.log(
      "   ❌ Check lib/main.dart line 1077 (FirebaseMessaging.onMessage)"
    );
    console.log("   ❌ Check AwesomeNotifications channel setup");
    console.log("\nIf you see BOTH:");
    console.log(
      "   ✅ Everything works! Problem is with Cloud Function alerts"
    );
    console.log("   → Run: npx firebase-tools functions:log -n 20");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    if (error.code === "messaging/invalid-registration-token") {
      console.error("\n⚠️  FCM TOKEN IS INVALID!");
      console.error("   Solution: Restart your app to get a fresh token");
    }
    process.exit(1);
  }
}

sendSimpleNotification();
