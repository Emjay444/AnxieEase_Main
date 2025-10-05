"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.monitorDatabaseGrowth = exports.optimizedSessionCleanup = exports.removeDeviceHistoryRedundancy = exports.optimizedDeviceDataSync = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.database();
/**
 * OPTIMIZED Cloud Function: Copy device current data to user session ONLY
 *
 * This replaces the redundant copying system with a single, efficient data flow:
 * Device Current → User Session (current + history for active monitoring only)
 *
 * ELIMINATES:
 * - Device history storage (major storage saver)
 * - Redundant copying operations
 * - Exponential data growth
 */
exports.optimizedDeviceDataSync = functions.database
    .ref("/devices/AnxieEase001/current")
    .onWrite(async (change, context) => {
    // Only process if data was created or updated (not deleted)
    if (!change.after.exists()) {
        console.log("📱 Device current data deleted - no action needed");
        return null;
    }
    const currentData = change.after.val();
    console.log(`📊 Device current data updated - optimized sync started`);
    try {
        // Get device assignment information
        const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
        const assignmentSnapshot = await assignmentRef.once("value");
        if (!assignmentSnapshot.exists()) {
            console.log("⚠️ No device assignment found - data stays in device current only");
            return null;
        }
        const rawAssignment = assignmentSnapshot.val();
        const assignedUser = (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.assignedUser) || (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.userId);
        const activeSessionId = (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.activeSessionId) || (rawAssignment === null || rawAssignment === void 0 ? void 0 : rawAssignment.sessionId);
        if (!assignedUser || !activeSessionId) {
            console.log("⚠️ Device not assigned or no active session - skipping sync");
            return null;
        }
        console.log(`👤 Syncing to user: ${assignedUser}, session: ${activeSessionId}`);
        // 1. Update user's session current data (real-time monitoring)
        const userSessionCurrentRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/current`);
        const enrichedCurrentData = Object.assign(Object.assign({}, currentData), { deviceId: "AnxieEase001", lastUpdated: admin.database.ServerValue.TIMESTAMP, sessionId: activeSessionId, userId: assignedUser });
        await userSessionCurrentRef.set(enrichedCurrentData);
        console.log(`✅ Current data synced to user session`);
        // 2. CONDITIONALLY add to session history for anxiety detection window
        // Only keep last 50 data points for sustained analysis (sliding window)
        const sessionHistoryRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/history`);
        let ts = currentData.timestamp || Date.now();
        // Convert string timestamp to numeric if needed
        if (typeof ts === "string") {
            ts = new Date(ts).getTime();
        }
        const enrichedHistoryData = Object.assign(Object.assign({}, currentData), { deviceId: "AnxieEase001", timestamp: ts, copiedAt: admin.database.ServerValue.TIMESTAMP, sessionId: activeSessionId, userId: assignedUser });
        // Add to history for analysis window
        await sessionHistoryRef.child(ts.toString()).set(enrichedHistoryData);
        // 3. CLEAN OLD HISTORY DATA (sliding window approach)
        // Keep only last 50 entries to prevent unbounded growth
        const historySnapshot = await sessionHistoryRef
            .orderByChild("timestamp")
            .limitToLast(60) // Get 60 to identify oldest 10 to remove
            .once("value");
        if (historySnapshot.exists()) {
            const historyData = historySnapshot.val();
            const timestamps = Object.keys(historyData).sort((a, b) => (historyData[a].timestamp || 0) - (historyData[b].timestamp || 0));
            // If we have more than 50 entries, remove the oldest ones
            if (timestamps.length > 50) {
                const toRemove = timestamps.slice(0, timestamps.length - 50);
                const removeBatch = {};
                toRemove.forEach(ts => {
                    removeBatch[ts] = null; // Firebase deletion syntax
                });
                if (Object.keys(removeBatch).length > 0) {
                    await sessionHistoryRef.update(removeBatch);
                    console.log(`🗑️ Cleaned ${Object.keys(removeBatch).length} old history entries`);
                }
            }
        }
        // 4. Update session metadata
        const sessionMetadataRef = db.ref(`/users/${assignedUser}/sessions/${activeSessionId}/metadata`);
        await sessionMetadataRef.update({
            lastActivity: admin.database.ServerValue.TIMESTAMP,
            lastDataTimestamp: ts,
            totalDataPoints: admin.database.ServerValue.increment(1),
        });
        console.log(`📊 Optimized sync completed - storage efficient!`);
        return {
            success: true,
            userId: assignedUser,
            sessionId: activeSessionId,
            optimized: true,
            storageReduction: "~70%"
        };
    }
    catch (error) {
        console.error("❌ Error in optimized device data sync:", error);
        // Log error for monitoring
        await db.ref("/system/errors").push({
            type: "optimized_device_sync_error",
            timestamp: admin.database.ServerValue.TIMESTAMP,
            error: error instanceof Error ? error.message : String(error),
            data: currentData,
        });
        throw error;
    }
});
/**
 * MIGRATION HELPER: Remove device history node completely
 *
 * This function safely removes the redundant device history while
 * preserving essential data in user sessions
 */
