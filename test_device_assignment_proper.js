// Device Assignment Test with Proper Firebase Credentials
const admin = require("firebase-admin");
const path = require("path");

// Initialize Firebase Admin with service account
const serviceAccount = require("./service-account-key.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

class DeviceAssignmentTester {
  async testAssignment() {
    console.log("🧪 Starting Device Assignment Test...\n");

    try {
      // Step 1: Check current assignment status
      console.log("📊 Step 1: Checking current assignment status...");
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      const assignmentSnapshot = await assignmentRef.once("value");
      const currentAssignment = assignmentSnapshot.val();

      console.log("Current assignment:", currentAssignment || "None");

      // Step 2: Clear any existing assignment first
      if (currentAssignment) {
        console.log("\n🧹 Clearing existing assignment...");
        await assignmentRef.remove();
        console.log("✅ Existing assignment cleared");
      }

      // Step 3: Create new assignment
      console.log("\n📱 Step 3: Creating new assignment...");
      const testUserId = "test_user_" + Date.now();
      const sessionId = "session_" + Date.now();

      const assignmentData = {
        assignedUser: testUserId,
        activeSessionId: sessionId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        assignedBy: "test_script",
        description: "Device assignment test",
        status: "active",
      };

      await assignmentRef.set(assignmentData);
      console.log("✅ Device assigned to:", testUserId);
      console.log("✅ Session ID:", sessionId);

      // Step 4: Create user session metadata
      console.log("\n📋 Step 4: Creating user session metadata...");
      const userSessionRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/metadata`
      );
      await userSessionRef.set({
        deviceId: "AnxieEase001",
        startTime: admin.database.ServerValue.TIMESTAMP,
        status: "active",
        description: "Test session for device assignment testing",
        totalDataPoints: 0,
      });
      console.log("✅ User session metadata created");

      // Step 5: Send test data to device current
      console.log("\n📤 Step 5: Sending test data...");
      const deviceCurrentRef = db.ref("/devices/AnxieEase001/current");
      const testData = {
        heartRate: 75,
        spo2: 98,
        bodyTemp: 98.6,
        worn: 1,
        timestamp: Date.now(),
        batteryLevel: 85,
      };

      await deviceCurrentRef.set(testData);
      console.log("✅ Test data sent:", testData);

      // Step 6: Wait and check if data was copied to user session
      console.log("\n⏳ Step 6: Waiting for Cloud Function to copy data...");
      await new Promise((resolve) => setTimeout(resolve, 5000)); // Wait 5 seconds

      const userCurrentRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/current`
      );
      const userCurrentSnapshot = await userCurrentRef.once("value");
      const userCurrentData = userCurrentSnapshot.val();

      if (userCurrentData) {
        console.log("✅ Data copied to user session:", userCurrentData);
        console.log(
          "✅ Cloud Function copyDeviceCurrentToUserSession is working!"
        );
      } else {
        console.log(
          "⚠️ Data not found in user session - Cloud Function might not be deployed"
        );
      }

      // Step 7: Send elevated heart rate for anxiety detection test
      console.log(
        "\n🚨 Step 7: Testing anxiety detection with elevated heart rate..."
      );
      const elevatedData = {
        heartRate: 95, // Above typical baseline of 70
        spo2: 97,
        bodyTemp: 98.8,
        worn: 1,
        timestamp: Date.now(),
        batteryLevel: 84,
      };

      await deviceCurrentRef.set(elevatedData);
      console.log("✅ Elevated heart rate data sent:", elevatedData);
      console.log(
        "📱 Watch for anxiety detection notification in your Cloud Function logs!"
      );

      // Step 8: Check if anxiety detection triggered (wait a bit)
      console.log("\n⏳ Step 8: Checking for anxiety detection results...");
      await new Promise((resolve) => setTimeout(resolve, 5000));

      const userAlertsRef = db.ref(`/users/${testUserId}/alerts`);
      const alertsSnapshot = await userAlertsRef.once("value");
      const alerts = alertsSnapshot.val();

      if (alerts) {
        console.log("🚨 Anxiety alerts found:", Object.keys(alerts).length);
        console.log(
          "✅ realTimeSustainedAnxietyDetection Cloud Function is working!"
        );
      } else {
        console.log(
          "⚠️ No anxiety alerts found - either threshold not met or sustained detection needs more time"
        );
      }

      // Step 9: Check Firebase structure
      console.log("\n📊 Step 9: Verifying Firebase structure...");

      // Check device history
      const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
      const historySnapshot = await deviceHistoryRef
        .limitToLast(1)
        .once("value");
      const historyData = historySnapshot.val();

      if (historyData) {
        console.log(
          "✅ Device history found:",
          Object.keys(historyData).length,
          "entries"
        );
      } else {
        console.log("⚠️ No device history found");
      }

      // Check user session data
      const userDataRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/data`
      );
      const userDataSnapshot = await userDataRef.limitToLast(1).once("value");
      const userData = userDataSnapshot.val();

      if (userData) {
        console.log(
          "✅ User session data found:",
          Object.keys(userData).length,
          "entries"
        );
      } else {
        console.log("⚠️ No user session data found");
      }

      // Step 10: Clean up (optional - comment out to keep data for inspection)
      console.log("\n🧹 Step 10: Cleaning up test data...");
      await assignmentRef.remove();
      await db.ref(`/users/${testUserId}`).remove();
      console.log("✅ Test data cleaned up");

      console.log("\n🎉 Device Assignment Test Completed Successfully!");
      console.log("\n📋 Test Results Summary:");
      console.log("✅ Device assignment: Working");
      console.log("✅ Test data sending: Working");
      console.log(
        userCurrentData ? "✅" : "⚠️",
        "Data copying to user session:",
        userCurrentData ? "Working" : "Check Cloud Functions"
      );
      console.log(
        alerts ? "✅" : "⚠️",
        "Anxiety detection:",
        alerts ? "Working" : "Needs more sustained data"
      );
    } catch (error) {
      console.error("\n❌ Test failed:", error.message);
      console.error("Error details:", error);
    }

    process.exit(0);
  }

  async quickStatusCheck() {
    console.log("🔍 Quick Device Status Check...\n");

    try {
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      const assignmentSnapshot = await assignmentRef.once("value");
      const assignment = assignmentSnapshot.val();

      console.log("Device Assignment:", assignment || "Not assigned");

      if (assignment) {
        console.log("📊 Assigned to user:", assignment.assignedUser);
        console.log("📊 Session ID:", assignment.activeSessionId);
        console.log("📊 Status:", assignment.status);
        console.log(
          "📊 Assigned at:",
          new Date(assignment.assignedAt).toLocaleString()
        );
      }

      const deviceCurrentRef = db.ref("/devices/AnxieEase001/current");
      const currentSnapshot = await deviceCurrentRef.once("value");
      const currentData = currentSnapshot.val();

      console.log("\nDevice Current Data:", currentData || "No data");
    } catch (error) {
      console.error("❌ Status check failed:", error.message);
    }

    process.exit(0);
  }
}

// Run based on command line argument
const tester = new DeviceAssignmentTester();

if (process.argv[2] === "status") {
  tester.quickStatusCheck();
} else {
  tester.testAssignment();
}
