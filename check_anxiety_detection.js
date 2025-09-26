const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function checkAnxietyDetection() {
  console.log("🔍 CHECKING ANXIETY DETECTION SYSTEM...");
  console.log("═".repeat(50));

  try {
    // Check recent sensor data processing
    console.log("📊 Checking recent sensor data...");
    const devicePath = "/devices/AnxieEase001";

    // Check current data
    const current = await db.ref(`${devicePath}/current`).once("value");
    if (current.exists()) {
      const data = current.val();
      console.log(`💓 Latest HR: ${data.heartRate} BPM`);
      console.log(`⏰ Timestamp: ${new Date(data.timestamp).toLocaleString()}`);
      console.log(`🌡️ Temperature: ${data.temperature}°C`);
      console.log(`💧 GSR: ${data.gsr}µS`);
    }

    // Check historical data (last 10 readings)
    console.log("\n📈 Recent sensor readings:");
    const history = await db
      .ref(`${devicePath}/sensorData`)
      .limitToLast(5)
      .once("value");
    if (history.exists()) {
      const readings = history.val();
      Object.keys(readings).forEach((key, index) => {
        const reading = readings[key];
        const time = new Date(reading.timestamp).toLocaleTimeString();
        console.log(
          `   ${index + 1}. ${time} - HR: ${reading.heartRate}, Temp: ${
            reading.temperature
          }°C`
        );
      });
    } else {
      console.log("   ❌ No historical sensor data found");
    }

    // Check anxiety alerts
    console.log("\n🚨 Checking anxiety alerts...");
    const alerts = await db
      .ref("/anxiety_alerts")
      .orderByChild("deviceId")
      .equalTo("AnxieEase001")
      .limitToLast(5)
      .once("value");
    if (alerts.exists()) {
      const alertList = alerts.val();
      console.log(
        `   ✅ Found ${Object.keys(alertList).length} recent alerts:`
      );
      Object.values(alertList).forEach((alert, index) => {
        console.log(
          `   ${index + 1}. ${new Date(
            alert.timestamp
          ).toLocaleString()} - Severity: ${alert.severity}`
        );
        console.log(`      Triggers: ${alert.triggers?.join(", ") || "N/A"}`);
      });
    } else {
      console.log("   ❌ No anxiety alerts found");
    }

    // Check native alerts
    console.log("\n📱 Checking native alerts...");
    const nativeAlerts = await db
      .ref("/native_alerts")
      .orderByChild("deviceId")
      .equalTo("AnxieEase001")
      .limitToLast(5)
      .once("value");
    if (nativeAlerts.exists()) {
      const alertList = nativeAlerts.val();
      console.log(
        `   ✅ Found ${Object.keys(alertList).length} native alerts:`
      );
      Object.values(alertList).forEach((alert, index) => {
        console.log(
          `   ${index + 1}. ${new Date(
            alert.timestamp
          ).toLocaleString()} - Type: ${alert.type}`
        );
        console.log(`      Status: ${alert.notificationStatus || "N/A"}`);
      });
    } else {
      console.log("   ❌ No native alerts found");
    }

    // Check user baseline for context
    console.log("\n👤 Checking user baseline...");
    const assignment = await db.ref(`${devicePath}/assignment`).once("value");
    if (assignment.exists()) {
      const userId = assignment.val().assignedUser;
      const baseline = await db.ref(`/users/${userId}/baseline`).once("value");
      if (baseline.exists()) {
        const baselineData = baseline.val();
        console.log(
          `   💓 Baseline HR: ${baselineData.restingHeartRate || "N/A"}`
        );
        console.log(
          `   📅 Last updated: ${new Date(
            baselineData.lastUpdated || 0
          ).toLocaleString()}`
        );
      } else {
        console.log("   ❌ No baseline data found");
      }
    }

    console.log("\n" + "═".repeat(50));
    console.log("💡 Analysis: If no alerts found despite elevated readings,");
    console.log("   the detection algorithm may need tuning or baseline data.");
  } catch (error) {
    console.error("❌ Error checking anxiety detection:", error);
  }
}

checkAnxietyDetection().catch(console.error);
