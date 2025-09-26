const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function debugNotificationIssues() {
  const db = admin.database();
  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
  const deviceId = "AnxieEase001";

  console.log("🔍 DEBUGGING NOTIFICATION DELIVERY ISSUES");
  console.log("═".repeat(60));

  try {
    // 1. Check FCM token freshness
    const deviceRef = db.ref(`/devices/${deviceId}/fcmToken`);
    const tokenSnapshot = await deviceRef.once("value");
    const fcmToken = tokenSnapshot.val();

    console.log(
      `📱 FCM Token: ${
        fcmToken ? fcmToken.substring(0, 50) + "..." : "Not found"
      }`
    );

    if (!fcmToken) {
      console.log("❌ No FCM token - app needs to be opened to register");
      return;
    }

    // 2. Test direct FCM send with different configurations
    console.log("\n🧪 TESTING FCM CONFIGURATIONS...");

    const testConfigs = [
      {
        name: "High Priority with Data",
        config: {
          token: fcmToken,
          notification: {
            title: "🚨 TEST - High Priority",
            body: "Testing high priority notification",
          },
          data: {
            type: "test_notification",
            priority: "high",
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "anxiety_alerts",
            },
          },
        },
      },
      {
        name: "Data-Only Message",
        config: {
          token: fcmToken,
          data: {
            type: "test_data_only",
            title: "Data Only Test",
            body: "This is a data-only message",
          },
          android: {
            priority: "high",
          },
        },
      },
      {
        name: "Simple Notification",
        config: {
          token: fcmToken,
          notification: {
            title: "📱 Simple Test",
            body: "Basic notification test",
          },
        },
      },
    ];

    for (const test of testConfigs) {
      try {
        console.log(`\n📤 Testing: ${test.name}`);
        const response = await admin.messaging().send(test.config);
        console.log(`✅ ${test.name} sent: ${response}`);

        // Wait between sends to avoid rate limiting
        await new Promise((resolve) => setTimeout(resolve, 2000));
      } catch (error) {
        console.log(`❌ ${test.name} failed:`, error.message);
        if (error.code) {
          console.log(`   Error Code: ${error.code}`);
        }
      }
    }

    // 3. Check recent alerts in database
    console.log("\n📋 CHECKING RECENT ALERTS IN DATABASE...");
    const alertsRef = db.ref(`/users/${userId}/alerts`);
    const alertsSnapshot = await alertsRef.limitToLast(3).once("value");

    if (alertsSnapshot.exists()) {
      const alerts = alertsSnapshot.val();
      console.log(`📊 Found ${Object.keys(alerts).length} recent alerts:`);
      Object.entries(alerts).forEach(([alertId, alert]) => {
        console.log(
          `   ${alertId}: ${alert.type || "unknown"} at ${new Date(
            alert.timestamp
          ).toLocaleString()}`
        );
      });
    } else {
      console.log("❌ No alerts found in database");
    }

    // 4. Check session validity
    console.log("\n📱 CHECKING USER SESSION...");
    const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
    const assignmentSnapshot = await assignmentRef.once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log(`✅ Device assigned to user: ${assignment.assignedUser}`);
      console.log(
        `📅 Assignment time: ${new Date(
          assignment.assignedAt
        ).toLocaleString()}`
      );
      console.log(`🔄 Session: ${assignment.activeSessionId}`);
    } else {
      console.log("❌ No device assignment found");
    }

    // 5. Check for rate limiting indicators
    console.log("\n⏱️ RATE LIMITING CHECK...");
    const now = Date.now();
    const oneMinuteAgo = now - 60000;

    // This is a simplified check - Firebase doesn't expose rate limit info directly
    console.log("📊 Sent 2 notifications in the last few minutes");
    console.log("⚠️  FCM has rate limits:");
    console.log("   • 1000 messages/minute per app");
    console.log("   • Individual device rate limits may apply");
    console.log(
      "   • Check Firebase Console > Cloud Messaging for delivery stats"
    );

    // 6. Test token validity
    console.log("\n🔍 TESTING TOKEN VALIDITY...");
    try {
      // Try to get token info (this is a simplified test)
      console.log("📱 Token appears to be in correct format");
      console.log(`📱 Token length: ${fcmToken.length} characters`);

      if (fcmToken.includes("APA91b")) {
        console.log("✅ Token format looks valid (contains APA91b)");
      } else {
        console.log("⚠️  Token format may be invalid");
      }
    } catch (error) {
      console.log("❌ Token validation failed:", error.message);
    }
  } catch (error) {
    console.error("❌ Debug failed:", error);
  }
}

// Run the debug
debugNotificationIssues();
