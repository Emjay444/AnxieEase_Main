const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.database();

async function fixFCMAssignment() {
  console.log("🔧 Fixing FCM token assignment issue...");

  try {
    // Check current assignment
    const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
    const assignmentSnap = await assignmentRef.once("value");
    const assignment = assignmentSnap.val();

    console.log("Current assignment:", assignment);

    if (
      assignment &&
      assignment.assignedUser !== "e0997cb7-68df-41e6-923f-48107872d434"
    ) {
      console.log("❌ Found conflicting assignment. Cleaning up...");

      // Clear the conflicting FCM token and user assignment
      await assignmentRef.update({
        fcmToken: null,
        tokenAssignedAt: null,
        lastTokenRefresh: null,
        assignedUser: "e0997cb7-68df-41e6-923f-48107872d434", // Set to correct user
      });

      console.log("✅ Cleaned up conflicting assignment");
    }

    // Also check for any test_user_001 references
    const testAssignmentCheck = await assignmentRef.once("value");
    const testAssignment = testAssignmentCheck.val();

    if (testAssignment && testAssignment.assignedUser === "test_user_001") {
      console.log("❌ Found test_user_001 assignment. Fixing...");

      await assignmentRef.update({
        assignedUser: "e0997cb7-68df-41e6-923f-48107872d434",
        fcmToken: null,
        tokenAssignedAt: null,
        lastTokenRefresh: null,
      });

      console.log("✅ Fixed test_user_001 assignment");
    }

    console.log(
      "✅ FCM assignment cleaned up. Now reopen your app to generate fresh FCM token!"
    );
    console.log("📱 Steps:");
    console.log("  1. Close your AnxieEase app completely");
    console.log("  2. Reopen and login");
    console.log("  3. The app should now store FCM token successfully");
    console.log("  4. Then run: node firebase_notification_tester.js");
  } catch (error) {
    console.error("❌ Error fixing FCM assignment:", error);
  }

  process.exit(0);
}

fixFCMAssignment();
