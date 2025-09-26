const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function checkFCMToken() {
  const db = admin.database();
  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";

  console.log(`🔍 Checking FCM token for user: ${userId}`);

  try {
    // Check user profile for FCM token
    const userRef = db.ref(`/users/${userId}`);
    const userSnapshot = await userRef.once("value");

    if (userSnapshot.exists()) {
      const userData = userSnapshot.val();
      console.log("📱 User profile exists but checking for FCM token...");

      if (userData.fcmToken) {
        console.log(`✅ FCM Token found in user profile: ${userData.fcmToken}`);
        return userData.fcmToken;
      } else {
        console.log("❌ No FCM token found in user profile");
      }
    } else {
      console.log("❌ User profile not found");
    }

    // Also check device assignment for FCM token
    const deviceRef = db.ref("/devices/AnxieEase001");
    const deviceSnapshot = await deviceRef.once("value");

    if (deviceSnapshot.exists()) {
      const deviceData = deviceSnapshot.val();
      console.log("📱 Device data:");
      console.log(JSON.stringify(deviceData, null, 2));

      if (deviceData.fcmToken) {
        console.log(`✅ FCM Token found in device: ${deviceData.fcmToken}`);
        return deviceData.fcmToken;
      } else {
        console.log("❌ No fcmToken field found in device data");
      }
    }

    return null;
  } catch (error) {
    console.error("Error checking FCM token:", error);
    return null;
  }
}

// Test FCM token and send test notification
async function testNotification() {
  const fcmToken = await checkFCMToken();

  if (!fcmToken) {
    console.log(
      "\n🤔 No FCM token found. To get notifications when app is closed:"
    );
    console.log("1. Run the Flutter app once to register FCM token");
    console.log("2. The app will store the token in Firebase");
    console.log("3. Then you can close the app and test notifications");
    return;
  }

  console.log("\n🧪 Testing FCM notification...");

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: "🚨 Anxiety Alert - Test",
        body: "Sustained elevated heart rate detected (10+ seconds)",
      },
      data: {
        type: "anxiety_alert",
        userId: "5afad7d4-3dcd-4353-badb-4f155303419a",
        severity: "mild",
        heartRate: "91",
        baseline: "73",
        duration: "10",
      },
      android: {
        priority: "high",
        notification: {
          color: "#FFA726",
          sound: "default",
          channelId: "anxiety_alerts",
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Test notification sent successfully!");
    console.log("📱 Message ID:", response);
    console.log("🔔 Check your device for the notification");
  } catch (error) {
    console.error("❌ Error sending test notification:", error);
  }
}

testNotification();
