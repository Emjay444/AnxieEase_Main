const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

async function checkDeviceData() {
  console.log("🔍 Checking device data and notifications...\n");

  try {
    // Check device current data
    const deviceRef = db.ref("devices/AnxieEase001/current");
    const deviceSnapshot = await deviceRef.once("value");
    const deviceData = deviceSnapshot.val();

    console.log("📱 Device Current Data:");
    if (deviceData) {
      console.log(`   Heart Rate: ${deviceData.heartRate} BPM`);
      console.log(
        `   Movement: accelX=${deviceData.accelX}, accelY=${deviceData.accelY}, accelZ=${deviceData.accelZ}`
      );
      console.log(
        `   Gyroscope: gyroX=${deviceData.gyroX}, gyroY=${deviceData.gyroY}, gyroZ=${deviceData.gyroZ}`
      );
      console.log(
        `   Timestamp: ${new Date(deviceData.timestamp).toLocaleString()}`
      );
      console.log(
        `   Data Age: ${Math.floor(
          (Date.now() - deviceData.timestamp) / 1000
        )} seconds ago\n`
      );
    } else {
      console.log("   ❌ No current data found\n");
    }

    // Check device assignment
    const assignmentRef = db.ref("devices/AnxieEase001/assignment");
    const assignmentSnapshot = await assignmentRef.once("value");
    const assignment = assignmentSnapshot.val();

    console.log("👤 Device Assignment:");
    if (assignment) {
      console.log(`   User ID: ${assignment.userId}`);
      console.log(`   Baseline HR: ${assignment.baselineHeartRate} BPM`);
      console.log(`   Active: ${assignment.active}\n`);
    } else {
      console.log("   ❌ No assignment found\n");
    }

    // Check user FCM token
    if (assignment && assignment.userId) {
      const userRef = db.ref(`users/${assignment.userId}`);
      const userSnapshot = await userRef.once("value");
      const userData = userSnapshot.val();

      console.log("🔔 User Notification Setup:");
      if (userData) {
        console.log(
          `   FCM Token: ${userData.fcmToken ? "✅ Present" : "❌ Missing"}`
        );
        if (userData.fcmToken) {
          console.log(`   Token: ${userData.fcmToken.substring(0, 30)}...`);
        }
        console.log(
          `   Notifications Enabled: ${
            userData.notificationsEnabled ? "✅ Yes" : "❌ No"
          }\n`
        );
      } else {
        console.log("   ❌ No user data found\n");
      }

      // Check recent notifications
      const notifRef = db.ref(`users/${assignment.userId}/notifications`);
      const notifSnapshot = await notifRef
        .orderByChild("timestamp")
        .limitToLast(5)
        .once("value");

      console.log("📬 Recent Notifications:");
      const notifications = notifSnapshot.val();
      if (notifications) {
        Object.entries(notifications)
          .sort(([, a], [, b]) => b.timestamp - a.timestamp)
          .forEach(([id, notif]) => {
            console.log(
              `   ${new Date(notif.timestamp).toLocaleString()}: ${
                notif.message
              }`
            );
          });
      } else {
        console.log("   No notifications found");
      }
    }

    // Calculate thresholds
    if (assignment && assignment.baselineHeartRate) {
      const baseline = assignment.baselineHeartRate;
      console.log("\n🎯 Anxiety Detection Thresholds:");
      console.log(`   Baseline: ${baseline} BPM`);
      console.log(`   Mild (with confirmation): ${baseline + 15} BPM`);
      console.log(`   Moderate (with confirmation): ${baseline + 25} BPM`);
      console.log(`   Severe (immediate): ${baseline + 35} BPM`);

      if (deviceData && deviceData.heartRate) {
        const currentHR = deviceData.heartRate;
        console.log(`   Current HR: ${currentHR} BPM`);

        if (currentHR >= baseline + 35) {
          console.log("   🚨 SEVERE ANXIETY - Should trigger immediate alert!");
        } else if (currentHR >= baseline + 25) {
          console.log("   ⚠️  MODERATE ANXIETY - Should ask for confirmation");
        } else if (currentHR >= baseline + 15) {
          console.log("   💛 MILD ANXIETY - Should ask for confirmation");
        } else {
          console.log("   ✅ Normal heart rate");
        }
      }
    }
  } catch (error) {
    console.error("Error checking device data:", error);
  }

  process.exit(0);
}

checkDeviceData();
