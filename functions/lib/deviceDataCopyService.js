"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupOldSessions = exports.getDeviceAssignment = exports.assignDeviceToUser = exports.copyDeviceCurrentToUserSession = exports.copyDeviceDataToUserSession = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.database();
/**
 * Cloud Function: Copy device history data to user sessions
 *
 * Triggers when new data is written to /devices/AnxieEase001/history/{timestamp}
 * Automatically copies the data to the assigned user's session history
 */
exports.copyDeviceDataToUserSession = functions.database
    .ref("/devices/AnxieEase001/history/{timestamp}")
    .onCreate(async (snapshot, context) => {
    const timestamp = context.params.timestamp;
    const sensorData = snapshot.val();
    console.log(`📊 New device data received at timestamp: ${timestamp}`);
    try {
        // Get device assignment information
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        const assignmentSnapshot = await assignmentRef.once("value");
        if (!assignmentSnapshot.exists()) {
            console.log("⚠️ No device assignment found - data will only stay in device history");
            return null;
        }
        const assignment = assignmentSnapshot.val();
        if (!assignment.assignedUser || !assignment.activeSessionId) {
            console.log("⚠️ Device not assigned to any user or no active session - skipping copy");
            return null;
        }
        console.log(`👤 Device assigned to user: ${assignment.assignedUser}`);
        console.log(`📋 Active session: ${assignment.activeSessionId}`);
        // Validate sensor data
        if (!sensorData || typeof sensorData !== 'object') {
            console.error("❌ Invalid sensor data received:", sensorData);
            return null;
        }
        // Copy data to user's session history
        const userSessionHistoryRef = db.ref(`/users/${assignment.assignedUser}/sessions/${assignment.activeSessionId}/history/${timestamp}`);
        // Add metadata about the copy operation
        const enrichedData = Object.assign(Object.assign({}, sensorData), { deviceId: "AnxieEase001", copiedAt: admin.database.ServerValue.TIMESTAMP, sessionId: assignment.activeSessionId, userId: assignment.assignedUser });
        await userSessionHistoryRef.set(enrichedData);
        console.log(`✅ Data successfully copied to user session`);
        console.log(`📍 Location: /users/${assignment.assignedUser}/sessions/${assignment.activeSessionId}/history/${timestamp}`);
        // Update session metadata with latest activity
        const sessionMetadataRef = db.ref(`/users/${assignment.assignedUser}/sessions/${assignment.activeSessionId}/metadata`);
        await sessionMetadataRef.update({
            lastActivity: admin.database.ServerValue.TIMESTAMP,
            lastDataTimestamp: parseInt(timestamp),
            totalDataPoints: admin.database.ServerValue.increment(1)
        });
        return { success: true, userId: assignment.assignedUser, sessionId: assignment.activeSessionId };
    }
    catch (error) {
        console.error("❌ Error copying device data to user session:", error);
        // Log error details for debugging
        await db.ref("/system/errors").push({
            type: "device_data_copy_error",
            timestamp: admin.database.ServerValue.TIMESTAMP,
            deviceTimestamp: timestamp,
            error: error instanceof Error ? error.message : String(error),
            data: sensorData
        });
        throw error;
    }
});
/**
 * Cloud Function: Copy device current data to user session (real-time)
 *
 * Triggers when current data is updated on the device
 * Copies to user's current session for real-time monitoring
 */
exports.copyDeviceCurrentToUserSession = functions.database
    .ref("/devices/AnxieEase001/current")
    .onWrite(async (change, context) => {
    // Only process if data was created or updated (not deleted)
    if (!change.after.exists()) {
        console.log("📱 Device current data deleted - no action needed");
        return null;
    }
    const currentData = change.after.val();
    console.log(`📊 Device current data updated`);
    try {
        // Get device assignment information
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        const assignmentSnapshot = await assignmentRef.once("value");
        if (!assignmentSnapshot.exists()) {
            console.log("⚠️ No device assignment found - current data stays in device only");
            return null;
        }
        const assignment = assignmentSnapshot.val();
        if (!assignment.assignedUser || !assignment.activeSessionId) {
            console.log("⚠️ Device not assigned or no active session - skipping current data copy");
            return null;
        }
        // Copy current data to user's session
        const userSessionCurrentRef = db.ref(`/users/${assignment.assignedUser}/sessions/${assignment.activeSessionId}/current`);
        const enrichedCurrentData = Object.assign(Object.assign({}, currentData), { deviceId: "AnxieEase001", lastUpdated: admin.database.ServerValue.TIMESTAMP, sessionId: assignment.activeSessionId, userId: assignment.assignedUser });
        await userSessionCurrentRef.set(enrichedCurrentData);
        console.log(`✅ Current data copied to user session: ${assignment.assignedUser}/${assignment.activeSessionId}`);
        return { success: true, userId: assignment.assignedUser, sessionId: assignment.activeSessionId };
    }
    catch (error) {
        console.error("❌ Error copying current data to user session:", error);
        throw error;
    }
});
/**
 * Cloud Function: Manage device assignment
 *
 * HTTP function to assign/unassign device to users
 * Called by admin interface or testing system
 */
exports.assignDeviceToUser = functions.https.onCall(async (data, context) => {
    // Verify admin authentication (implement your auth logic)
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to assign devices');
    }
    const { userId, sessionId, action, adminNotes } = data;
    try {
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        if (action === "assign") {
            if (!userId || !sessionId) {
                throw new functions.https.HttpsError('invalid-argument', 'userId and sessionId are required for assignment');
            }
            const assignmentData = {
                assignedUser: userId,
                activeSessionId: sessionId,
                assignedAt: Date.now(),
                assignedBy: context.auth.uid
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
                    totalDataPoints: 0
                }
            });
            console.log(`✅ Device assigned to user ${userId}, session ${sessionId}`);
            return { success: true, message: "Device assigned successfully", userId, sessionId };
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
                        unassignedBy: context.auth.uid
                    });
                }
            }
            await assignmentRef.remove();
            console.log(`✅ Device unassigned`);
            return { success: true, message: "Device unassigned successfully" };
        }
        else {
            throw new functions.https.HttpsError('invalid-argument', 'Action must be "assign" or "unassign"');
        }
    }
    catch (error) {
        console.error("❌ Error managing device assignment:", error);
        throw new functions.https.HttpsError('internal', `Failed to ${action} device: ${error instanceof Error ? error.message : String(error)}`);
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
            return { assigned: false, message: "Device is not assigned to any user" };
        }
        const assignment = snapshot.val();
        return {
            assigned: true,
            assignedUser: assignment.assignedUser,
            activeSessionId: assignment.activeSessionId,
            assignedAt: assignment.assignedAt,
            assignedBy: assignment.assignedBy
        };
    }
    catch (error) {
        console.error("❌ Error getting device assignment:", error);
        throw new functions.https.HttpsError('internal', `Failed to get device assignment: ${error instanceof Error ? error.message : String(error)}`);
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
    const cutoffTime = Date.now() - (30 * 24 * 60 * 60 * 1000); // 30 days ago
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