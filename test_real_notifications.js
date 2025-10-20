/**
 * Test Real Notifications Script
 * This script simulates real heart rate data to trigger actual anxiety detection
 * and notifications with custom sounds for different severity levels.
 *
 * UPDATED BASELINE: 76.4 BPM (from device assignment)
 * User: e0997cb7-68df-41e6-923f-48107872d434
 * 
 * Thresholds:
 * Mild: 96+ BPM (25% above baseline)
 * Moderate: 107+ BPM (40% above baseline)
 * Severe: 122+ BPM (60% above baseline)
 * Critical: 138+ BPM (80% above baseline)
 */

const admin = require("firebase-admin");

// Suppress Firebase warnings
process.env.FIREBASE_DATABASE_EMULATOR_HOST = undefined;

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
  console.log("✅ Firebase Admin initialized successfully\n");
}

const db = admin.database();

// Test configuration - UPDATED WITH CORRECT USER AND BASELINE
const BASELINE_BPM = 76.4; // Correct baseline from device assignment
const TEST_DEVICE_ID = "AnxieEase001"; // Your actual device ID
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434"; // Correct user ID from device assignment
const TEST_SESSION_ID = "session_" + Date.now();

// Calculate heart rates for each severity level
const HEART_RATES = {
  mild: Math.round(BASELINE_BPM * 1.25), // 25% above baseline = 96 BPM
  moderate: Math.round(BASELINE_BPM * 1.4), // 40% above baseline = 107 BPM
  severe: Math.round(BASELINE_BPM * 1.6), // 60% above baseline = 122 BPM
  critical: Math.round(BASELINE_BPM * 1.8), // 80% above baseline = 138 BPM
};

console.log("🔍 Heart Rate Test Values Based on 76.4 BPM Baseline:");
console.log(`📊 Mild: ${HEART_RATES.mild} BPM`);
console.log(`📊 Moderate: ${HEART_RATES.moderate} BPM`);
console.log(`📊 Severe: ${HEART_RATES.severe} BPM`);
console.log(`📊 Critical: ${HEART_RATES.critical} BPM\n`);

// Function to setup device assignment and user baseline (required for sustained detection)
async function setupDeviceAssignment() {
  console.log("🔧 Setting up device assignment and user baseline...");

  try {
    // Set up device assignment with your real user
    const assignmentData = {
      [`/devices/${TEST_DEVICE_ID}/assignment/assignedUser`]: TEST_USER_ID,
      [`/devices/${TEST_DEVICE_ID}/assignment/activeSessionId`]:
        TEST_SESSION_ID,
      [`/devices/${TEST_DEVICE_ID}/assignment/assignedAt`]: Date.now(),
      [`/devices/${TEST_DEVICE_ID}/assignment/assignedBy`]: "test_script",
      [`/devices/${TEST_DEVICE_ID}/assignment/status`]: "active",
      [`/devices/${TEST_DEVICE_ID}/assignment/deviceId`]: TEST_DEVICE_ID,
      // Store baseline in the assignment/supabaseSync location like your real data
      [`/devices/${TEST_DEVICE_ID}/assignment/supabaseSync/baselineHR`]:
        BASELINE_BPM,
      [`/devices/${TEST_DEVICE_ID}/assignment/supabaseSync/syncedAt`]:
        Date.now(),
    };

    // Write assignment data (no separate user baseline needed)
    await db.ref().update(assignmentData);

    console.log("✅ Device assignment configured with real user");
    console.log(`� User: ${TEST_USER_ID}`);
    console.log(`🔗 Device: ${TEST_DEVICE_ID}`);
    console.log(
      `💓 Baseline: ${BASELINE_BPM} BPM (stored in assignment/supabaseSync)`
    );
    console.log(`📱 Session: ${TEST_SESSION_ID}\n`);
  } catch (error) {
    console.error("❌ Error setting up device assignment:", error);
    throw error;
  }
}

