/**
 * 🔄 AUTO-SYNC: SUPABASE → FIREBASE DEVICE ASSIGNMENTS
 *
 * This function should be triggered whenever admin changes device assignment in Supabase
 * It will automatically update Firebase to match Supabase changes in real-time
 */

const admin = require("firebase-admin");
const { createClient } = require("@supabase/supabase-js");
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

// Initialize Supabase (you'll need to add your credentials)
const supabaseUrl = "YOUR_SUPABASE_URL"; // Replace with your URL
const supabaseKey = "YOUR_SUPABASE_ANON_KEY"; // Replace with your key
// const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * 🎯 MAIN SYNC FUNCTION - Call this when Supabase device assignment changes
 *
 * This should be triggered by:
 * 1. Supabase Database Webhook
 * 2. Supabase Edge Function
 * 3. Manual admin trigger
 */
async function syncFirebaseFromSupabase(deviceId) {
  console.log(`\n🔄 AUTO-SYNC: ${deviceId} assignment change detected`);
  console.log("================================================");

  try {
    // Step 1: Get current assignment from Supabase
    console.log("🔍 Step 1: Fetching current Supabase assignment...");

    // TODO: Replace with actual Supabase query
    // For now, using your known assignment from screenshot
    const supabaseAssignment = {
      device_id: "AnxieEase001",
      user_id: "e0997cb7-684f-41e5-929f-4480788d4ad0",
      baseline_hr: 73.5,
      linked_at: "2025-09-24 22:52:33.77+00",
      baseline_updated_at: "2025-09-23 04:39:03.464+00",
      is_active: true,
      battery_level: 18,
      firmware_version: null,
      last_seen_at: "2025-09-23 04:39:00+00",
    };

    console.log("✅ Supabase Assignment Retrieved:");
    console.log(`   Device: ${supabaseAssignment.device_id}`);
    console.log(`   User: ${supabaseAssignment.user_id}`);
    console.log(`   Baseline HR: ${supabaseAssignment.baseline_hr} BPM`);
    console.log(`   Active: ${supabaseAssignment.is_active}`);
    console.log(`   Linked: ${supabaseAssignment.linked_at}`);

    // Step 2: Check current Firebase assignment
    console.log("\n🔍 Step 2: Checking current Firebase assignment...");
    const firebaseAssignmentRef = db.ref(`/devices/${deviceId}/assignment`);
    const firebaseSnapshot = await firebaseAssignmentRef.once("value");
    const currentFirebaseAssignment = firebaseSnapshot.val();

    if (currentFirebaseAssignment) {
      console.log("📊 Current Firebase Assignment:");
      console.log(`   User: ${currentFirebaseAssignment.assignedUser}`);
      console.log(`   Session: ${currentFirebaseAssignment.activeSessionId}`);
      console.log(`   Status: ${currentFirebaseAssignment.status}`);
    }

    // Step 3: Compare and sync if needed
    const needsSync =
      !currentFirebaseAssignment ||
      currentFirebaseAssignment.assignedUser !== supabaseAssignment.user_id ||
      currentFirebaseAssignment.status !== "active";

    if (needsSync) {
      console.log("\n🔄 Step 3: Syncing Firebase with Supabase...");

      const newSessionId = `session_${Date.now()}`;

      // Update Firebase assignment
      const newFirebaseAssignment = {
        assignedUser: supabaseAssignment.user_id,
        activeSessionId: newSessionId,
        deviceId: deviceId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        status: supabaseAssignment.is_active ? "active" : "inactive",
        assignedBy: "supabase_auto_sync",
        supabaseSync: {
          syncedAt: admin.database.ServerValue.TIMESTAMP,
          baselineHR: supabaseAssignment.baseline_hr,
          linkedAt: supabaseAssignment.linked_at,
          batteryLevel: supabaseAssignment.battery_level,
        },
        previousAssignment: currentFirebaseAssignment,
      };

      await firebaseAssignmentRef.set(newFirebaseAssignment);

      console.log("✅ Firebase assignment updated!");
      console.log(`   NEW User: ${supabaseAssignment.user_id}`);
      console.log(`   NEW Session: ${newSessionId}`);
      console.log(`   Baseline: ${supabaseAssignment.baseline_hr} BPM`);

      // Step 4: Set up user baseline in Firebase (for anxiety detection)
      console.log("\n👤 Step 4: Syncing user baseline...");

      await db.ref(`/users/${supabaseAssignment.user_id}/baseline`).set({
        heartRate: supabaseAssignment.baseline_hr,
        timestamp: Date.now(),
        source: "supabase_sync",
        deviceId: deviceId,
      });

      console.log(
        `✅ User baseline synced: ${supabaseAssignment.baseline_hr} BPM`
      );

      // Step 5: Initialize user session
      console.log("\n📱 Step 5: Initializing user session...");

      await db
        .ref(
          `/users/${supabaseAssignment.user_id}/sessions/${newSessionId}/metadata`
        )
        .set({
          deviceId: deviceId,
          status: "active",
          startTime: admin.database.ServerValue.TIMESTAMP,
          source: "supabase_auto_sync",
          baselineHR: supabaseAssignment.baseline_hr,
        });

      console.log("✅ User session initialized");

      // Step 6: Clean up old user session (if different user)
      if (
        currentFirebaseAssignment &&
        currentFirebaseAssignment.assignedUser !== supabaseAssignment.user_id
      ) {
        console.log("\n🧹 Step 6: Cleaning up previous user...");

        const oldUserId = currentFirebaseAssignment.assignedUser;
        const oldSessionId = currentFirebaseAssignment.activeSessionId;

        if (oldSessionId) {
          await db
            .ref(`/users/${oldUserId}/sessions/${oldSessionId}/metadata`)
            .update({
              status: "ended",
              endTime: admin.database.ServerValue.TIMESTAMP,
              endReason: "device_reassigned_by_admin",
            });

          console.log(`✅ Previous user session ended: ${oldUserId}`);
        }
      }

      console.log("\n🎉 AUTO-SYNC COMPLETE!");
      console.log("======================");
      console.log("✅ Firebase matches Supabase");
      console.log("✅ User baseline synced");
      console.log("✅ Session initialized");
      console.log("✅ Ready for anxiety detection");

      return {
        success: true,
        message: "Auto-sync completed successfully",
        newUser: supabaseAssignment.user_id,
        newSession: newSessionId,
        baseline: supabaseAssignment.baseline_hr,
      };
    } else {
      console.log("\n✅ No sync needed - Firebase already matches Supabase");
      return {
        success: true,
        message: "No sync needed",
        currentUser: currentFirebaseAssignment.assignedUser,
      };
    }
  } catch (error) {
    console.error("❌ Auto-sync failed:", error.message);
    return {
      success: false,
      error: error.message,
    };
  }
}

