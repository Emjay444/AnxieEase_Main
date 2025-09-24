/**
 * 🧪 TEST DATA WRITING
 *
 * Simple test to verify we can write heart rate data to Firebase
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

const REAL_USER_ID = "5efad7d4-3dcd-4333-ba4b-41f86";
const REAL_DEVICE_ID = "AnxieEase001";

async function testDataWriting() {
  console.log("\n🧪 TESTING DATA WRITING");
  console.log("======================");

  try {
    // Get current assignment
    const assignmentSnapshot = await db
      .ref(`/devices/${REAL_DEVICE_ID}/assignment`)
      .once("value");
    const assignment = assignmentSnapshot.val();

    if (!assignment) {
      console.log("❌ No device assignment found");
      return;
    }

    const sessionId = assignment.sessionId;
    console.log(`📋 Session ID: ${sessionId}`);

    // Try writing a single heart rate data point
    console.log("\n📊 Writing test heart rate data...");
    const testData = {
      heartRate: 95.5,
      timestamp: Date.now(),
      deviceId: REAL_DEVICE_ID,
      source: "test_data_writing",
    };

    const dataPath = `/users/${REAL_USER_ID}/sessions/${sessionId}/data`;
    console.log(`   Path: ${dataPath}`);

    const dataRef = db.ref(dataPath).push();
    await dataRef.set(testData);

    console.log("✅ Data written successfully!");
    console.log(`   Heart Rate: ${testData.heartRate} BPM`);
    console.log(
      `   Timestamp: ${new Date(testData.timestamp).toLocaleString()}`
    );

    // Verify the data was written
    console.log("\n🔍 Verifying data was stored...");
    const verifySnapshot = await db.ref(dataPath).once("value");
    const storedData = verifySnapshot.val();

    if (storedData) {
      const dataKeys = Object.keys(storedData);
      console.log(
        `✅ Verification successful! Found ${dataKeys.length} data point(s)`
      );

      // Show the data
      dataKeys.forEach((key) => {
        const point = storedData[key];
        console.log(
          `   ${key}: ${point.heartRate} BPM at ${new Date(
            point.timestamp
          ).toLocaleString()}`
        );
      });
    } else {
      console.log("❌ No data found - write may have failed");
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
    console.error("   Stack:", error.stack);
  }
}

testDataWriting();
