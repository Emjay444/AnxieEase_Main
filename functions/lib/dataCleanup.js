"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.monitorFirebaseUsage = exports.aggregateHealthDataHourly = exports.cleanupHealthData = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
/**
 * Cloud Function: Clean up old health data
 * Runs every hour to remove data older than retention periods
 */
exports.cleanupHealthData = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('UTC')
    .onRun(async (context) => {
    const db = admin.database();
    const now = Date.now();
    // Retention periods
    const retentionPeriods = {
        history: 24 * 60 * 60 * 1000,
        hourly_summary: 7 * 24 * 60 * 60 * 1000,
        alerts: 30 * 24 * 60 * 60 * 1000 // 30 days for alerts
    };
    try {
        let totalDeleted = 0;
        // Get all health metrics
        const healthMetricsRef = db.ref('health_metrics');
        const snapshot = await healthMetricsRef.once('value');
        if (!snapshot.exists()) {
            console.log('No health metrics data found');
            return null;
        }
        const deletionPromises = [];
        // Process each user's data
        snapshot.forEach((userSnapshot) => {
            const userId = userSnapshot.key;
            // Process each device
            userSnapshot.forEach((deviceSnapshot) => {
                const deviceId = deviceSnapshot.key;
                // Clean up history data (24 hours)
                const historyRef = deviceSnapshot.child('history');
                if (historyRef.exists()) {
                    historyRef.forEach((timestampSnapshot) => {
                        const timestamp = parseInt(timestampSnapshot.key || '0');
                        if (timestamp < (now - retentionPeriods.history)) {
                            deletionPromises.push(timestampSnapshot.ref.remove().then(() => {
                                totalDeleted++;
                                console.log(`Deleted history data: ${userId}/${deviceId}/${timestamp}`);
                            }));
                        }
                    });
                }
                // Clean up hourly summaries (7 days)
                const hourlySummaryRef = deviceSnapshot.child('hourly_summary');
                if (hourlySummaryRef.exists()) {
                    hourlySummaryRef.forEach((hourSnapshot) => {
                        const hourTimestamp = parseInt(hourSnapshot.key || '0');
                        if (hourTimestamp < (now - retentionPeriods.hourly_summary)) {
                            deletionPromises.push(hourSnapshot.ref.remove().then(() => {
                                totalDeleted++;
                                console.log(`Deleted hourly summary: ${userId}/${deviceId}/${hourTimestamp}`);
                            }));
                        }
                    });
                }
                // Clean up alerts (30 days)
                const alertsRef = deviceSnapshot.child('alerts');
                if (alertsRef.exists()) {
                    alertsRef.forEach((alertSnapshot) => {
                        const alertTimestamp = parseInt(alertSnapshot.key || '0');
                        if (alertTimestamp < (now - retentionPeriods.alerts)) {
                            deletionPromises.push(alertSnapshot.ref.remove().then(() => {
                                totalDeleted++;
                                console.log(`Deleted alert: ${userId}/${deviceId}/${alertTimestamp}`);
                            }));
                        }
                    });
                }
            });
        });
        // Execute all deletions
        await Promise.all(deletionPromises);
        console.log(`Health data cleanup completed. Total items deleted: ${totalDeleted}`);
        return {
            success: true,
            deletedCount: totalDeleted,
            timestamp: now
        };
    }
    catch (error) {
        console.error('Error during health data cleanup:', error);
        throw error;
    }
});
/**
 * Cloud Function: Aggregate health data hourly
 * Processes raw data into hourly summaries to reduce storage
 */
