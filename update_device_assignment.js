/**
 * 🔄 UPDATE DEVICE ASSIGNMENT TO REAL USER
 *
 * This script updates the AnxieEase001 assignment to match your admin dashboard
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
const REAL_USER_ID = "5efad7d4-3dcd-4333-ba4b-41f86"; // From your admin dashboard

async function updateDeviceAssignment() {
  console.log("\n🔄 UPDATING DEVICE ASSIGNMENT TO REAL USER");
  console.log("==========================================");

  try {
    // Create a new session ID
    const sessionId = `session_${Date.now()}`;

    console.log(`📟 Updating device ${DEVICE_ID} assignment`);
    console.log(`   From: test-user-1`);
    console.log(`   To: ${REAL_USER_ID}`);

    // Update device assignment
    await db.ref(`/devices/${DEVICE_ID}/assignment`).set({
      userId: REAL_USER_ID,
      sessionId: sessionId,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      adminNotes: "Updated to match admin dashboard assignment",
    });

    // Set user session metadata
    await db.ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/metadata`).set({
      deviceId: DEVICE_ID,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      source: "admin_assignment_update",
    });

    // Clean up old test user assignment
    await db.ref(`/users/test-user-1`).remove();

    console.log("✅ Device assignment updated successfully!");
    console.log(`   Device: ${DEVICE_ID}`);
    console.log(`   User: ${REAL_USER_ID}`);
    console.log(`   Session: ${sessionId}`);
    console.log(`   Status: active`);

    console.log("\n🎯 Ready for real user testing!");
    console.log("Run: node test_background_anxiety_detection.js");
  } catch (error) {
    console.error("❌ Update failed:", error.message);
  }
}

updateDeviceAssignment();