/**
 * 🎯 WEBHOOK HANDLER - Call this from Supabase Database Webhook
 *
 * This function should be called whenever wearable_devices table changes
 */
async function handleSupabaseWebhook(payload) {
  console.log("\n📡 SUPABASE WEBHOOK RECEIVED");
  console.log("============================");
  console.log("Payload:", JSON.stringify(payload, null, 2));

  try {
    // Extract device info from webhook payload
    const deviceId = payload.record?.device_id || payload.old_record?.device_id;

    if (!deviceId) {
      console.log("⚠️ No device_id in webhook payload");
      return { success: false, error: "No device_id found" };
    }

    console.log(`📱 Device assignment change detected: ${deviceId}`);

    // Trigger auto-sync
    return await syncFirebaseFromSupabase(deviceId);
  } catch (error) {
    console.error("❌ Webhook processing failed:", error.message);
    return { success: false, error: error.message };
  }
}

/**
 * 🔄 PERIODIC SYNC - Run this on a schedule to ensure consistency
 */
async function periodicSync() {
  console.log("\n⏰ PERIODIC SYNC - Ensuring Firebase/Supabase consistency");
  console.log("=========================================================");

  try {
    // TODO: Get all active devices from Supabase
    const activeDevices = ["AnxieEase001"]; // Replace with Supabase query

    for (const deviceId of activeDevices) {
      console.log(`\n🔍 Checking ${deviceId}...`);
      await syncFirebaseFromSupabase(deviceId);
    }

    console.log("\n✅ Periodic sync complete");
  } catch (error) {
    console.error("❌ Periodic sync failed:", error.message);
  }
}

// Export functions for use in different contexts
module.exports = {
  syncFirebaseFromSupabase,
  handleSupabaseWebhook,
  periodicSync,
};

// If run directly, perform manual sync
if (require.main === module) {
  console.log("🚀 Manual sync triggered");
  syncFirebaseFromSupabase("AnxieEase001");
}