// Function to simulate sustained heart rate data
async function simulateSustainedHeartRate(severity, duration = 35000) {
  const heartRate = HEART_RATES[severity];
  const startTime = Date.now();

  console.log(
    `🫀 Starting ${severity.toUpperCase()} simulation: ${heartRate} BPM for ${
      duration / 1000
    }s`
  );

  // Set up device assignment first (required for sustained detection)
  await setupDeviceAssignment();

  // Simulate heart rate data points every 2 seconds for the duration
  const interval = setInterval(async () => {
    const currentTime = Date.now();
    const elapsed = currentTime - startTime;

    if (elapsed >= duration) {
      clearInterval(interval);
      console.log(`✅ ${severity.toUpperCase()} simulation completed`);
      return;
    }

    // Add some realistic variation (±2-5 BPM)
    const variation = Math.floor(Math.random() * 6) - 3; // -3 to +3
    const currentHeartRate = heartRate + variation;

    // Write to devices path (triggers realTimeSustainedAnxietyDetection)
    const deviceData = {
      [`/devices/${TEST_DEVICE_ID}/current/heartRate`]: currentHeartRate,
      [`/devices/${TEST_DEVICE_ID}/current/timestamp`]: currentTime,
      [`/devices/${TEST_DEVICE_ID}/current/batteryLevel`]: 85,
      [`/devices/${TEST_DEVICE_ID}/current/isConnected`]: true,
    };

    // Also write to user session path
    const userSessionData = {
      [`/users/${TEST_USER_ID}/sessions/current/heartRate`]: currentHeartRate,
      [`/users/${TEST_USER_ID}/sessions/current/timestamp`]: currentTime,
      [`/users/${TEST_USER_ID}/sessions/current/deviceId`]: TEST_DEVICE_ID,
    };

    try {
      await db.ref().update(deviceData);
      await db.ref().update(userSessionData);
      console.log(
        `💓 ${severity}: ${currentHeartRate} BPM (${elapsed / 1000}s elapsed)`
      );
    } catch (error) {
      console.error("❌ Error writing heart rate data:", error);
    }
  }, 2000); // Every 2 seconds
}

// Function to trigger direct alert (for immediate testing)
async function triggerDirectAlert(severity) {
  const heartRate = HEART_RATES[severity];
  const timestamp = Date.now();

  console.log(
    `🚨 Triggering direct ${severity.toUpperCase()} alert: ${heartRate} BPM`
  );

  const alertData = {
    severity: severity,
    heartRate: heartRate,
    timestamp: timestamp,
    confidence: 85,
    baseline: BASELINE_BPM,
    alertType: "direct_test",
    deviceId: TEST_DEVICE_ID,
    userId: TEST_USER_ID,
    source: "test", // CRITICAL: Required for Cloud Function to process alert
  };

  try {
    // Write to alerts path (triggers onNativeAlertCreate)
    console.log(`📝 Writing alert to /devices/${TEST_DEVICE_ID}/alerts...`);
    const alertRef = db.ref(`/devices/${TEST_DEVICE_ID}/alerts`).push();
    console.log(`📍 Generated alert ID: ${alertRef.key}`);
    
    console.log(`💾 Saving alert data...`);
    await alertRef.set(alertData);

    console.log(`✅ Direct ${severity} alert triggered successfully!`);
    console.log(`📍 Alert ID: ${alertRef.key}`);
    console.log(
      `📱 Check your device for the notification with custom ${severity} sound`
    );
    console.log(`\n💡 Run 'node verify_alert_sent.js' to verify the alert was created\n`);

    return alertRef.key;
  } catch (error) {
    console.error(`❌ Error triggering ${severity} alert:`, error);
    throw error;
  }
}

// Main test menu
async function runTest() {
  const args = process.argv.slice(2);
  const testType = args[0];
  const severity = args[1];

  if (!testType || !severity) {
    console.log("🎯 Real Notification Test Options:");
    console.log("");
    console.log("📱 DIRECT ALERTS (Immediate notification):");
    console.log("   node test_real_notifications.js direct mild");
    console.log("   node test_real_notifications.js direct moderate");
    console.log("   node test_real_notifications.js direct severe");
    console.log("   node test_real_notifications.js direct critical");
    console.log("");
    console.log("⏱️ SUSTAINED DETECTION (35-second simulation):");
    console.log("   node test_real_notifications.js sustained mild");
    console.log("   node test_real_notifications.js sustained moderate");
    console.log("   node test_real_notifications.js sustained severe");
    console.log("   node test_real_notifications.js sustained critical");
    console.log("");
    console.log("💡 Direct alerts trigger immediately");
    console.log(
      "💡 Sustained detection simulates real-world gradual heart rate increase"
    );
    process.exit(0);
  }

  if (!["mild", "moderate", "severe", "critical"].includes(severity)) {
    console.error(
      "❌ Invalid severity. Use: mild, moderate, severe, or critical"
    );
    process.exit(1);
  }

  console.log(`🎯 Testing ${testType} ${severity} notification...`);
  console.log(
    `📱 Make sure your app is running and notifications are enabled!`
  );
  console.log(`🔊 Listen for the custom ${severity} alert sound\n`);

  try {
    if (testType === "direct") {
      await triggerDirectAlert(severity);
      console.log("\n✅ Test completed successfully!");
      process.exit(0);
    } else if (testType === "sustained") {
      await simulateSustainedHeartRate(severity);
    } else {
      console.error("❌ Invalid test type. Use: direct or sustained");
      process.exit(1);
    }
  } catch (error) {
    console.error("\n❌ Test failed:", error.message);
    console.error(error);
    process.exit(1);
  }
}

// Handle script termination
process.on("SIGINT", () => {
  console.log("\n🛑 Test interrupted. Cleaning up...");
  process.exit(0);
});

runTest().catch(console.error);
