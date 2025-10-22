/**
 * Quick FCM Status Check
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function checkStatus() {
  try {
    console.log("🔍 Checking FCM Token Status...\n");

    // Check assignment
    const assignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log("✅ Assignment exists:");
      console.log(`   User: ${assignment.assignedUser || "N/A"}`);
      console.log(
        `   FCM Token: ${
          assignment.fcmToken
            ? "EXISTS (" + assignment.fcmToken.substring(0, 40) + "...)"
            : "❌ MISSING"
        }`
      );
      console.log(`   Status: ${assignment.status || "N/A"}`);
      console.log(
        `   Last Token Refresh: ${
          assignment.lastTokenRefresh
            ? new Date(assignment.lastTokenRefresh).toLocaleString()
            : "N/A"
        }`
      );

      if (assignment.fcmToken) {
        console.log("\n✅ FCM Token is present in assignment!");
        console.log("\n💡 Next Steps:");
        console.log("   1. Make sure your app is running and in foreground");
        console.log("   2. Check notification permissions are enabled");
        console.log("   3. Run: node test_all_notifications.js");

        // Check if token is valid by attempting to send a test
        console.log("\n🧪 Testing if token is valid...");
        try {
          const testMessage = {
            token: assignment.fcmToken,
            data: {
              type: "test",
              title: "Token Test",
              message: "If you see this, your FCM token works!",
            },
          };

          const result = await admin.messaging().send(testMessage);
          console.log("✅ Token is VALID! Test message sent:", result);
          console.log("📱 Check your device - you should see a notification!");
        } catch (error) {
          console.error("❌ Token is INVALID or EXPIRED!");
          console.error(`   Error: ${error.code} - ${error.message}`);
          console.error(
            "\n💡 SOLUTION: Restart your app to get a fresh FCM token"
          );
        }
      } else {
        console.log("\n❌ No FCM token in assignment!");
        console.log("\n💡 SOLUTIONS:");
        console.log("   1. Restart your Flutter app");
        console.log("   2. Check lib/main.dart FCM initialization");
        console.log("   3. Verify Google Play Services is installed");
        console.log("   4. Check app logs for FCM errors");
      }
    } else {
      console.log("❌ No assignment found for device AnxieEase001");
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

checkStatus();
