"use strict";
/**
 * 🕒 FIREBASE AUTO-CLEANUP FUNCTION
 *
 * This Cloud Function automatically cleans up old data to prevent storage bloat.
 * Deploy this to run on a schedule (e.g., daily, weekly).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCleanupStats = exports.manualCleanup = exports.autoCleanup = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.database();
// Configuration - Updated for high-frequency wearable data (every 10 seconds)
const CLEANUP_CONFIG = {
    // Data retention periods (in days) - REDUCED for 10-second data intervals
    DEVICE_HISTORY_RETENTION: 3,
    USER_SESSION_RETENTION: 7,
    ANXIETY_ALERTS_RETENTION: 30,
    BACKUP_RETENTION: 3,
    CURRENT_DATA_RETENTION: 0.003,
    // Batch sizes for large datasets - INCREASED for high-volume data
    BATCH_SIZE: 500,
    // Safety limits - INCREASED for high-volume cleanup
    MAX_DELETIONS_PER_RUN: 5000, // Increased from 1000 for 10-second intervals
};
/**
 * Scheduled auto-cleanup function
 * Runs every 6 hours for high-frequency wearable data (10-second intervals)
 * Schedule: 2 AM, 8 AM, 2 PM, 8 PM UTC
 */
exports.autoCleanup = (0, scheduler_1.onSchedule)("0 2,8,14,20 * * *", async (event) => {
    firebase_functions_1.logger.info("🧹 Starting high-frequency scheduled Firebase cleanup...");
    try {
        const results = await performCleanup();
        firebase_functions_1.logger.info("✅ High-frequency scheduled cleanup completed:", results);
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ High-frequency scheduled cleanup failed:", error instanceof Error ? error.message : String(error));
    }
});
/**
 * Manual cleanup function (HTTP trigger)
 * Call via: https://your-project.cloudfunctions.net/manualCleanup
 */
