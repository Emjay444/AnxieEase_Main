/**
 * 🔄 SYNC FIREBASE WITH SUPABASE DEVICE ASSIGNMENT
 *
 * This will update Firebase assignment to match your Supabase admin changes
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

async function syncDeviceAssignmentFromSupabase() {
  console.log("\n🔄 SYNCING FIREBASE WITH SUPABASE ASSIGNMENT");
  console.log("=============================================");

  try {
    // From your Supabase screenshot:
    const DEVICE_ID = "AnxieEase001";
    const NEW_USER_ID = "e0997cb7-684f-41e5-929f-4480788d4ad0"; // From your Supabase
    const NEW_SESSION_ID = `session_${Date.now()}`;

    console.log("📊 Current Supabase Assignment (from your screenshot):");
    console.log(`   Device: ${DEVICE_ID}`);
    console.log(`   User ID: ${NEW_USER_ID}`);
    console.log(`   Status: Active`);

    // Step 1: Check current Firebase assignment
    console.log("\n🔍 Step 1: Checking current Firebase assignment...");
    const currentAssignmentSnapshot = await db
      .ref(`/devices/${DEVICE_ID}/assignment`)
      .once("value");
    const currentAssignment = currentAssignmentSnapshot.val();

    if (currentAssignment) {
      console.log("❗ Current Firebase Assignment (OUTDATED):");
      console.log(`   Assigned User: ${currentAssignment.assignedUser}`);
      console.log(`   Session ID: ${currentAssignment.activeSessionId}`);
      console.log(`   Status: ${currentAssignment.status}`);
      console.log(
        `   Assigned At: ${new Date(
          currentAssignment.assignedAt
        ).toLocaleString()}`
      );
    } else {
      console.log("⚠️ No current assignment found in Firebase");
    }

    // Step 2: Update Firebase to match Supabase
    console.log("\n📝 Step 2: Updating Firebase to match Supabase...");

    const newAssignment = {
      assignedUser: NEW_USER_ID,
      activeSessionId: NEW_SESSION_ID,
      deviceId: DEVICE_ID,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      assignedBy: "supabase_admin_sync",
      syncedFromSupabase: true,
      previousUser: currentAssignment ? currentAssignment.assignedUser : null,
    };

    await db.ref(`/devices/${DEVICE_ID}/assignment`).set(newAssignment);

    console.log("✅ Firebase assignment updated!");
    console.log(`   NEW Assigned User: ${NEW_USER_ID}`);
    console.log(`   NEW Session ID: ${NEW_SESSION_ID}`);
    console.log(`   Status: active`);
    console.log(`   Synced from: Supabase admin panel`);

    // Step 3: Clear old user's active session (if any)
    if (currentAssignment && currentAssignment.assignedUser !== NEW_USER_ID) {
      console.log(`\n🧹 Step 3: Cleaning up old user's session...`);

      const oldUserId = currentAssignment.assignedUser;
      const oldSessionId = currentAssignment.activeSessionId;

      // Mark old session as ended
      if (oldSessionId) {
        await db
          .ref(`/users/${oldUserId}/sessions/${oldSessionId}/metadata`)
          .update({
            status: "ended",
            endTime: admin.database.ServerValue.TIMESTAMP,
            endReason: "device_reassigned",
          });

        console.log(`✅ Old user's session ended: ${oldUserId}`);
      }
    }

    // Step 4: Set up new user's session
    console.log(`\n👤 Step 4: Setting up new user's session...`);

    await db
      .ref(`/users/${NEW_USER_ID}/sessions/${NEW_SESSION_ID}/metadata`)
      .set({
        deviceId: DEVICE_ID,
        status: "active",
        startTime: admin.database.ServerValue.TIMESTAMP,
        assignmentSource: "supabase_admin",
      });

    console.log(`✅ New user's session initialized: ${NEW_USER_ID}`);

    // Step 5: Verify the sync
    console.log("\n🔍 Step 5: Verifying sync...");

    const verifySnapshot = await db
      .ref(`/devices/${DEVICE_ID}/assignment`)
      .once("value");
    const verifiedAssignment = verifySnapshot.val();

    console.log("\n📊 SYNC VERIFICATION:");
    console.log("====================");
    console.log(`Firebase User:   ${verifiedAssignment.assignedUser}`);
    console.log(`Supabase User:   ${NEW_USER_ID}`);
    console.log(
      `Match: ${
        verifiedAssignment.assignedUser === NEW_USER_ID ? "✅ YES" : "❌ NO"
      }`
    );

    if (verifiedAssignment.assignedUser === NEW_USER_ID) {
      console.log("\n🎉 SUCCESS: Firebase and Supabase are now in sync!");
      console.log("✅ Device assignment updated");
      console.log("✅ Old user session ended");
      console.log("✅ New user session started");
      console.log("✅ Ready for anxiety detection with new user");
    } else {
      console.log("\n❌ SYNC FAILED: Assignments still don't match");
    }

    console.log("\n📱 NEXT STEPS:");
    console.log("==============");
    console.log("1. New user can now use the device");
    console.log("2. Only new user will receive anxiety alerts");
    console.log("3. Old user will no longer get notifications");
    console.log("4. Test anxiety detection with new user");
  } catch (error) {
    console.error("❌ Sync failed:", error.message);
  }
}

syncDeviceAssignmentFromSupabase();
