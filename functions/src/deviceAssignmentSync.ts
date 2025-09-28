/**
 * 🔄 FIREBASE FUNCTION: AUTO-SYNC DEVICE ASSIGNMENTS
 *
 * This Firebase Function receives webhooks from Supabase when device assignments change
 * and automatically updates Firebase Realtime Database to match
 *
 * Deploy with: npx firebase deploy --only functions:syncDeviceAssignment
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.database();

/**
 * 📡 HTTP Function to receive Supabase webhooks
 *
 * Supabase webhook URL: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/syncDeviceAssignment
 */
export const syncDeviceAssignment = functions.https.onRequest(
  async (req, res) => {
    // Enable CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    console.log("📡 Supabase webhook received for device assignment sync");
    console.log("Request body:", JSON.stringify(req.body, null, 2));

    try {
      const payload = req.body;

      // Validate webhook payload
      if (!payload || !payload.record) {
        console.log("⚠️ Invalid webhook payload");
        res.status(400).json({ error: "Invalid payload" });
        return;
      }

      const record = payload.record;
      const deviceId = record.device_id;
      const userId = record.user_id;
      const baselineHR = record.baseline_hr;
      const isActive = record.is_active;

      if (!deviceId) {
        console.log("⚠️ No device_id in webhook payload");
        res.status(400).json({ error: "Missing device_id" });
        return;
      }

      console.log(`🔄 Processing device assignment change:`);
      console.log(`   Device: ${deviceId}`);
      console.log(`   User: ${userId}`);
      console.log(`   Baseline: ${baselineHR} BPM`);
      console.log(`   Active: ${isActive}`);

      // Step 1: Get current Firebase assignment
      const currentAssignmentRef = db.ref(`/devices/${deviceId}/assignment`);
      const currentSnapshot = await currentAssignmentRef.once("value");
      const currentAssignment = currentSnapshot.val();

      // Step 2: Check if sync is needed
      const needsSync =
        !currentAssignment ||
        currentAssignment.assignedUser !== userId ||
        Math.abs(currentAssignment.supabaseSync?.baselineHR - baselineHR) > 0.1;

      if (!needsSync) {
        console.log("✅ Firebase already in sync with Supabase");
        res.status(200).json({
          success: true,
          message: "Already in sync",
          currentUser: currentAssignment.assignedUser,
        });
        return;
      }

      console.log("🔄 Syncing Firebase with Supabase changes...");

      // Step 3: Update Firebase assignment
      const newSessionId = `session_${Date.now()}`;
      const newAssignment = {
        assignedUser: userId,
        activeSessionId: newSessionId,
        deviceId: deviceId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        status: isActive ? "active" : "inactive",
        assignedBy: "supabase_webhook_sync",
        supabaseSync: {
          syncedAt: admin.database.ServerValue.TIMESTAMP,
          baselineHR: baselineHR,
          webhookTrigger: true,
          originalPayload: payload.type || "unknown",
        },
        previousAssignment:
          currentAssignment && currentAssignment.assignedUser
            ? {
                assignedUser: currentAssignment.assignedUser,
                activeSessionId: currentAssignment.activeSessionId || null,
                assignedBy: currentAssignment.assignedBy || "unknown",
                assignedAt: currentAssignment.assignedAt || null,
                status: currentAssignment.status || "unknown",
                deviceId: currentAssignment.deviceId || deviceId,
                // Intentionally exclude previousAssignment to prevent infinite nesting
              }
            : null,
      };

      await currentAssignmentRef.set(newAssignment);
      console.log(`✅ Firebase assignment updated for ${deviceId}`);

      // Step 3b: ALSO update device metadata for anxiety detection functions
      await db.ref(`/devices/${deviceId}/metadata`).update({
        userId: userId,
        assignedUser: userId,
        deviceId: deviceId,
        lastSync: admin.database.ServerValue.TIMESTAMP,
        source: "supabase_webhook_sync",
      });
      console.log(`✅ Device metadata updated for anxiety detection`);

      // Step 4: Update user baseline
      if (userId && baselineHR) {
        await db.ref(`/users/${userId}/baseline`).set({
          heartRate: baselineHR,
          timestamp: Date.now(),
          source: "supabase_webhook_sync",
          deviceId: deviceId,
        });
        console.log(`✅ User baseline updated: ${baselineHR} BPM`);
      }

      // Step 5: Initialize new user session
      if (userId && isActive) {
        await db.ref(`/users/${userId}/sessions/${newSessionId}/metadata`).set({
          deviceId: deviceId,
          status: "active",
          startTime: admin.database.ServerValue.TIMESTAMP,
          source: "supabase_webhook_sync",
          baselineHR: baselineHR,
        });
        console.log(`✅ User session initialized: ${newSessionId}`);
      }

      // Step 6: Clean up old user session
      if (
        currentAssignment &&
        currentAssignment.assignedUser &&
        currentAssignment.assignedUser !== userId
      ) {
        const oldUserId = currentAssignment.assignedUser;
        const oldSessionId = currentAssignment.activeSessionId;

        if (oldSessionId) {
          await db
            .ref(`/users/${oldUserId}/sessions/${oldSessionId}/metadata`)
            .update({
              status: "ended",
              endTime: admin.database.ServerValue.TIMESTAMP,
              endReason: "device_reassigned_by_admin_webhook",
            });
          console.log(`✅ Old user session ended: ${oldUserId}`);
        }
      }

      console.log("🎉 Webhook sync completed successfully");

      res.status(200).json({
        success: true,
        message: "Device assignment synced successfully",
        deviceId: deviceId,
        newUser: userId,
        newSession: newSessionId,
        baseline: baselineHR,
        syncedAt: new Date().toISOString(),
      });
    } catch (error) {
      console.error("❌ Webhook sync failed:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * 🔄 SCHEDULED FUNCTION: Periodic sync to ensure consistency
 *
 * Runs every 5 minutes to check for any missed webhook updates
 */
export const periodicDeviceSync = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
    console.log("⏰ Running periodic device assignment sync");

    try {
      // TODO: This would query Supabase to get all active device assignments
      // For now, we'll just log that periodic sync ran

      console.log(
        "⏰ Periodic sync completed (placeholder - implement Supabase query)"
      );

      return null;
    } catch (error) {
      console.error("❌ Periodic sync failed:", error);
      return null;
    }
  });

/**
 * 🧪 TEST FUNCTION: Manual sync trigger for testing
 */
export const testDeviceSync = functions.https.onRequest(async (req, res) => {
  console.log("🧪 Manual device sync test triggered");

  try {
    // Simulate a Supabase webhook payload
    const testPayload = {
      type: "INSERT",
      record: {
        device_id: "AnxieEase001",
        user_id: "e0997cb7-684f-41e5-929f-4480788d4ad0",
        baseline_hr: 73.5,
        is_active: true,
        linked_at: new Date().toISOString(),
      },
    };

    // Process the test payload (reuse the webhook logic)
    const deviceId = testPayload.record.device_id;
    const userId = testPayload.record.user_id;

    const newSessionId = `test_session_${Date.now()}`;

    await db.ref(`/devices/${deviceId}/assignment`).set({
      assignedUser: userId,
      activeSessionId: newSessionId,
      deviceId: deviceId,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      assignedBy: "manual_test_sync",
      testSync: true,
    });

    console.log("✅ Test sync completed");

    res.status(200).json({
      success: true,
      message: "Test sync completed",
      testPayload: testPayload,
      result: {
        deviceId: deviceId,
        userId: userId,
        sessionId: newSessionId,
      },
    });
  } catch (error) {
    console.error("❌ Test sync failed:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});