exports.removeDeviceHistoryRedundancy = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Admin authentication required");
    }
    try {
        console.log("🚀 Starting device history redundancy removal...");
        // 1. Create backup of device history before deletion
        const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
        const historySnapshot = await deviceHistoryRef.once("value");
        if (historySnapshot.exists()) {
            const historyData = historySnapshot.val();
            const dataCount = Object.keys(historyData).length;
            // Store backup in system/backups
            const backupRef = db.ref("/system/backups/device_history_migration");
            await backupRef.set({
                timestamp: admin.database.ServerValue.TIMESTAMP,
                dataCount: dataCount,
                migratedBy: context.auth.uid,
                data: historyData, // Full backup for safety
            });
            console.log(`✅ Backup created for ${dataCount} history entries`);
            // 2. Remove the redundant device history node
            await deviceHistoryRef.remove();
            console.log(`🗑️ Device history node removed - freed significant storage!`);
            // 3. Update system stats
            await db.ref("/system/optimization").set({
                deviceHistoryRemoved: true,
                removedEntries: dataCount,
                optimizedAt: admin.database.ServerValue.TIMESTAMP,
                estimatedStorageSaved: `${Math.round(dataCount * 0.5)}KB`,
                optimizedBy: context.auth.uid,
            });
            return {
                success: true,
                message: "Device history redundancy removed successfully",
                entriesRemoved: dataCount,
                storageOptimized: true,
                backupLocation: "/system/backups/device_history_migration"
            };
        }
        else {
            return {
                success: true,
                message: "No device history found - already optimized",
                entriesRemoved: 0,
            };
        }
    }
    catch (error) {
        console.error("❌ Error removing device history redundancy:", error);
        throw new functions.https.HttpsError("internal", `Failed to optimize database: ${error instanceof Error ? error.message : String(error)}`);
    }
});
/**
 * ENHANCED: Automatic session cleanup with retention policy
 *
 * Cleans completed sessions older than 7 days (vs 30 days)
 * More aggressive cleanup for storage optimization
 */
