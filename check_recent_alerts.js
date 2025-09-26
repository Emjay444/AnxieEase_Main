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

async function checkRecentAlerts() {
  console.log("🚨 CHECKING FOR RECENT ALERTS...");
  console.log("═".repeat(40));

  try {
    // Get device assignment first
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const userId = assignment.val().assignedUser || assignment.val().userId;
    console.log("👤 User ID:", userId);

    // Check recent device data
    console.log("\n📊 Recent device data:");
    const current = await db.ref("/devices/AnxieEase001/current").once("value");
    if (current.exists()) {
      const data = current.val();
      console.log("✅ Latest HR:", data.heartRate + " BPM");
      console.log("   Timestamp:", data.timestamp);
      const timeAgo =
        (Date.now() -
          new Date(data.timestamp.replace(" ", "T") + "Z").getTime()) /
        1000;
      console.log("   Time ago:", timeAgo.toFixed(1) + " seconds");
    }

    // Check for recent alerts in multiple locations
    console.log("\n🔍 Checking alerts in native_alerts...");
    const nativeAlerts = await db
      .ref("/native_alerts")
      .limitToLast(5)
      .once("value");
    if (nativeAlerts.exists()) {
      const alerts = nativeAlerts.val();
      console.log(
        `✅ Found ${Object.keys(alerts).length} recent native alerts:`
      );
      Object.entries(alerts).forEach(([id, alert]) => {
        console.log(
          `   • ${new Date(alert.timestamp).toLocaleString()}: ${
            alert.severity
          } - ${alert.message}`
        );
      });
    } else {
      console.log("❌ No native alerts found");
    }

    console.log("\n🔍 Checking alerts in user alerts...");
    const userAlerts = await db
      .ref(`/users/${userId}/alerts`)
      .limitToLast(5)
      .once("value");
    if (userAlerts.exists()) {
      const alerts = userAlerts.val();
      console.log(`✅ Found ${Object.keys(alerts).length} user alerts:`);
      Object.entries(alerts).forEach(([id, alert]) => {
        console.log(
          `   • ${new Date(alert.timestamp).toLocaleString()}: ${
            alert.severity
          } - ${alert.message || alert.type}`
        );
      });
    } else {
      console.log("❌ No user alerts found");
    }

    console.log("\n🔍 Checking for anxiety_alerts...");
    const anxietyAlerts = await db
      .ref("/anxiety_alerts")
      .limitToLast(5)
      .once("value");
    if (anxietyAlerts.exists()) {
      const alerts = anxietyAlerts.val();
      console.log(`✅ Found ${Object.keys(alerts).length} anxiety alerts:`);
      Object.entries(alerts).forEach(([id, alert]) => {
        console.log(
          `   • ${new Date(alert.timestamp).toLocaleString()}: ${
            alert.severity
          } - ${alert.message}`
        );
      });
    } else {
      console.log("❌ No anxiety alerts found");
    }

    // Check user session history build up
    console.log("\n📈 Checking user session history build up...");
    const historyRef = db.ref(`/users/${userId}/sensors/session_history`);
    const history = await historyRef.limitToLast(10).once("value");

    if (history.exists()) {
      const historyData = history.val();
      const entries = Object.keys(historyData).length;
      console.log(`✅ Session history has ${entries} recent entries`);

      // Show last few entries
      const sortedEntries = Object.entries(historyData).sort(
        (a, b) => b[1].timestamp - a[1].timestamp
      );
      console.log("   Recent entries:");
      sortedEntries.slice(0, 3).forEach(([key, entry]) => {
        console.log(
          `   • ${new Date(entry.timestamp).toLocaleString()}: HR=${
            entry.heartRate
          } BPM`
        );
      });
    } else {
      console.log(
        "❌ No session history entries found - this might be the issue!"
      );
    }
  } catch (error) {
    console.error("❌ Error checking alerts:", error);
  }
}

checkRecentAlerts().catch(console.error);
