/**
 * 🕒 FIREBASE AUTO-CLEANUP FUNCTION
 *
 * This Cloud Function automatically cleans up old data to prevent storage bloat.
 * Deploy this to run on a schedule (e.g., daily, weekly).
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();

// Configuration - BALANCED for high-frequency wearable data (every 10 seconds, single user)
const CLEANUP_CONFIG = {
  // Data retention periods (in days)
  DEVICE_HISTORY_RETENTION: 1, // Keep 1 day of sensor history (~8.6k points)
  USER_SESSION_RETENTION: 3, // Keep 3 days of user sessions (~25.9k points)
  ANXIETY_ALERTS_RETENTION: 30, // Keep 30 days of anxiety alerts (reduced from 180)
  BACKUP_RETENTION: 3, // Keep 3 days of backups
  CURRENT_DATA_RETENTION: 0.003, // Keep current data for 5 minutes only (0.003 days)

  // Batch sizes for large datasets - INCREASED for high-volume data
  BATCH_SIZE: 500, // Increased from 100 for efficiency

  // Safety limits - INCREASED for high-volume cleanup
  MAX_DELETIONS_PER_RUN: 5000, // Increased from 1000 for 10-second intervals
};

/**
 * Scheduled auto-cleanup function
 * Runs every 2 hours to prevent database bloat
 * Schedule: Every 2 hours (UTC)
 */
export const autoCleanup = functions.pubsub
  .schedule("0 2,8,14,20 * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    functions.logger.info(
      "🧹 Starting high-frequency scheduled Firebase cleanup..."
    );
    try {
      const results = await performCleanup();
      functions.logger.info(
        "✅ High-frequency scheduled cleanup completed:",
        results
      );
    } catch (error) {
      functions.logger.error(
        "❌ High-frequency scheduled cleanup failed:",
        error instanceof Error ? error.message : String(error)
      );
    }
  });

/**
 * Manual cleanup function (HTTP trigger)
 * Call via: https://your-project.cloudfunctions.net/manualCleanup
 */
