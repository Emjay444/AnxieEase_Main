"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.monitorDuplicationPrevention = exports.removeTimestampDuplicates = exports.disabledDeviceHistoryCreation = exports.smartDeviceDataSync = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.database();
/**
 * SMART Function: Only copy device current data to user sessions
 *
 * IMPORTANT: This function does NOT write to device history at all.
 * Device history is managed by the wearable itself in native format.
 * We only handle user session copying for individual tracking.
 */
exports.smartDeviceDataSync = functions.database
    .ref("/devices/AnxieEase001/current")
    .onWrite(async (change, context) => {
    // Only process if data was created or updated (not deleted)
    if (!change.after.exists()) {
        console.log("📱 Device current data deleted - no action needed");
        return null;
    }
    const currentData = change.after.val();
    console.log(`📊 Smart sync: Device current data updated`);
    try {
        // Get device assignment information
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        const assignmentSnapshot = await assignmentRef.once("value");
        if (!assignmentSnapshot.exists()) {
            console.log("⚠️ No device assignment - data stays in device current only");
            console.log("💡 Device native history (YYYY_MM_DD format) preserved by wearable");
            return null;
        }
        const rawAssignment = assignmentSnapshot.val();
        const assignedUser = (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.assignedUser) || (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.userId);
        const activeSessionId = (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.activeSessionId) || (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.sessionId);
        if (!assignedUser || !activeSessionId) {
            console.log("⚠️ Device not assigned to user - skipping user session copy");
            console.log("💡 Device native history preserved, no user tracking");
            return null;
        }
        console.log(`👤 Smart sync to user: ${assignedUser}, session: ${activeSessionId}`);
        // 1. Update user's session current data (real-time monitoring)
        const userSessionCurrentRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/current`);
        const enrichedCurrentData = Object.assign(Object.assign({}, currentData), { deviceId: "AnxieEase001", lastUpdated: admin.database.ServerValue.TIMESTAMP, sessionId: activeSessionId, userId: assignedUser });
        await userSessionCurrentRef.set(enrichedCurrentData);
        console.log(`✅ Current data synced to user session`);
        // 2. Add to user session history for anxiety detection (sliding window)
        const sessionHistoryRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/history`);
        // Create timestamp from device timestamp string
        let ts;
        if (currentData.timestamp && typeof currentData.timestamp === 'string') {
            // Convert "2025-10-05 20:13:51" to milliseconds
            ts = new Date(currentData.timestamp).getTime();
        }
        else {
            ts = Date.now();
        }
        // Derive device-native key format for session history: YYYY_MM_DD_HH_MM_SS
        const toNativeKeyFromString = (s) => {
            // Already native format
            if (/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/.test(s))
                return s;
            // Common device format with dashes/colons and space separator
            const m = s.match(/^(\d{4})[-_/](\d{2})[-_/](\d{2})[ T](\d{2})[:_](\d{2})[:_](\d{2})$/);
            if (m)
                return `${m[1]}_${m[2]}_${m[3]}_${m[4]}_${m[5]}_${m[6]}`;
            // Fallback: replace common separators with underscore
            const replaced = s.replace(/[-: T/]/g, "_");
            return /^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/.test(replaced)
                ? replaced
                : null;
        };
        const pad2 = (n) => (n < 10 ? `0${n}` : `${n}`);
        const toNativeKeyFromMillis = (millis) => {
            const d = new Date(millis);
            const yyyy = d.getFullYear();
            const MM = pad2(d.getMonth() + 1);
            const dd = pad2(d.getDate());
            const HH = pad2(d.getHours());
            const mm = pad2(d.getMinutes());
            const ss = pad2(d.getSeconds());
            return `${yyyy}_${MM}_${dd}_${HH}_${mm}_${ss}`;
        };
        const sessionHistoryKey = (typeof currentData.timestamp === 'string'
            ? toNativeKeyFromString(currentData.timestamp)
            : null) || toNativeKeyFromMillis(ts);
        const enrichedHistoryData = Object.assign(Object.assign({}, currentData), { deviceId: "AnxieEase001", 
            // Keep numeric timestamp for sorting/queries; key uses native format
            timestamp: ts, copiedAt: admin.database.ServerValue.TIMESTAMP, sessionId: activeSessionId, userId: assignedUser, source: "device_current_sync" });
        // Add to user session history using native key (not device history!)
        await sessionHistoryRef.child(sessionHistoryKey).set(enrichedHistoryData);
        console.log(`📝 Added to user session history (native key): ${sessionHistoryKey}`);
        // 3. Maintain sliding window for user session (keep last 50 entries)
        const historySnapshot = await sessionHistoryRef
            .orderByChild("timestamp")
            .limitToLast(60)
            .once("value");
        if (historySnapshot.exists()) {
            const historyData = historySnapshot.val();
            const timestamps = Object.keys(historyData).sort((a, b) => (historyData[a].timestamp || 0) - (historyData[b].timestamp || 0));
            // Remove oldest entries if more than 50
            if (timestamps.length > 50) {
                const toRemove = timestamps.slice(0, timestamps.length - 50);
                const removeBatch = {};
                toRemove.forEach(ts => {
                    removeBatch[ts] = null;
                });
                await sessionHistoryRef.update(removeBatch);
                console.log(`🗑️ Cleaned ${toRemove.length} old entries from user session history`);
            }
        }
        // 4. Update session metadata
        const sessionMetadataRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/metadata`);
        await sessionMetadataRef.update({
            lastActivity: admin.database.ServerValue.TIMESTAMP,
            lastDataTimestamp: ts,
            totalDataPoints: admin.database.ServerValue.increment(1),
        });
        console.log(`🎯 Smart sync completed - no device history duplication!`);
        console.log(`💡 Device native format (YYYY_MM_DD) preserved by wearable`);
        return {
            success: true,
            userId: assignedUser,
            sessionId: activeSessionId,
            approach: "smart_no_duplication",
            deviceHistoryUntouched: true,
        };
    }
    catch (error) {
        console.error("❌ Error in smart device data sync:", error);
        await db.ref("/system/errors").push({
            type: "smart_device_sync_error",
            timestamp: admin.database.ServerValue.TIMESTAMP,
            error: error instanceof Error ? error.message : String(error),
            data: currentData,
        });
        throw error;
    }
});
/**
 * DISABLE the old redundant functions by creating replacements that do nothing
 *
 * This prevents the old copyDeviceDataToUserSession from creating duplicates
 */
exports.disabledDeviceHistoryCreation = functions.database
    .ref("/devices/AnxieEase001/history/{timestamp}")
    .onCreate(async (snapshot, context) => {
    const timestamp = context.params.timestamp;
    // Check if this is a device native format (wearable created)
    if (timestamp.match(/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/)) {
        console.log(`✅ Device native entry detected: ${timestamp} - preserving as-is`);
        return null; // Let the device's native entry remain
    }
    // Check if this is a timestamp duplicate (function created)
    if (timestamp.match(/^\d{13}$/)) {
        console.log(`⚠️ Timestamp duplicate detected: ${timestamp} - should be cleaned up`);
        console.log(`💡 Consider running cleanup script to remove timestamp duplicates`);
        return null; // Don't process duplicates
    }
    console.log(`ℹ️ Unknown format entry: ${timestamp} - no action taken`);
    return null;
});
/**
 * Cleanup function to remove existing timestamp duplicates
 */
exports.removeTimestampDuplicates = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Admin authentication required");
    }
    try {
        console.log("🧹 Starting smart cleanup: removing timestamp duplicates only");
        const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
        const historySnapshot = await deviceHistoryRef.once("value");
        if (!historySnapshot.exists()) {
            return {
                success: true,
                message: "No device history found",
                timestampDuplicatesRemoved: 0,
            };
        }
        const historyData = historySnapshot.val();
        let timestampDuplicates = 0;
        let deviceNativePreserved = 0;
        const toRemove = [];
        // Identify what to remove vs preserve
        Object.keys(historyData).forEach(key => {
            // Device native format: YYYY_MM_DD_HH_MM_SS (PRESERVE)
            if (key.match(/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/)) {
                deviceNativePreserved++;
                console.log(`✅ Preserving device native: ${key}`);
            }
            // Timestamp format: 13-digit number (REMOVE)
            else if (key.match(/^\d{13}$/)) {
                timestampDuplicates++;
                toRemove.push(key);
                console.log(`🗑️ Marking for removal: ${key}`);
            }
        });
        console.log(`📊 Analysis: ${deviceNativePreserved} native entries preserved, ${timestampDuplicates} duplicates to remove`);
        // Remove timestamp duplicates only
        if (toRemove.length > 0) {
            const removeBatch = {};
            toRemove.forEach(key => {
                removeBatch[key] = null; // Firebase deletion syntax
            });
            await deviceHistoryRef.update(removeBatch);
            console.log(`✅ Removed ${toRemove.length} timestamp duplicates`);
        }
        // Create cleanup log
        await db.ref("/system/smart_cleanup").set({
            timestamp: admin.database.ServerValue.TIMESTAMP,
            cleanupType: "timestamp_duplicates_only",
            deviceNativePreserved: deviceNativePreserved,
            timestampDuplicatesRemoved: timestampDuplicates,
            cleanedBy: context.auth.uid,
            preservationStrategy: "keep_device_native_format",
        });
        return {
            success: true,
            message: "Smart cleanup completed successfully",
            deviceNativePreserved: deviceNativePreserved,
            timestampDuplicatesRemoved: timestampDuplicates,
            storageOptimized: timestampDuplicates > 0,
        };
    }
    catch (error) {
        console.error("❌ Error in smart cleanup:", error);
        throw new functions.https.HttpsError("internal", `Smart cleanup failed: ${error instanceof Error ? error.message : String(error)}`);
    }
});
/**
 * Monitoring function to detect future duplication
 */
exports.monitorDuplicationPrevention = functions.pubsub
    .schedule("every 6 hours")
    .timeZone("UTC")
    .onRun(async (context) => {
    try {
        const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
        const historySnapshot = await deviceHistoryRef.once("value");
        let deviceNativeCount = 0;
        let timestampDuplicateCount = 0;
        if (historySnapshot.exists()) {
            const historyData = historySnapshot.val();
            Object.keys(historyData).forEach(key => {
                if (key.match(/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/)) {
                    deviceNativeCount++;
                }
                else if (key.match(/^\d{13}$/)) {
                    timestampDuplicateCount++;
                }
            });
        }
        await db.ref("/system/duplication_monitoring").set({
            timestamp: admin.database.ServerValue.TIMESTAMP,
            deviceNativeEntries: deviceNativeCount,
            timestampDuplicates: timestampDuplicateCount,
            duplicationStatus: timestampDuplicateCount === 0 ? "clean" : "needs_cleanup",
            recommendation: timestampDuplicateCount > 0 ?
                `Run cleanup to remove ${timestampDuplicateCount} timestamp duplicates` :
                "System is clean - no duplicates detected",
        });
        console.log(`📊 Duplication monitoring: ${deviceNativeCount} native, ${timestampDuplicateCount} duplicates`);
        return {
            deviceNativeEntries: deviceNativeCount,
            timestampDuplicates: timestampDuplicateCount,
            systemClean: timestampDuplicateCount === 0,
        };
    }
    catch (error) {
        console.error("❌ Error in duplication monitoring:", error);
        throw error;
    }
});
//# sourceMappingURL=smartDeviceDataSync.js.map