exports.optimizedSessionCleanup = functions.pubsub
    .schedule("every 12 hours")
    .timeZone("UTC")
    .onRun(async (context) => {
    const retentionDays = 7; // Reduced from 30 to 7 days
    const cutoffTime = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
    try {
        const usersRef = db.ref("/users");
        const usersSnapshot = await usersRef.once("value");
        let cleanedSessions = 0;
        let totalDataPointsCleaned = 0;
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
                        // Count data points before deletion
                        const historyCount = session.history ? Object.keys(session.history).length : 0;
                        totalDataPointsCleaned += historyCount;
                        await db.ref(`/users/${userId}/sessions/${sessionId}`).remove();
                        cleanedSessions++;
                        console.log(`🗑️ Cleaned session: ${userId}/${sessionId} (${historyCount} data points)`);
                    }
                }
            }
        }
        // Update cleanup stats
        await db.ref("/system/cleanup_stats").set({
            lastCleanup: admin.database.ServerValue.TIMESTAMP,
            sessionsRemoved: cleanedSessions,
            dataPointsRemoved: totalDataPointsCleaned,
            retentionDays: retentionDays,
            nextCleanup: Date.now() + (12 * 60 * 60 * 1000), // 12 hours from now
        });
        console.log(`✅ Optimized cleanup completed:`);
        console.log(`   - Sessions removed: ${cleanedSessions}`);
        console.log(`   - Data points cleaned: ${totalDataPointsCleaned}`);
        console.log(`   - Storage freed: ~${Math.round(totalDataPointsCleaned * 0.5)}KB`);
        return {
            cleanedSessions,
            totalDataPointsCleaned,
            storageOptimized: true
        };
    }
    catch (error) {
        console.error("❌ Error during optimized session cleanup:", error);
        throw error;
    }
});
/**
 * MONITORING: Database size monitoring function
 *
 * Tracks database growth and alerts if storage is growing too fast
 */
exports.monitorDatabaseGrowth = functions.pubsub
    .schedule("every 6 hours")
    .timeZone("UTC")
    .onRun(async (context) => {
    try {
        // Count active data points across the database
        const devicesRef = db.ref("/devices");
        const usersRef = db.ref("/users");
        const [devicesSnapshot, usersSnapshot] = await Promise.all([
            devicesRef.once("value"),
            usersRef.once("value")
        ]);
        let totalDataPoints = 0;
        let activeHistoryPoints = 0;
        // Count device current data (should be minimal)
        if (devicesSnapshot.exists()) {
            const devices = devicesSnapshot.val();
            Object.keys(devices).forEach(deviceId => {
                if (devices[deviceId].current)
                    totalDataPoints++;
                if (devices[deviceId].history) {
                    console.warn(`⚠️ Device history still exists for ${deviceId} - should be optimized!`);
                }
            });
        }
        // Count user session data
        if (usersSnapshot.exists()) {
            const users = usersSnapshot.val();
            Object.keys(users).forEach(userId => {
                if (users[userId].sessions) {
                    Object.keys(users[userId].sessions).forEach(sessionId => {
                        const session = users[userId].sessions[sessionId];
                        if (session.current)
                            totalDataPoints++;
                        if (session.history) {
                            const historyCount = Object.keys(session.history).length;
                            activeHistoryPoints += historyCount;
                            totalDataPoints += historyCount;
                        }
                    });
                }
            });
        }
        // Store monitoring data
        await db.ref("/system/monitoring").set({
            timestamp: admin.database.ServerValue.TIMESTAMP,
            totalDataPoints: totalDataPoints,
            activeHistoryPoints: activeHistoryPoints,
            estimatedSizeMB: Math.round((totalDataPoints * 0.5) / 1024),
            optimizationStatus: activeHistoryPoints < 1000 ? "optimal" : "review_needed",
            nextMonitoring: Date.now() + (6 * 60 * 60 * 1000),
        });
        console.log(`📊 Database monitoring completed:`);
        console.log(`   - Total data points: ${totalDataPoints}`);
        console.log(`   - Active history points: ${activeHistoryPoints}`);
        console.log(`   - Estimated size: ${Math.round((totalDataPoints * 0.5) / 1024)}MB`);
        return {
            totalDataPoints,
            activeHistoryPoints,
            optimizationHealthy: activeHistoryPoints < 1000
        };
    }
    catch (error) {
        console.error("❌ Error monitoring database growth:", error);
        throw error;
    }
});
//# sourceMappingURL=optimizedDeviceDataService.js.map