export const manualCleanup = functions.https.onRequest(async (req, res) => {
  functions.logger.info("🧹 Manual cleanup triggered...");
  try {
    const results = await performCleanup();
    res.json({
      success: true,
      message: "Cleanup completed successfully",
      results,
    });
  } catch (error) {
    functions.logger.error(
      "❌ Manual cleanup failed:",
      error instanceof Error ? error.message : String(error)
    );
    res.status(500).json({
      success: false,
      message: "Cleanup failed",
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

async function performCleanup() {
  const results = {
    deviceHistoryDeleted: 0,
    userSessionsDeleted: 0,
    anxietyAlertsDeleted: 0,
    backupsDeleted: 0,
    currentDataCleaned: 0, // NEW: Track current data cleanup
    totalSavings: 0,
    timestamp: new Date().toISOString(),
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

async function cleanupDeviceHistory(): Promise<number> {
  functions.logger.info("🔍 Cleaning device history...");

  const cutoffTime =
    Date.now() - CLEANUP_CONFIG.DEVICE_HISTORY_RETENTION * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  try {
    const historyRef = db.ref("/devices/AnxieEase001/history");
    const snapshot = await historyRef.once("value");

    if (snapshot.exists()) {
      const allEntries = snapshot.val();
      const updates: { [key: string]: null } = {};

      for (const [key, entry] of Object.entries(allEntries)) {
        let entryTime = 0;

        // If entry has a timestamp field, use it
        if ((entry as any)?.timestamp) {
          const timestampValue = (entry as any).timestamp;
          if (typeof timestampValue === "number") {
            entryTime = timestampValue;
          } else if (typeof timestampValue === "string") {
            // Parse string timestamps like "2025-10-06 14:54:35"
            entryTime = new Date(timestampValue).getTime();
          }
        } else if (/^\d{13}$/.test(key)) {
          // 13-digit timestamp key
          entryTime = parseInt(key);
        } else if (/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/.test(key)) {
          // Device native key: YYYY_MM_DD_HH_MM_SS -> convert to epoch
          const [year, month, day, hour, minute, second] = key
            .split("_")
            .map(Number);
          entryTime = new Date(
            year,
            month - 1,
            day,
            hour,
            minute,
            second
          ).getTime();
        }

        if (entryTime > 0 && entryTime < cutoffTime) {
          updates[key] = null;
          deletedCount++;

          if (deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN) break;
        }
      }

      const count = Object.keys(updates).length;
      if (count > 0) {
        await historyRef.update(updates);
        functions.logger.info(
          `✅ Deleted ${deletedCount} old device history entries`
        );
      } else {
        functions.logger.info(
          `ℹ️ No old device history entries found (cutoff: ${new Date(
            cutoffTime
          ).toISOString()})`
        );
      }
    }
  } catch (error) {
    functions.logger.error("❌ Device history cleanup failed:", error);
  }

  return deletedCount;
}

async function cleanupUserSessions(): Promise<number> {
  functions.logger.info("🔍 Cleaning user session data...");

  const sessionRetentionTime =
    Date.now() - CLEANUP_CONFIG.USER_SESSION_RETENTION * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");

    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();

      for (const [userId, userData] of Object.entries(users)) {
        if (!(userData as any).sessions) continue;

        const sessions = (userData as any).sessions;
        const updates: { [key: string]: null } = {};

        for (const [sessionId, session] of Object.entries(sessions)) {
          const sessionData = session as any;

          // Prefer completed sessions, but also clean stale inactive ones by startTime
          const isCompleted = sessionData.metadata?.status === "completed";
          const endTime = sessionData.metadata?.endTime;
          const startTime = sessionData.metadata?.startTime;

          if (isCompleted && endTime && endTime < sessionRetentionTime) {
            // Remove entire session (including history and metadata)
            updates[`/users/${userId}/sessions/${sessionId}`] = null;
            deletedCount++;

            functions.logger.info(
              `🗑️ Marking session for deletion: ${userId}/${sessionId}`
            );

            if (deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN) break;
          } else if (
            !isCompleted &&
            startTime &&
            startTime < sessionRetentionTime
          ) {
            // Old inactive session
            updates[`/users/${userId}/sessions/${sessionId}`] = null;
            deletedCount++;

            functions.logger.info(
              `🗑️ Marking old inactive session for deletion: ${userId}/${sessionId}`
            );

            if (deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN) break;
          } else if (!isCompleted && sessionData.history) {
            // For active sessions, clean up old history entries (keep session active)
            const historyEntries = sessionData.history;
            let historyDeleted = 0;

            for (const [timestamp] of Object.entries(historyEntries)) {
              const entryTime = parseInt(timestamp);
              if (entryTime < sessionRetentionTime) {
                updates[
                  `/users/${userId}/sessions/${sessionId}/history/${timestamp}`
                ] = null;
                historyDeleted++;

                if (historyDeleted >= 100) break; // Limit per active session
              }
            }

            if (historyDeleted > 0) {
              functions.logger.info(
                `🧹 Cleaning ${historyDeleted} old history entries from active session: ${userId}/${sessionId}`
              );
              deletedCount += historyDeleted;
            }
          }
        }

        if (Object.keys(updates).length > 0) {
          await db.ref().update(updates);
        }
      }

      if (deletedCount > 0) {
        functions.logger.info(
          `✅ Cleaned ${deletedCount} user session entries`
        );
      }
    }
  } catch (error) {
    functions.logger.error("❌ User session cleanup failed:", error);
  }

  return deletedCount;
}

/**
 * NEW: Clean up current data more aggressively for high-frequency wearable data
 * Removes current data older than 5 minutes to prevent buildup
 */
async function cleanupCurrentData(): Promise<number> {
  functions.logger.info("🔍 Cleaning high-frequency current data...");

  const cutoffTime =
    Date.now() - CLEANUP_CONFIG.CURRENT_DATA_RETENTION * 24 * 60 * 60 * 1000; // 5 minutes
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
        functions.logger.info("🧹 Cleared old device current data");
      }
    }

    // Clean user current data
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");

    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();
      const updates: { [key: string]: null } = {};

      for (const [userId, userData] of Object.entries(users)) {
        const userSessions = (userData as any).sessions;
        if (!userSessions) continue;

        for (const [sessionId, sessionData] of Object.entries(userSessions)) {
          const current = (sessionData as any).current;
          if (current && current.timestamp && current.timestamp < cutoffTime) {
            updates[`/users/${userId}/sessions/${sessionId}/current`] = null;
            deletedCount++;
          }
        }
      }

      if (Object.keys(updates).length > 0) {
        await db.ref().update(updates);
        functions.logger.info(
          `🧹 Cleared ${
            Object.keys(updates).length
          } old user current data entries`
        );
      }
    }

    if (deletedCount > 0) {
      functions.logger.info(
        `✅ Cleaned ${deletedCount} current data entries (high-frequency optimization)`
      );
    }
  } catch (error) {
    functions.logger.error("❌ Current data cleanup failed:", error);
  }

  return deletedCount;
}

async function cleanupAnxietyAlerts(): Promise<number> {
  functions.logger.info("🔍 Cleaning anxiety alerts...");

  const cutoffTime =
    Date.now() - CLEANUP_CONFIG.ANXIETY_ALERTS_RETENTION * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");

    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();

      for (const [userId, userData] of Object.entries(users)) {
        if (!(userData as any).anxietyAlerts) continue;

        const alerts = (userData as any).anxietyAlerts;
        const updates: { [key: string]: null } = {};

        for (const [alertId, alert] of Object.entries(alerts)) {
          if ((alert as any).timestamp < cutoffTime) {
            updates[`/users/${userId}/anxietyAlerts/${alertId}`] = null;
            deletedCount++;
          }
        }

        if (Object.keys(updates).length > 0) {
          await db.ref().update(updates);
        }
      }

      if (deletedCount > 0) {
        functions.logger.info(`✅ Deleted ${deletedCount} old anxiety alerts`);
      }
    }
  } catch (error) {
    functions.logger.error("❌ Anxiety alerts cleanup failed:", error);
  }

  return deletedCount;
}

