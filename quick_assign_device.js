/**
 * 🔧 Quick Device Assignment for Testing
 *
 * This script assigns the AnxieEase001 device to test-user-1 for testing purposes
 * Run this before running the anxiety detection test
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

const DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "test-user-1";

async function assignDeviceForTesting() {
  console.log("\n🔧 QUICK DEVICE ASSIGNMENT FOR TESTING");
  console.log("=====================================");

  try {
    // Create a test session ID
    const sessionId = `session_${Date.now()}`;

    console.log(`📟 Assigning device ${DEVICE_ID} to user ${TEST_USER_ID}`);

    // Set device assignment
    await db.ref(`/devices/${DEVICE_ID}/assignment`).set({
      userId: TEST_USER_ID,
      sessionId: sessionId,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      adminNotes: "Test assignment via script",
    });

    // Set user session metadata
    await db.ref(`/users/${TEST_USER_ID}/sessions/${sessionId}/metadata`).set({
      deviceId: DEVICE_ID,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      source: "admin_assignment",
    });

    console.log("✅ Device assignment completed!");
    console.log(`   User: ${TEST_USER_ID}`);
    console.log(`   Device: ${DEVICE_ID}`);
    console.log(`   Session: ${sessionId}`);
    console.log(`   Status: active`);

    console.log("\n🎯 Ready for anxiety detection testing!");
    console.log("Run: node test_real_user_anxiety_detection.js");
  } catch (error) {
    console.error("❌ Assignment failed:", error.message);
  }
}

assignDeviceForTesting();
