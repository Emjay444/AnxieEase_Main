// MANUAL WEBHOOK TRIGGER - FIX MISSING USER ID
// This simulates the Supabase webhook to properly sync user assignments

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

async function fixDeviceAssignment() {
  console.log("🔧 FIXING DEVICE ASSIGNMENT - MANUAL WEBHOOK TRIGGER");
  console.log("===================================================\n");

  try {
    // Data from your Supabase screenshots
    const deviceId = "AnxieEase001";
    const userId = "5efad7d4-3dd1-4355-badb-4f68bc0ab4df"; // Your full user ID from Supabase
    const baselineHR = 73.2; // From your Supabase assignment

    console.log("📋 ASSIGNMENT DATA TO SYNC:");
    console.log("============================");
    console.log(`Device ID: ${deviceId}`);
    console.log(`User ID: ${userId}`);
    console.log(`Baseline HR: ${baselineHR} BPM`);

    // Step 1: Update Firebase assignment (what webhook should do)
    console.log("\n🔄 STEP 1: Updating Firebase assignment...");

    const newSessionId = `session_${Date.now()}`;
    const newAssignment = {
      assignedUser: userId,
      activeSessionId: newSessionId,
      deviceId: deviceId,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      assignedBy: "manual_webhook_fix",
      supabaseSync: {
        syncedAt: admin.database.ServerValue.TIMESTAMP,
        baselineHR: baselineHR,
        webhookTrigger: true,
        manualFix: true,
      },
    };

    await db.ref(`/devices/${deviceId}/assignment`).set(newAssignment);
    console.log("✅ Assignment path updated");

    // Step 2: CRITICAL - Update device metadata for anxiety detection
    console.log("\n🔄 STEP 2: Updating device metadata for notifications...");

    await db.ref(`/devices/${deviceId}/metadata`).update({
      userId: userId,
      assignedUser: userId,
      deviceId: deviceId,
      lastSync: admin.database.ServerValue.TIMESTAMP,
      source: "manual_webhook_fix",
      notificationReady: true,
    });
    console.log("✅ Metadata path updated - ANXIETY DETECTION READY");

    // Step 3: Set user baseline
    console.log("\n🔄 STEP 3: Setting user baseline...");

    await db.ref(`/users/${userId}/baseline`).set({
      heartRate: baselineHR,
      timestamp: Date.now(),
      source: "manual_webhook_fix",
      deviceId: deviceId,
    });
    console.log("✅ User baseline set");

    // Step 4: Initialize user session
    console.log("\n🔄 STEP 4: Initializing user session...");

    await db.ref(`/users/${userId}/sessions/${newSessionId}/metadata`).set({
      deviceId: deviceId,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      source: "manual_webhook_fix",
      baselineHR: baselineHR,
    });
    console.log("✅ User session initialized");

    // Step 5: Verify the fix
    console.log("\n🔍 STEP 5: Verifying the fix...");

    // Check if anxiety detection can find the user
    const metadataRef = db.ref(`devices/${deviceId}/metadata`);
    const metadataSnapshot = await metadataRef.once("value");

    if (metadataSnapshot.exists()) {
      const metadata = metadataSnapshot.val();
      console.log("✅ Device metadata found:");
      console.log(`   userId: ${metadata.userId}`);
      console.log(`   assignedUser: ${metadata.assignedUser}`);
      console.log(`   notificationReady: ${metadata.notificationReady}`);
    }

    // Check assignment
    const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
    const assignmentSnapshot = await assignmentRef.once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log("✅ Device assignment found:");
      console.log(`   assignedUser: ${assignment.assignedUser}`);
      console.log(`   status: ${assignment.status}`);
      console.log(`   sessionId: ${assignment.activeSessionId}`);
    }

    console.log("\n🎉 SUCCESS: Device assignment fixed!");
    console.log("=====================================");
    console.log("✅ Device AnxieEase001 is now properly assigned to user");
    console.log("✅ Anxiety detection functions can now find the userId");
    console.log("✅ Notifications should now work!");

    console.log("\n📱 NEXT STEPS:");
    console.log("===============");
    console.log("1. Deploy the updated Firebase Functions");
    console.log("2. Test anxiety detection with elevated heart rate");
    console.log("3. Check if notifications appear in your Flutter app");
    console.log("4. Verify webhook sync works for future changes");

    console.log("\n🔔 TO TEST NOTIFICATIONS:");
    console.log("===========================");
    console.log("• Increase your heart rate to 89+ BPM while sitting still");
    console.log('• You should get: "Are you feeling anxious?" notification');
    console.log("• Notification should appear in both system tray and app");
  } catch (error) {
    console.error("❌ Error fixing device assignment:", error.message);
  }
}

fixDeviceAssignment();
