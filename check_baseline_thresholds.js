// Check baseline and threshold values for anxiety detection
const admin = require("firebase-admin");

// Initialize Firebase Admin using environment variables
admin.initializeApp({
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function checkThresholds() {
  console.log("🔍 Checking baseline and threshold values...\n");

  try {
    const db = admin.database();

    // 1. Check user baseline values
    console.log("1️⃣ Checking user baseline values...");
    const usersSnapshot = await db.ref("users").once("value");
    const users = usersSnapshot.val();

    if (!users) {
      console.log("❌ No users found");
      return;
    }

    for (const [userId, userData] of Object.entries(users)) {
      console.log(`\n👤 User: ${userId}`);
      console.log(
        `📱 FCM Token: ${userData.fcmToken ? "✅ Present" : "❌ Missing"}`
      );
      console.log(
        `📡 Assigned Device: ${userData.assignedDevice || "❌ None"}`
      );

      if (userData.baseline) {
        console.log(`💓 Baseline HR: ${userData.baseline} BPM`);

        // Calculate thresholds based on baseline
        const mild = userData.baseline * 1.15; // 15% above baseline
        const moderate = userData.baseline * 1.25; // 25% above baseline
        const severe = userData.baseline * 1.35; // 35% above baseline
        const critical = userData.baseline * 1.5; // 50% above baseline

        console.log(`📊 Calculated thresholds:`);
        console.log(
          `   🟢 Mild: ${Math.round(mild)} BPM (${userData.baseline} + 15%)`
        );
        console.log(
          `   🟡 Moderate: ${Math.round(moderate)} BPM (${
            userData.baseline
          } + 25%)`
        );
        console.log(
          `   🟠 Severe: ${Math.round(severe)} BPM (${userData.baseline} + 35%)`
        );
        console.log(
          `   🔴 Critical: ${Math.round(critical)} BPM (${
            userData.baseline
          } + 50%)`
        );

        // Check if test heart rates would trigger
        console.log(`\n🧪 Test HR analysis:`);
        const testRates = [80, 95, 105, 120];
        for (const testHR of testRates) {
          let severity = "normal";
          if (testHR >= critical) severity = "critical";
          else if (testHR >= severe) severity = "severe";
          else if (testHR >= moderate) severity = "moderate";
          else if (testHR >= mild) severity = "mild";

          const trigger =
            severity !== "normal" ? "🚨 TRIGGERS" : "⭕ No trigger";
          console.log(`   ${testHR} BPM → ${severity} ${trigger}`);
        }
      } else {
        console.log(`❌ No baseline set for this user!`);
      }
    }

    // 2. Check current device data
    console.log("\n2️⃣ Checking current device data...");
    const devicesSnapshot = await db.ref("devices").once("value");
    const devices = devicesSnapshot.val();

    if (devices) {
      for (const [deviceId, deviceData] of Object.entries(devices)) {
        if (deviceData.current) {
          console.log(`\n📡 Device: ${deviceId}`);
          console.log(
            `💓 Current HR: ${deviceData.current.heartRate || "N/A"} BPM`
          );
          console.log(
            `⏰ Last updated: ${new Date(
              deviceData.current.timestamp || 0
            ).toLocaleString()}`
          );
        }
      }
    }

    // 3. Check recent user sessions for activity
    console.log("\n3️⃣ Checking recent user sessions...");
    for (const [userId, userData] of Object.entries(users)) {
      if (userData.assignedDevice) {
        const sessionRef = db.ref(`users/${userId}/sessions`);
        const sessionsSnapshot = await sessionRef.limitToLast(3).once("value");
        const sessions = sessionsSnapshot.val();

        if (sessions) {
          console.log(`\n📊 Recent sessions for user ${userId}:`);
          for (const [sessionId, sessionData] of Object.entries(sessions)) {
            console.log(
              `   Session ${sessionId}: ${
                sessionData.heartRate || "N/A"
              } BPM at ${new Date(sessionData.timestamp || 0).toLocaleString()}`
            );
          }
        } else {
          console.log(`\n📊 No recent sessions for user ${userId}`);
        }
      }
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }

  process.exit(0);
}

checkThresholds();
