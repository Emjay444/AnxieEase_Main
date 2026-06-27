"use strict";
var _a, _b;
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupOldSessions = exports.getDeviceAssignment = exports.assignDeviceToUser = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.database();
// Server-side-only Supabase credentials, used to verify admin status.
// Never sourced from client-provided data.
const SUPABASE_URL = process.env.SUPABASE_URL || ((_a = functions.config().supabase) === null || _a === void 0 ? void 0 : _a.url);
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ||
    ((_b = functions.config().supabase) === null || _b === void 0 ? void 0 : _b.service_role_key);
let fetchImpl = null;
try {
    fetchImpl = global.fetch || require("node-fetch");
}
catch (_c) { }
/**
 * Verifies the caller is a real, currently-valid Supabase user with
 * role = 'admin' in public.user_profiles. The caller's Firebase Auth
 * context (context.auth) has no relationship to Supabase identities in
 * this app (the mobile/web clients authenticate via Supabase, not
 * Firebase Auth), so admin status can only be established by validating
 * a genuine Supabase access token server-side -- never by trusting any
 * role the client claims to have.
 */
async function verifySupabaseAdmin(accessToken) {
    var _a;
    if (typeof accessToken !== "string" ||
        !accessToken ||
        !SUPABASE_URL ||
        !SUPABASE_SERVICE_ROLE_KEY ||
        !fetchImpl) {
        return false;
    }
    try {
        // Resolve the token to a real Supabase user; this validates the
        // token's signature/expiry against Supabase Auth itself.
        const userResp = await fetchImpl(`${SUPABASE_URL}/auth/v1/user`, {
            headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${accessToken}`,
            },
        });
        if (!userResp.ok)
            return false;
        const userData = await userResp.json();
        const uid = userData === null || userData === void 0 ? void 0 : userData.id;
        if (!uid || typeof uid !== "string")
            return false;
        // Look up the role server-side with the service-role key (bypasses
        // RLS by design -- this is the one trusted, server-only check).
        const roleResp = await fetchImpl(`${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${uid}&select=role`, {
            headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            },
        });
        if (!roleResp.ok)
            return false;
        const rows = await roleResp.json();
        const isAdmin = Array.isArray(rows) && ((_a = rows[0]) === null || _a === void 0 ? void 0 : _a.role) === "admin";
        if (isAdmin) {
            console.log(`✅ Verified admin request from Supabase user ${uid}`);
        }
        return isAdmin;
    }
    catch (error) {
        console.error("❌ Admin verification failed:", error instanceof Error ? error.message : String(error));
        return false;
    }
}
/**
 * Interface for sensor data from the wearable device
 * COMMENTED OUT - Only used by disabled functions
 */
/*
interface SensorData {
  heartRate: number;
  spo2: number;
  bodyTemp: number;
  ambientTemp: number;
  battPerc: number;
  worn: number;
  timestamp: number;
  accelX?: number;
  accelY?: number;
  accelZ?: number;
  gyroX?: number;
  gyroY?: number;
  gyroZ?: number;
  pitch?: number;
  roll?: number;
}
*/
/**
 * DISABLED: This function creates timestamp duplicates in user sessions
 * REPLACED BY: smartDeviceDataSync which prevents duplicates
 *
 * Cloud Function: Copy device history data to user sessions
 *
 * Triggers when new data is written to /devices/AnxieEase001/history/{timestamp}
 * Automatically copies the data to the assigned user's session history
 */
/*
// DISABLED - Creates timestamp duplicates
export const copyDeviceDataToUserSession = functions.database
  .ref("/devices/AnxieEase001/history/{timestamp}")
  .onCreate(async (snapshot, context) => {
    const timestamp = context.params.timestamp;
    const sensorData = snapshot.val() as SensorData;

    console.log(`📊 New device data received at timestamp: ${timestamp}`);

    try {
      // Get device assignment information
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      const assignmentSnapshot = await assignmentRef.once("value");

      if (!assignmentSnapshot.exists()) {
        console.log(
          "⚠️ No device assignment found - data will only stay in device history"
        );
        return null;
      }

      const rawAssignment = assignmentSnapshot.val() as any;
      const assignedUser = rawAssignment?.assignedUser || rawAssignment?.userId;
      const activeSessionId =
        rawAssignment?.activeSessionId || rawAssignment?.sessionId;

      if (!assignedUser || !activeSessionId) {
        console.log(
          "⚠️ Device not assigned to any user or no active session - skipping copy"
        );
        return null;
      }

      console.log(`👤 Device assigned to user: ${assignedUser}`);
      console.log(`📋 Active session: ${activeSessionId}`);

      // Validate sensor data
      if (!sensorData || typeof sensorData !== "object") {
        console.error("❌ Invalid sensor data received:", sensorData);
        return null;
      }

      // Copy data to user's session history
      const userSessionHistoryRef = db.ref(
        `/users/${assignedUser}/sessions/${activeSessionId}/history/${timestamp}`
      );

      // Add metadata about the copy operation
      const enrichedData = {
        ...sensorData,
        deviceId: "AnxieEase001",
        copiedAt: admin.database.ServerValue.TIMESTAMP,
        sessionId: activeSessionId,
        userId: assignedUser,
      };

      await userSessionHistoryRef.set(enrichedData);

      console.log(`✅ Data successfully copied to user session`);
      console.log(
        `📍 Location: /users/${assignedUser}/sessions/${activeSessionId}/history/${timestamp}`
      );

      // Update session metadata with latest activity
      const sessionMetadataRef = db.ref(
        `/users/${assignedUser}/sessions/${activeSessionId}/metadata`
      );

      await sessionMetadataRef.update({
        lastActivity: admin.database.ServerValue.TIMESTAMP,
        lastDataTimestamp: parseInt(timestamp),
        totalDataPoints: admin.database.ServerValue.increment(1),
      });

      return {
        success: true,
        userId: assignedUser,
        sessionId: activeSessionId,
      };
    } catch (error) {
      console.error("❌ Error copying device data to user session:", error);

      // Log error details for debugging
      await db.ref("/system/errors").push({
        type: "device_data_copy_error",
        timestamp: admin.database.ServerValue.TIMESTAMP,
        deviceTimestamp: timestamp,
        error: error instanceof Error ? error.message : String(error),
        data: sensorData,
      });

      throw error;
    }
  });
*/
/**
 * DISABLED: This function also creates timestamp duplicates
 * REPLACED BY: smartDeviceDataSync and realTimeSustainedAnxietyDetection
 *
 * Cloud Function: Copy device current data to user session (real-time)
 *
 * Triggers when current data is updated on the device
 * Copies to user's current session for real-time monitoring
 */
/*
// DISABLED - Creates timestamp duplicates
export const copyDeviceCurrentToUserSession = functions.database
  .ref("/devices/AnxieEase001/current")
  .onWrite(async (change, context) => {
    // Only process if data was created or updated (not deleted)
    if (!change.after.exists()) {
      console.log("📱 Device current data deleted - no action needed");
      return null;
    }

    const currentData = change.after.val() as SensorData;
    console.log(`📊 Device current data updated`);

    try {
      // Get device assignment information
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      const assignmentSnapshot = await assignmentRef.once("value");

      if (!assignmentSnapshot.exists()) {
        console.log(
          "⚠️ No device assignment found - current data stays in device only"
        );
        return null;
      }

      const rawAssignment = assignmentSnapshot.val() as any;
      const assignedUser = rawAssignment?.assignedUser || rawAssignment?.userId;
      const activeSessionId =
        rawAssignment?.activeSessionId || rawAssignment?.sessionId;

      if (!assignedUser || !activeSessionId) {
        console.log(
          "⚠️ Device not assigned or no active session - skipping current data copy"
        );
        return null;
      }

      // Copy current data to user's session (current)
      const userSessionCurrentRef = db.ref(
        `/users/${assignedUser}/sessions/${activeSessionId}/current`
      );

      const enrichedCurrentData = {
        ...currentData,
        deviceId: "AnxieEase001",
        lastUpdated: admin.database.ServerValue.TIMESTAMP,
        sessionId: activeSessionId,
        userId: assignedUser,
      };

      await userSessionCurrentRef.set(enrichedCurrentData);

      console.log(
        `✅ Current data copied to user session: ${assignedUser}/${activeSessionId}`
      );

      // Also append to user's session history to build sustained analysis window
      try {
        let ts = currentData.timestamp || Date.now();

        // Convert string timestamp to numeric if needed
        if (typeof ts === "string") {
          // Convert "2025-09-26 21:40:23" format to milliseconds
          ts = new Date(ts).getTime();
          console.log(`🔄 Converted string timestamp to numeric: ${ts}`);
        }

        const userSessionHistoryRef = db.ref(
          `/users/${assignedUser}/sessions/${activeSessionId}/history/${ts}`
        );
        const enrichedHistoryData = {
          ...currentData,
          deviceId: "AnxieEase001",
          timestamp: ts, // Use numeric timestamp
          copiedAt: admin.database.ServerValue.TIMESTAMP,
          sessionId: activeSessionId,
          userId: assignedUser,
        };
        await userSessionHistoryRef.set(enrichedHistoryData);
        console.log(`📝 Appended current data to history at ${ts}`);
      } catch (err) {
        console.warn("⚠️ Failed to append current to history:", err);
      }

      return {
        success: true,
        userId: assignedUser,
        sessionId: activeSessionId,
      };
    } catch (error) {
      console.error("❌ Error copying current data to user session:", error);
      throw error;
    }
  });
*/
/**
 * Cloud Function: Manage device assignment
 *
 * HTTP function to assign/unassign device to users
 * Called by admin interface or testing system
 */
exports.assignDeviceToUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to assign devices");
    }
    // The caller must prove admin status via a real Supabase session
    // (verified server-side above); a client-asserted role is never
    // trusted, since this app's admin role lives in Supabase, not in the
    // Firebase Auth context.
    const isAdmin = await verifySupabaseAdmin(data === null || data === void 0 ? void 0 : data.supabaseAccessToken);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin privileges required to assign or unassign devices");
    }
    const { userId, sessionId, action, adminNotes } = data;
    try {
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        if (action === "assign") {
            if (!userId || !sessionId) {
                throw new functions.https.HttpsError("invalid-argument", "userId and sessionId are required for assignment");
            }
            const assignmentData = {
                assignedUser: userId,
                activeSessionId: sessionId,
                assignedAt: Date.now(),
                assignedBy: context.auth.uid,
            };
            await assignmentRef.set(assignmentData);
            // Initialize user session
            const sessionRef = db.ref(`/users/${userId}/sessions/${sessionId}`);
            await sessionRef.update({
                metadata: {
                    deviceId: "AnxieEase001",
                    startTime: admin.database.ServerValue.TIMESTAMP,
                    assignedBy: context.auth.uid,
                    status: "active",
                    adminNotes: adminNotes || "",
                    totalDataPoints: 0,
                },
            });
            console.log(`✅ Device assigned to user ${userId}, session ${sessionId}`);
            return {
                success: true,
                message: "Device assigned successfully",
                userId,
                sessionId,
            };
        }
        else if (action === "unassign") {
            // End current session before unassigning
            const currentAssignment = await assignmentRef.once("value");
            if (currentAssignment.exists()) {
                const assignment = currentAssignment.val();
                // Mark session as completed
                if (assignment.assignedUser && assignment.activeSessionId) {
                    const sessionMetadataRef = db.ref(`/users/${assignment.assignedUser}/sessions/${assignment.activeSessionId}/metadata`);
                    await sessionMetadataRef.update({
                        endTime: admin.database.ServerValue.TIMESTAMP,
                        status: "completed",
                        unassignedBy: context.auth.uid,
                    });
                }
            }
            await assignmentRef.remove();
            console.log(`✅ Device unassigned`);
            return { success: true, message: "Device unassigned successfully" };
        }
        else {
            throw new functions.https.HttpsError("invalid-argument", 'Action must be "assign" or "unassign"');
        }
    }
    catch (error) {
        console.error("❌ Error managing device assignment:", error);
        throw new functions.https.HttpsError("internal", `Failed to ${action} device: ${error instanceof Error ? error.message : String(error)}`);
    }
});
/**
 * Cloud Function: Get device assignment status
 *
 * HTTP function to check current device assignment
 */
exports.getDeviceAssignment = functions.https.onCall(async (data, context) => {
    try {
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        const snapshot = await assignmentRef.once("value");
        if (!snapshot.exists()) {
            return {
                assigned: false,
                message: "Device is not assigned to any user",
            };
        }
        const assignment = snapshot.val();
        return {
            assigned: true,
            assignedUser: assignment.assignedUser,
            activeSessionId: assignment.activeSessionId,
            assignedAt: assignment.assignedAt,
            assignedBy: assignment.assignedBy,
        };
    }
    catch (error) {
        console.error("❌ Error getting device assignment:", error);
        throw new functions.https.HttpsError("internal", `Failed to get device assignment: ${error instanceof Error ? error.message : String(error)}`);
    }
});
/**
 * Cloud Function: Clean up old session data
 *
 * Scheduled function to clean up completed sessions older than 30 days
 */
exports.cleanupOldSessions = functions.pubsub
    .schedule("every 24 hours")
    .timeZone("UTC")
    .onRun(async (context) => {
    const cutoffTime = Date.now() - 30 * 24 * 60 * 60 * 1000; // 30 days ago
    try {
        const usersRef = db.ref("/users");
        const usersSnapshot = await usersRef.once("value");
        let cleanedSessions = 0;
        if (usersSnapshot.exists()) {
            const users = usersSnapshot.val();
            for (const userId in users) {
                const userSessions = users[userId].sessions;
                if (!userSessions)
                    continue;
                for (const sessionId in userSessions) {
                    const session = userSessions[sessionId];
                    const sessionMetadata = session.metadata;
                    // Clean up completed sessions older than cutoff
                    if ((sessionMetadata === null || sessionMetadata === void 0 ? void 0 : sessionMetadata.status) === "completed" &&
                        (sessionMetadata === null || sessionMetadata === void 0 ? void 0 : sessionMetadata.endTime) &&
                        sessionMetadata.endTime < cutoffTime) {
                        await db.ref(`/users/${userId}/sessions/${sessionId}`).remove();
                        cleanedSessions++;
                        console.log(`🗑️ Cleaned up old session: ${userId}/${sessionId}`);
                    }
                }
            }
        }
        console.log(`✅ Session cleanup completed. Removed ${cleanedSessions} old sessions.`);
        return { cleanedSessions };
    }
    catch (error) {
        console.error("❌ Error during session cleanup:", error);
        throw error;
    }
});
//# sourceMappingURL=deviceDataCopyService.js.map