const admin = require("firebase-admin");
const path = require("path");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-default-rtdb.firebaseio.com",
});

const db = admin.database();

async function sendRealAnxietyAlert(severity, heartRate = 75) {
  try {
    const deviceId = "AnxieEase001"; // Your device ID
    const alertId = `alert_${severity}_${Date.now()}`;
    const timestamp = Date.now();

    // Real alert data structure (as if coming from actual device sensors)
    const alertData = {
      severity: severity,
      heartRate: heartRate,
      timestamp: timestamp,
      source: "sensor",
      confidence: severity === "mild" ? 60 : severity === "moderate" ? 70 : 85,
      sensorData: {
        hrv: Math.floor(Math.random() * 50) + 20, // Random HRV
        stress:
          severity === "mild" ? 0.6 : severity === "moderate" ? 0.7 : 0.85,
        movement: Math.random() * 0.5, // Random movement data
      },
    };

    console.log(`� Sending REAL ${severity} anxiety alert to Firebase...`);
    console.log(`📍 Path: /devices/${deviceId}/alerts/${alertId}`);
    console.log(`📊 Data:`, alertData);

    // Write to Firebase - this will trigger the onNativeAlertCreate function
    await db.ref(`/devices/${deviceId}/alerts/${alertId}`).set(alertData);

    console.log(`✅ REAL ${severity} alert sent successfully!`);
    console.log(
      `🔔 This will trigger a REAL notification on your device in a few seconds.`
    );
    console.log("---");

    return alertId;
  } catch (error) {
    console.error(`❌ Error sending ${severity} alert:`, error);
    throw error;
  }
}

async function testAllSeverityLevels() {
  console.log("🚨 Testing REAL Anxiety Alert Notifications");
  console.log("==========================================");
  console.log(
    "This will send REAL anxiety alerts to Firebase to trigger actual notifications."
  );
  console.log(
    "Make sure your app is running and you have notification permissions enabled."
  );
  console.log("");

  try {
    // Send real mild alert
    await sendRealAnxietyAlert("mild", 78);
    await new Promise((resolve) => setTimeout(resolve, 8000)); // Wait 8 seconds

    // Send real moderate alert
    await sendRealAnxietyAlert("moderate", 95);
    await new Promise((resolve) => setTimeout(resolve, 8000)); // Wait 8 seconds

    // Send real severe alert
    await sendRealAnxietyAlert("severe", 120);
    await new Promise((resolve) => setTimeout(resolve, 5000)); // Wait 5 seconds

    console.log("🎉 All REAL anxiety alerts sent successfully!");
    console.log("📱 Check your device for REAL notifications.");
    console.log("⏰ Notifications may take 10-30 seconds to appear.");
  } catch (error) {
    console.error("❌ Error in alert sequence:", error);
  } finally {
    // Clean up
    process.exit(0);
  }
}

// Check command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
  // No arguments - send all real severity levels
  testAllSeverityLevels();
} else if (args.length >= 1) {
  // Single severity real alert
  const severity = args[0].toLowerCase();
  const heartRate = args[1] ? parseInt(args[1]) : 75;

  if (!["mild", "moderate", "severe"].includes(severity)) {
    console.error("❌ Invalid severity. Use: mild, moderate, or severe");
    process.exit(1);
  }

  console.log(`🚨 Sending REAL ${severity} anxiety alert`);
  sendRealAnxietyAlert(severity, heartRate)
    .then(() => {
      console.log("✅ REAL alert sent!");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Alert failed:", error);
      process.exit(1);
    });
}
