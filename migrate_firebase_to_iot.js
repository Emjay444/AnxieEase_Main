// Firebase Database Cleanup and IoT Migration Script
// This script removes old Bluetooth data and sets up the new IoT structure

const admin = require("firebase-admin");

// Initialize Firebase Admin (you'll need to set up your service account)
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.database();

async function migrateToIoTStructure() {
  console.log(
    "🔧 Starting Firebase migration from Bluetooth to IoT structure..."
  );

  try {
    // 1. Clean up old Bluetooth data structure
    console.log("🗑️ Removing old Bluetooth data...");

    // Remove old device data with Bluetooth structure
    const devicesRef = db.ref("devices");
    const snapshot = await devicesRef.once("value");

    if (snapshot.exists()) {
      const devices = snapshot.val();

      for (const deviceId in devices) {
        const device = devices[deviceId];

        // Check if this is old Bluetooth data structure
        if (device.Metrics && device.Metrics.deviceAddress) {
          console.log(`🔄 Migrating device: ${deviceId}`);

          // Remove old Bluetooth structure
          await devicesRef.child(deviceId).remove();
          console.log(`✅ Removed old Bluetooth data for ${deviceId}`);
        }
      }
    }

    // 2. Initialize/repair IoT structure for AnxieEase001
    console.log("🚀 Setting up new IoT structure...");

    const iotDeviceRef = db.ref("devices/AnxieEase001");

    // Set up device metadata with IoT structure
    await iotDeviceRef.child("metadata").set({
      deviceId: "AnxieEase001",
      deviceType: "simulated_health_monitor",
      userId: "user_001",
      status: "initialized",
      lastInitialized: admin.database.ServerValue.TIMESTAMP,
      isSimulated: true,
      created: admin.database.ServerValue.TIMESTAMP,
      version: "2.0.0",
      architecture: "pure_iot_firebase",
    });

    // Set up initial sensor data structure (uses severityLevel, no isStressDetected)
    await iotDeviceRef.child("current").set({
      heartRate: 72,
      spo2: 98,
      bodyTemp: 36.5,
      ambientTemp: 23.0,
      battPerc: 85,
      worn: true,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      deviceId: "AnxieEase001",
      userId: "user_001",
      severityLevel: "mild",
      source: "iot_simulation",
      connectionStatus: "initialized",
    });

    // 3. One-time cleanup across all devices/current:
    //    - remove legacy isStressDetected
    //    - ensure severityLevel exists (default to 'mild')
    console.log(
      "🧹 Running one-time cleanup: removing isStressDetected and ensuring severityLevel..."
    );
    const allDevicesSnap = await devicesRef.once("value");
    if (allDevicesSnap.exists()) {
      const updates = {};
      const devices = allDevicesSnap.val();
      for (const dId in devices) {
        const d = devices[dId] || {};
        const current = d.current || {};
        // Remove old key
        updates[`/devices/${dId}/current/isStressDetected`] = null;
        // Backfill severityLevel if missing
        if (
          current.severityLevel === undefined ||
          current.severityLevel === null
        ) {
          updates[`/devices/${dId}/current/severityLevel`] = "mild";
        }
      }
      if (Object.keys(updates).length) {
        await db.ref().update(updates);
        console.log("✅ Cleanup applied across devices");
      } else {
        console.log("ℹ️ No devices to clean");
      }
    }

    // Set up historical data structure (placeholder)
    await iotDeviceRef.child("history").child("sessions").set({
      placeholder: "Historical sensor data sessions will be stored here",
    });

    // Set up user data structure
    const usersRef = db.ref("users/user_001");
    await usersRef.set({
      userId: "user_001",
      deviceId: "AnxieEase001",
      lastActivity: admin.database.ServerValue.TIMESTAMP,
      preferences: {
        dataFrequency: 2000, // 2 seconds
        stressDetection: true,
        historicalDataRetention: 30, // days
      },
    });

    console.log("✅ Firebase migration completed successfully!");
    console.log("📊 New IoT structure:");
    console.log("- devices/AnxieEase001/metadata - Device information");
    console.log("- devices/AnxieEase001/current - Real-time sensor data");
    console.log("- devices/AnxieEase001/history - Historical data");
    console.log("- users/user_001 - User preferences and settings");
  } catch (error) {
    console.error("❌ Migration failed:", error);
  } finally {
    // Close the connection
    admin.app().delete();
  }
}

// Run the migration
migrateToIoTStructure();
