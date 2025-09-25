const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

async function fixBaselineSync() {
  console.log("🔧 Fixing baseline sync for notifications...\n");

  try {
    // The logs showed baseline 73.2 BPM for user 5afad7d4-3dcd-4353-badb-4f155303419a
    // But device is assigned to 5efad7d4-3dd1-4355-badb-4f68bc0ab4df
    // Let me update the correct assignment

    const deviceId = "AnxieEase001";
    const userId = "5efad7d4-3dd1-4355-badb-4f68bc0ab4df";
    const baseline = 73.2;

    console.log("📝 Updating device assignment with baseline...");
    await db.ref(`devices/${deviceId}/assignment`).set({
      userId: userId,
      baselineHeartRate: baseline,
      active: true,
      assignedAt: Date.now(),
      source: "notification_fix",
    });

    console.log("📝 Updating user baseline...");
    await db.ref(`users/${userId}/baseline`).set({
      heartRate: baseline,
      updatedAt: Date.now(),
      source: "notification_sync",
    });

    console.log("📝 Ensuring user notification settings...");
    await db.ref(`users/${userId}/settings`).set({
      notificationsEnabled: true,
      anxietyAlertsEnabled: true,
      confirmationRequired: true,
      updatedAt: Date.now(),
    });

    console.log("✅ Baseline sync completed!");
    console.log(`   Device: ${deviceId}`);
    console.log(`   User: ${userId}`);
    console.log(`   Baseline: ${baseline} BPM`);
    console.log(
      `   Thresholds: ${baseline + 15}+ (mild), ${baseline + 25}+ (moderate), ${
        baseline + 35
      }+ (severe)`
    );
  } catch (error) {
    console.error("❌ Error fixing baseline sync:", error);
  }

  process.exit(0);
}

fixBaselineSync();