async function cleanupOldBackups(): Promise<number> {
  functions.logger.info("🔍 Cleaning old backups...");

  const cutoffTime =
    Date.now() - CLEANUP_CONFIG.BACKUP_RETENTION * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  try {
    const backupsRef = db.ref("/backups");
    const snapshot = await backupsRef.once("value");

    if (snapshot.exists()) {
      const backups = snapshot.val();
      const updates: { [key: string]: null } = {};

      for (const [backupId, backup] of Object.entries(backups)) {
        const backupTime = new Date(
          (backup as any).metadata?.created
        ).getTime();

        if (backupTime < cutoffTime) {
          updates[backupId] = null;
          deletedCount++;
        }
      }

      if (Object.keys(updates).length > 0) {
        await backupsRef.update(updates);
        functions.logger.info(`✅ Deleted ${deletedCount} old backups`);
      }
    }
  } catch (error) {
    functions.logger.error("❌ Backup cleanup failed:", error);
  }

  return deletedCount;
}

async function logCleanupResults(results: any): Promise<void> {
  try {
    // Log to Firebase for monitoring
    await db.ref("/system/cleanup_logs").push({
      ...results,
      config: CLEANUP_CONFIG,
    });

    functions.logger.info("📊 Cleanup Results:", results);
  } catch (error) {
    functions.logger.error("❌ Failed to log cleanup results:", error);
  }
}

/**
 * Get cleanup statistics
 */
export const getCleanupStats = functions.https.onRequest(async (req, res) => {
  try {
    const logsRef = db.ref("/system/cleanup_logs");
    const recentLogs = await logsRef
      .orderByChild("timestamp")
      .limitToLast(10)
      .once("value");

    res.json({
      success: true,
      recentCleanups: recentLogs.val() || {},
      config: CLEANUP_CONFIG,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
