/**
 * 🔍 CHECK CURRENT DEVICE ASSIGNMENT
 *
 * This script checks what user is currently assigned to AnxieEase001
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

async function checkDeviceAssignment() {
  console.log("\n🔍 CHECKING CURRENT DEVICE ASSIGNMENT");
  console.log("====================================");

  try {
    // Check AnxieEase001 assignment
    const assignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const assignment = assignmentSnapshot.val();

    if (assignment) {
      console.log("✅ Device AnxieEase001 is assigned!");
      console.log(`   Assigned to user: ${assignment.userId}`);
      console.log(`   Session ID: ${assignment.sessionId}`);
      console.log(`   Status: ${assignment.status}`);
      console.log(
        `   Assigned at: ${new Date(assignment.assignedAt).toLocaleString()}`
      );
      console.log(`   Admin notes: ${assignment.adminNotes || "None"}`);

      // Return the user ID so you can use it in your test
      console.log(`\n📋 COPY THIS USER ID FOR YOUR TEST:`);
      console.log(`   TEST_USER_ID = "${assignment.userId}"`);
    } else {
      console.log("❌ No device assignment found for AnxieEase001");
      console.log(
        "Please assign the device through your admin dashboard first"
      );
    }
  } catch (error) {
    console.error("❌ Error checking assignment:", error.message);
  }
}

checkDeviceAssignment();
