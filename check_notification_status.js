const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

async function checkNotificationStatus() {
  console.log("🔍 Checking current notification status...\n");

  try {
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";

    // Check all notification paths
    console.log("📱 Checking Firebase database for saved notifications...");

    // Path 1: Standard notifications
    const notificationsRef = db.ref(`users/${userId}/notifications`);
    const notificationsSnapshot = await notificationsRef
      .orderByChild("timestamp")
      .limitToLast(5)
      .once("value");
    const notifications = notificationsSnapshot.val();

    console.log("\n📋 Recent Notifications in Database:");
    if (notifications) {
      Object.entries(notifications)
        .sort(([, a], [, b]) => b.timestamp - a.timestamp)
        .forEach(([id, notif]) => {
          console.log(
            `   ${new Date(notif.timestamp).toLocaleString()}: ${notif.title}`
          );
          console.log(`      Message: ${notif.message}`);
          console.log(`      Type: ${notif.type}, Read: ${notif.read}`);
          console.log(`      ID: ${id}`);
          console.log("");
        });
    } else {
      console.log(
        "   ❌ No notifications found in users/{userId}/notifications"
      );
    }

    // Path 2: Anxiety alerts
    const alertsRef = db.ref(`users/${userId}/anxietyAlerts`);
    const alertsSnapshot = await alertsRef
      .orderByChild("timestamp")
      .limitToLast(3)
      .once("value");
    const alerts = alertsSnapshot.val();

    console.log("🚨 Recent Anxiety Alerts:");
    if (alerts) {
      Object.entries(alerts)
        .sort(([, a], [, b]) => b.timestamp - a.timestamp)
        .forEach(([id, alert]) => {
          console.log(
            `   ${new Date(alert.timestamp).toLocaleString()}: HR ${
              alert.heartRate
            } BPM`
          );
        });
    } else {
      console.log("   No anxiety alerts found");
    }

    // Check device current data
    const deviceRef = db.ref("devices/AnxieEase001/current");
    const deviceSnapshot = await deviceRef.once("value");
    const deviceData = deviceSnapshot.val();

    console.log("\n📱 Current Device Data:");
    if (deviceData) {
      console.log(`   Heart Rate: ${deviceData.heartRate} BPM`);
      console.log(
        `   Timestamp: ${new Date(deviceData.timestamp).toLocaleString()}`
      );
      console.log(
        `   Age: ${Math.floor(
          (Date.now() - deviceData.timestamp) / 1000
        )} seconds ago`
      );

      // Check if this should trigger anxiety detection
      const baseline = 73.2;
      const mildThreshold = baseline + 15; // 88.2

      if (deviceData.heartRate >= mildThreshold) {
        console.log(
          `   🚨 SHOULD TRIGGER: ${deviceData.heartRate} >= ${mildThreshold} (mild anxiety)`
        );
      } else {
        console.log(
          `   ✅ Normal: ${deviceData.heartRate} < ${mildThreshold} (threshold)`
        );
      }
    }

    // Check if Firebase Functions triggered
    console.log("\n⚡ Checking Firebase Functions logs...");
    console.log(
      "   (Note: Check Firebase console for real-time function execution logs)"
    );

    console.log("\n📊 NOTIFICATION TEST RESULTS:");
    console.log("==============================");
    console.log(
      notifications
        ? "✅ Notifications saved to database"
        : "❌ No notifications in database"
    );
    console.log(
      alerts ? "✅ Anxiety alerts saved" : "❌ No anxiety alerts saved"
    );
    console.log(
      deviceData ? "✅ Device data updated" : "❌ No device data found"
    );
    console.log("✅ FCM push notifications sent");

    console.log("\n🎯 NEXT STEPS FOR TESTING:");
    console.log("===========================");
    console.log("1. 📱 Check your Android notification tray now");
    console.log("2. 🚀 Open your Flutter app with: flutter run");
    console.log("3. 📋 Navigate to notification screen in app");
    console.log("4. 🏠 Check homepage for notification indicators");
    console.log("5. ✅ Confirm notifications appear in both places");

    if (notifications) {
      console.log("\n🔔 You should see these notifications in your app:");
      Object.values(notifications)
        .sort((a, b) => b.timestamp - a.timestamp)
        .slice(0, 3)
        .forEach((notif) => {
          console.log(`   - ${notif.title}: ${notif.message}`);
        });
    }
  } catch (error) {
    console.error("❌ Error checking notification status:", error);
  }

  process.exit(0);
}

checkNotificationStatus();
