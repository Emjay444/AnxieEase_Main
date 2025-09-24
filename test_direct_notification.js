/**
 * 🧪 DIRECT FCM NOTIFICATION TEST
 *
 * This script tests if FCM notifications work directly to your phone/emulator.
 * Use this FIRST to verify FCM is working before testing anxiety detection.
 *
 * Prerequisites:
 * 1. Get FCM token from Flutter app console logs
 * 2. Paste the token in USER_FCM_TOKEN below
 * 3. Run: node test_direct_notification.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const messaging = admin.messaging();

// ⚠️ IMPORTANT: Replace with your real FCM token from Flutter app console logs
const USER_FCM_TOKEN =
  "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

/**
 * 🧪 Test direct FCM notification to verify FCM is working
 */
async function testDirectNotification() {
  console.log("\n🧪 TESTING DIRECT FCM NOTIFICATION");
  console.log("==================================");

  try {
    // Validate token is provided
    if (USER_FCM_TOKEN === "PASTE_YOUR_FCM_TOKEN_HERE") {
      throw new Error(`
⚠️  Please update USER_FCM_TOKEN with your real FCM token!

To get your FCM token:
1. Run your Flutter app on a phone/emulator
2. Login with any user account
3. Check the console logs for: "🔑 FCM registration token: ..."
4. Copy that ENTIRE token (it's very long ~150+ characters)
5. Paste it in this script at line 22
      `);
    }

    console.log("📱 Sending test notification to your device...");
    console.log(`   Target token: ${USER_FCM_TOKEN.substring(0, 20)}...`);

    // Create test notification message
    const message = {
      token: USER_FCM_TOKEN,
      notification: {
        title: "🧪 AnxieEase FCM Test",
        body: "Success! FCM notifications are working perfectly. Your anxiety detection system is ready!",
      },
      data: {
        type: "test",
        timestamp: Date.now().toString(),
        test_id: "direct_fcm_test",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "max",
          defaultSound: true,
          color: "#00FF00",
        },
      },
    };

    // Send the notification
    const response = await messaging.send(message);

    console.log("\n✅ NOTIFICATION SENT SUCCESSFULLY!");
    console.log("===================================");
    console.log(
      "📱 Check your phone/emulator - you should see the test notification!"
    );
    console.log(`📊 Message ID: ${response}`);
    console.log("\n🎉 FCM is working! You can now test anxiety detection.");

    return response;
  } catch (error) {
    console.error("\n❌ NOTIFICATION TEST FAILED!");
    console.error("=============================");

    if (error.code === "messaging/registration-token-not-registered") {
      console.error("🔍 Error: FCM token is invalid or expired");
      console.error("💡 Solution: Get a fresh FCM token from Flutter app");
    } else if (error.code === "messaging/invalid-registration-token") {
      console.error("🔍 Error: FCM token format is invalid");
      console.error(
        "💡 Solution: Make sure you copied the entire token correctly"
      );
    } else {
      console.error("🔍 Error details:", error);
    }

    console.error("\n🛠️  Troubleshooting steps:");
    console.error("1. Make sure Flutter app is running on your device");
    console.error("2. User must be logged in to the app");
    console.error("3. Copy the FCM token from console logs exactly");
    console.error("4. Check that Firebase project credentials are correct");

    process.exit(1);
  }
}

// Run the test
testDirectNotification()
  .then(() => {
    console.log("\n✨ Direct notification test completed successfully!");
    console.log("🚀 Ready to test full anxiety detection system!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Test failed:", error);
    process.exit(1);
  });
