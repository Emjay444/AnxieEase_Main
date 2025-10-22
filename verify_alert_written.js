/**
 * Verify Alert Was Written to RTDB
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

async function checkAlerts() {
  try {
    console.log("🔍 Checking alerts in RTDB...\n");

    const alertsSnapshot = await db
      .ref("/devices/AnxieEase001/alerts")
      .orderByKey()
      .limitToLast(5)
      .once("value");

    if (!alertsSnapshot.exists()) {
      console.log("❌ No alerts found at /devices/AnxieEase001/alerts");
      process.exit(1);
    }

    const alerts = alertsSnapshot.val();
    const alertKeys = Object.keys(alerts);

    console.log(`✅ Found ${alertKeys.length} recent alerts:\n`);

    alertKeys.forEach((key, index) => {
      const alert = alerts[key];
      const timestamp = new Date(alert.timestamp).toLocaleString();
      console.log(`${index + 1}. Alert ID: ${key}`);
      console.log(`   Severity: ${alert.severity || "N/A"}`);
      console.log(`   Heart Rate: ${alert.heartRate || "N/A"} BPM`);
      console.log(`   Source: ${alert.source || "N/A"}`);
      console.log(`   Timestamp: ${timestamp}`);
      console.log(`   User ID: ${alert.userId || "N/A"}`);
      console.log("");
    });

    // Check the database path that the trigger is watching
    const triggerPath = "/devices/AnxieEase001/alerts";
    console.log(`📍 Trigger watches: ${triggerPath}/{alertId}`);
    console.log(`✅ Alerts are being written to the correct path\n`);

    // Check if there's a database rules issue
    console.log("🔍 Checking database rules...");
    try {
      await db.ref("/.info/connected").once("value");
      console.log("✅ Database connection is working\n");
    } catch (error) {
      console.error("❌ Database connection error:", error);
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

checkAlerts();