exports.manualCleanup = (0, https_1.onRequest)(async (req, res) => {
    firebase_functions_1.logger.info("🧹 Manual cleanup triggered...");
    try {
        const results = await performCleanup();
        res.json({
            success: true,
            message: "Cleanup completed successfully",
            results
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Manual cleanup failed:", error instanceof Error ? error.message : String(error));
        res.status(500).json({
            success: false,
            message: "Cleanup failed",
            error: error instanceof Error ? error.message : String(error)
        });
    }
});
async function performCleanup() {
    const results = {
        deviceHistoryDeleted: 0,
        userSessionsDeleted: 0,
        anxietyAlertsDeleted: 0,
        backupsDeleted: 0,
        currentDataCleaned: 0,
        totalSavings: 0,
        timestamp: new Date().toISOString()
    };
    // 1. Clean up old device history
    results.deviceHistoryDeleted = await cleanupDeviceHistory();
    // 2. Clean up old user sessions
    results.userSessionsDeleted = await cleanupUserSessions();
    // 3. Clean up old anxiety alerts
    results.anxietyAlertsDeleted = await cleanupAnxietyAlerts();
    // 4. Clean up old backups
    results.backupsDeleted = await cleanupOldBackups();
    // 5. Clean up current data (NEW for high-frequency data)
    results.currentDataCleaned = await cleanupCurrentData();
    // Calculate total savings
    results.totalSavings =
        results.deviceHistoryDeleted +
            results.userSessionsDeleted +
            results.anxietyAlertsDeleted +
            results.backupsDeleted +
            results.currentDataCleaned;
    // Log cleanup summary
    await logCleanupResults(results);
    return results;
}
async function cleanupDeviceHistory() {
    firebase_functions_1.logger.info("🔍 Cleaning device history...");
    const cutoffTime = Date.now() - (CLEANUP_CONFIG.DEVICE_HISTORY_RETENTION * 24 * 60 * 60 * 1000);
    let deletedCount = 0;
    try {
        const historyRef = db.ref("/devices/AnxieEase001/history");
        const snapshot = await historyRef.orderByChild("timestamp").endAt(cutoffTime).once("value");
        if (snapshot.exists()) {
            const oldEntries = snapshot.val();
            const updates = {};
            for (const [key, entry] of Object.entries(oldEntries)) {
                if (entry.timestamp < cutoffTime) {
                    updates[key] = null;
                    deletedCount++;
                    if (deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN)
                        break;
                }
            }
            if (Object.keys(updates).length > 0) {
                await historyRef.update(updates);
                firebase_functions_1.logger.info(`✅ Deleted ${deletedCount} old device history entries`);
            }
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Device history cleanup failed:", error);
    }
    return deletedCount;
}
async function cleanupUserSessions() {
    var _a, _b;
    firebase_functions_1.logger.info("🔍 Cleaning user session data...");
    const sessionRetentionTime = Date.now() - (CLEANUP_CONFIG.USER_SESSION_RETENTION * 24 * 60 * 60 * 1000);
    let deletedCount = 0;
    try {
        const usersRef = db.ref("/users");
        const usersSnapshot = await usersRef.once("value");
        if (usersSnapshot.exists()) {
            const users = usersSnapshot.val();
            for (const [userId, userData] of Object.entries(users)) {
                if (!userData.sessions)
                    continue;
                const sessions = userData.sessions;
                const updates = {};
                for (const [sessionId, session] of Object.entries(sessions)) {
                    const sessionData = session;
                    // Only clean up COMPLETED sessions that are old enough
                    const isCompleted = ((_a = sessionData.metadata) === null || _a === void 0 ? void 0 : _a.status) === "completed";
                    const endTime = (_b = sessionData.metadata) === null || _b === void 0 ? void 0 : _b.endTime;
                    if (isCompleted && endTime && endTime < sessionRetentionTime) {
                        // Remove entire session (including history and metadata)
                        updates[`/users/${userId}/sessions/${sessionId}`] = null;
                        deletedCount++;
                        firebase_functions_1.logger.info(`🗑️ Marking session for deletion: ${userId}/${sessionId}`);
                        if (deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN)
                            break;
                    }
                    else if (!isCompleted && sessionData.history) {
                        // For active sessions, clean up old history entries (keep session active)
                        const historyEntries = sessionData.history;
                        let historyDeleted = 0;
                        for (const [timestamp] of Object.entries(historyEntries)) {
                            const entryTime = parseInt(timestamp);
                            if (entryTime < sessionRetentionTime) {
                                updates[`/users/${userId}/sessions/${sessionId}/history/${timestamp}`] = null;
                                historyDeleted++;
                                if (historyDeleted >= 100)
                                    break; // Limit per active session
                            }
                        }
                        if (historyDeleted > 0) {
                            firebase_functions_1.logger.info(`🧹 Cleaning ${historyDeleted} old history entries from active session: ${userId}/${sessionId}`);
                            deletedCount += historyDeleted;
                        }
                    }
                }
                if (Object.keys(updates).length > 0) {
                    await db.ref().update(updates);
                }
            }
            if (deletedCount > 0) {
                firebase_functions_1.logger.info(`✅ Cleaned ${deletedCount} user session entries`);
            }
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ User session cleanup failed:", error);
    }
    return deletedCount;
}
/**
 * NEW: Clean up current data more aggressively for high-frequency wearable data
 * Removes current data older than 5 minutes to prevent buildup
 */
async function cleanupCurrentData() {
    firebase_functions_1.logger.info("🔍 Cleaning high-frequency current data...");
    const cutoffTime = Date.now() - (CLEANUP_CONFIG.CURRENT_DATA_RETENTION * 24 * 60 * 60 * 1000); // 5 minutes
    let deletedCount = 0;
    try {
        // Clean device current data
        const deviceCurrentRef = db.ref("/devices/AnxieEase001/current");
        const deviceSnapshot = await deviceCurrentRef.once("value");
        if (deviceSnapshot.exists()) {
            const currentData = deviceSnapshot.val();
            if (currentData.timestamp && currentData.timestamp < cutoffTime) {
                await deviceCurrentRef.remove();
                deletedCount++;
                firebase_functions_1.logger.info("🧹 Cleared old device current data");
            }
        }
        // Clean user current data
        const usersRef = db.ref("/users");
        const usersSnapshot = await usersRef.once("value");
        if (usersSnapshot.exists()) {
            const users = usersSnapshot.val();
            const updates = {};
            for (const [userId, userData] of Object.entries(users)) {
                const userSessions = userData.sessions;
                if (!userSessions)
                    continue;
                for (const [sessionId, sessionData] of Object.entries(userSessions)) {
                    const current = sessionData.current;
                    if (current && current.timestamp && current.timestamp < cutoffTime) {
                        updates[`/users/${userId}/sessions/${sessionId}/current`] = null;
                        deletedCount++;
                    }
                }
            }
            if (Object.keys(updates).length > 0) {
                await db.ref().update(updates);
                firebase_functions_1.logger.info(`🧹 Cleared ${Object.keys(updates).length} old user current data entries`);
            }
        }
        if (deletedCount > 0) {
            firebase_functions_1.logger.info(`✅ Cleaned ${deletedCount} current data entries (high-frequency optimization)`);
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Current data cleanup failed:", error);
    }
    return deletedCount;
}
async function cleanupAnxietyAlerts() {
    firebase_functions_1.logger.info("🔍 Cleaning anxiety alerts...");
    const cutoffTime = Date.now() - (CLEANUP_CONFIG.ANXIETY_ALERTS_RETENTION * 24 * 60 * 60 * 1000);
    let deletedCount = 0;
    try {
        const usersRef = db.ref("/users");
        const usersSnapshot = await usersRef.once("value");
        if (usersSnapshot.exists()) {
            const users = usersSnapshot.val();
            for (const [userId, userData] of Object.entries(users)) {
                if (!userData.anxietyAlerts)
                    continue;
                const alerts = userData.anxietyAlerts;
                const updates = {};
                for (const [alertId, alert] of Object.entries(alerts)) {
                    if (alert.timestamp < cutoffTime) {
                        updates[`/users/${userId}/anxietyAlerts/${alertId}`] = null;
                        deletedCount++;
                    }
                }
                if (Object.keys(updates).length > 0) {
                    await db.ref().update(updates);
                }
            }
            if (deletedCount > 0) {
                firebase_functions_1.logger.info(`✅ Deleted ${deletedCount} old anxiety alerts`);
            }
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Anxiety alerts cleanup failed:", error);
    }
    return deletedCount;
}
async function cleanupOldBackups() {
    var _a;
    firebase_functions_1.logger.info("🔍 Cleaning old backups...");
    const cutoffTime = Date.now() - (CLEANUP_CONFIG.BACKUP_RETENTION * 24 * 60 * 60 * 1000);
    let deletedCount = 0;
    try {
        const backupsRef = db.ref("/backups");
        const snapshot = await backupsRef.once("value");
        if (snapshot.exists()) {
            const backups = snapshot.val();
            const updates = {};
            for (const [backupId, backup] of Object.entries(backups)) {
                const backupTime = new Date((_a = backup.metadata) === null || _a === void 0 ? void 0 : _a.created).getTime();
                if (backupTime < cutoffTime) {
                    updates[backupId] = null;
                    deletedCount++;
                }
            }
            if (Object.keys(updates).length > 0) {
                await backupsRef.update(updates);
                firebase_functions_1.logger.info(`✅ Deleted ${deletedCount} old backups`);
            }
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Backup cleanup failed:", error);
    }
    return deletedCount;
}
async function logCleanupResults(results) {
    try {
        // Log to Firebase for monitoring
        await db.ref("/system/cleanup_logs").push(Object.assign(Object.assign({}, results), { config: CLEANUP_CONFIG }));
        firebase_functions_1.logger.info("📊 Cleanup Results:", results);
    }
    catch (error) {
        firebase_functions_1.logger.error("❌ Failed to log cleanup results:", error);
    }
}
/**
 * Get cleanup statistics
 */
exports.getCleanupStats = (0, https_1.onRequest)(async (req, res) => {
    try {
        const logsRef = db.ref("/system/cleanup_logs");
        const recentLogs = await logsRef.orderByChild("timestamp").limitToLast(10).once("value");
        res.json({
            success: true,
            recentCleanups: recentLogs.val() || {},
            config: CLEANUP_CONFIG
        });
    }
    catch (error) {
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : String(error)
        });
    }
});
//# sourceMappingURL=autoCleanup.js.map