exports.aggregateHealthDataHourly = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('UTC')
    .onRun(async (context) => {
    const db = admin.database();
    const now = Date.now();
    const currentHour = Math.floor(now / (60 * 60 * 1000)) * (60 * 60 * 1000);
    const previousHour = currentHour - (60 * 60 * 1000);
    try {
        const healthMetricsRef = db.ref('health_metrics');
        const snapshot = await healthMetricsRef.once('value');
        if (!snapshot.exists()) {
            console.log('No health metrics data to aggregate');
            return null;
        }
        const aggregationPromises = [];
        snapshot.forEach((userSnapshot) => {
            const userId = userSnapshot.key;
            userSnapshot.forEach((deviceSnapshot) => {
                const deviceId = deviceSnapshot.key;
                const historyRef = deviceSnapshot.child('history');
                if (historyRef.exists()) {
                    const hourlyReadings = [];
                    // Collect readings from the previous hour
                    historyRef.forEach((timestampSnapshot) => {
                        const timestamp = parseInt(timestampSnapshot.key || '0');
                        if (timestamp >= previousHour && timestamp < currentHour) {
                            const reading = timestampSnapshot.val();
                            if (reading && reading.heartRate) {
                                hourlyReadings.push({
                                    timestamp,
                                    heartRate: reading.heartRate,
                                    spo2: reading.spo2,
                                    temperature: reading.bodyTemperature
                                });
                            }
                        }
                    });
                    // Create hourly summary if we have data
                    if (hourlyReadings.length > 0) {
                        const heartRates = hourlyReadings.map(r => r.heartRate).filter(hr => hr != null);
                        const spo2Values = hourlyReadings.map(r => r.spo2).filter(spo2 => spo2 != null);
                        const temperatures = hourlyReadings.map(r => r.temperature).filter(temp => temp != null);
                        const summary = {
                            dataPoints: hourlyReadings.length,
                            heartRate: heartRates.length > 0 ? {
                                min: Math.min(...heartRates),
                                max: Math.max(...heartRates),
                                avg: Math.round(heartRates.reduce((sum, hr) => sum + hr, 0) / heartRates.length)
                            } : null,
                            spo2: spo2Values.length > 0 ? {
                                min: Math.min(...spo2Values),
                                max: Math.max(...spo2Values),
                                avg: Math.round(spo2Values.reduce((sum, spo2) => sum + spo2, 0) / spo2Values.length)
                            } : null,
                            temperature: temperatures.length > 0 ? {
                                min: Math.min(...temperatures),
                                max: Math.max(...temperatures),
                                avg: Math.round((temperatures.reduce((sum, temp) => sum + temp, 0) / temperatures.length) * 10) / 10
                            } : null,
                            timestamp: previousHour
                        };
                        // Store hourly summary
                        const hourlyPath = `health_metrics/${userId}/${deviceId}/hourly_summary/${previousHour}`;
                        aggregationPromises.push(db.ref(hourlyPath).set(summary).then(() => {
                            console.log(`Created hourly summary: ${userId}/${deviceId}/${previousHour}`);
                        }));
                    }
                }
            });
        });
        await Promise.all(aggregationPromises);
        console.log(`Hourly aggregation completed. Summaries created: ${aggregationPromises.length}`);
        return {
            success: true,
            summariesCreated: aggregationPromises.length,
            timestamp: now
        };
    }
    catch (error) {
        console.error('Error during hourly aggregation:', error);
        throw error;
    }
});
/**
 * Cloud Function: Monitor Firebase usage and send alerts
 * Tracks data usage and sends notifications if approaching limits
 */
exports.monitorFirebaseUsage = functions.pubsub
    .schedule('every 24 hours')
    .timeZone('UTC')
    .onRun(async (context) => {
    const db = admin.database();
    try {
        // Get database size metrics (you'll need to implement this based on your Firebase plan)
        const healthMetricsRef = db.ref('health_metrics');
        const snapshot = await healthMetricsRef.once('value');
        if (snapshot.exists()) {
            const dataSize = JSON.stringify(snapshot.val()).length;
            const dataSizeMB = Math.round((dataSize / (1024 * 1024)) * 100) / 100;
            console.log(`Current health metrics data size: ${dataSizeMB} MB`);
            // Alert if data size exceeds threshold (adjust as needed)
            const thresholdMB = 100; // 100 MB threshold
            if (dataSizeMB > thresholdMB) {
                console.warn(`⚠️  Health metrics data size (${dataSizeMB} MB) exceeds threshold (${thresholdMB} MB)`);
                // You can add notification logic here (email, push notification, etc.)
                // For now, just log the warning
            }
            return {
                success: true,
                dataSizeMB,
                thresholdMB,
                alertTriggered: dataSizeMB > thresholdMB
            };
        }
        return { success: true, dataSizeMB: 0, alertTriggered: false };
    }
    catch (error) {
        console.error('Error monitoring Firebase usage:', error);
        throw error;
    }
});
//# sourceMappingURL=dataCleanup.js.map