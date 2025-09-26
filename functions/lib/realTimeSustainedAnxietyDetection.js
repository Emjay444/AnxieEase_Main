"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.realTimeSustainedAnxietyDetection = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
/**
 * Real-time anxiety detection with user-specific analysis
 * Triggers when device current data is updated
 * Only processes if device is assigned to a user
 */
exports.realTimeSustainedAnxietyDetection = functions.database
    .ref("/devices/{deviceId}/current")
    .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const afterData = change.after.val();
    console.log(`🔍 Device ${deviceId} data updated, checking for user assignment`);
    // Validate required data
    if (!afterData ||
        !afterData.heartRate ||
        typeof afterData.heartRate !== "number") {
        console.log("❌ Missing or invalid heart rate data");
        return null;
    }
    try {
        // STEP 1: Check if device is assigned to a user
        const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
        const assignmentSnapshot = await assignmentRef.once("value");
        if (!assignmentSnapshot.exists()) {
            console.log(`⚠️ Device ${deviceId} not assigned to any user - skipping anxiety detection`);
            return null;
        }
        const assignment = assignmentSnapshot.val();
        if (!assignment.assignedUser || !assignment.activeSessionId) {
            console.log(`⚠️ Device ${deviceId} assignment incomplete - skipping`);
            return null;
        }
        const userId = assignment.assignedUser;
        const sessionId = assignment.activeSessionId;
        console.log(`👤 Device assigned to user: ${userId}, session: ${sessionId}`);
        // STEP 2: Get user's personal baseline
        const userBaseline = await getUserBaseline(userId, deviceId);
        if (!userBaseline || !userBaseline.baselineHR) {
            console.log(`⚠️ No baseline found for user ${userId} - skipping anxiety detection`);
            return null;
        }
        console.log(`📊 User baseline: ${userBaseline.baselineHR} BPM`);
        // STEP 3: Get user's recent session history (not device history!)
        const userHistoryData = await getUserSessionHistory(userId, sessionId, 40);
        if (userHistoryData.length < 3) {
            console.log(`⚠️ Not enough user session history (${userHistoryData.length} points) for sustained detection`);
            return null;
        }
        // STEP 4: Analyze for sustained anxiety using USER-SPECIFIC data
        const sustainedAnalysis = analyzeUserSustainedAnxiety(userHistoryData, userBaseline.baselineHR, afterData, userId);
        if (sustainedAnalysis.isSustained) {
            console.log(`🚨 SUSTAINED ANXIETY DETECTED FOR USER ${userId}`);
            console.log(`📊 Duration: ${sustainedAnalysis.sustainedSeconds}s`);
            console.log(`💓 Average HR: ${sustainedAnalysis.averageHR} (${sustainedAnalysis.percentageAbove}% above user's baseline)`);
            // STEP 5: Send FCM notification to SPECIFIC USER
            return await sendUserAnxietyAlert({
                userId: userId,
                sessionId: sessionId,
                deviceId: deviceId,
                severity: sustainedAnalysis.severity,
                heartRate: sustainedAnalysis.averageHR,
                baseline: userBaseline.baselineHR,
                duration: sustainedAnalysis.sustainedSeconds,
                reason: sustainedAnalysis.reason,
            });
        }
        else {
            console.log(`✅ User ${userId}: Heart rate elevated but not sustained (${sustainedAnalysis.durationSeconds}s < 30s required)`);
        }
        return null;
    }
    catch (error) {
        console.error("❌ Error in user-specific anxiety detection:", error);
        return null;
    }
});
/**
 * Get user's session history data (from user sessions, not raw device data)
 */
async function getUserSessionHistory(userId, sessionId, seconds) {
    const userSessionRef = db.ref(`/users/${userId}/sessions/${sessionId}/history`);
    const cutoffTime = Date.now() - seconds * 1000;
    try {
        const snapshot = await userSessionRef
            .orderByChild("timestamp")
            .startAt(cutoffTime)
            .once("value");
        if (!snapshot.exists()) {
            console.log(`📊 No user session history found for ${userId}/${sessionId} in last ${seconds}s`);
            return [];
        }
        const historyData = [];
        snapshot.forEach((childSnapshot) => {
            const data = childSnapshot.val();
            if (data && data.heartRate && data.timestamp) {
                historyData.push({
                    timestamp: data.timestamp,
                    heartRate: data.heartRate,
                    spo2: data.spo2,
                    bodyTemp: data.bodyTemp,
                    worn: data.worn || 1,
                });
            }
        });
        // Sort by timestamp (most recent first)
        historyData.sort((a, b) => b.timestamp - a.timestamp);
        console.log(`📊 Retrieved ${historyData.length} user session history points for analysis`);
        return historyData;
    }
    catch (error) {
        console.error("❌ Error fetching user session history:", error);
        return [];
    }
}
/**
 * Analyze sustained anxiety using USER-SPECIFIC data and baselines
 */
function analyzeUserSustainedAnxiety(userHistoryData, baselineHR, currentData, userId) {
    if (userHistoryData.length < 3) {
        return { isSustained: false, durationSeconds: 0 };
    }
    // User-specific anxiety threshold (20% above their personal baseline)
    const anxietyThreshold = baselineHR * 1.2;
    const now = Date.now();
    console.log(`📊 User ${userId} analysis: threshold=${anxietyThreshold} BPM, current=${currentData.heartRate} BPM`);
    // Include current data point and sort by timestamp
    const allData = [Object.assign(Object.assign({}, currentData), { timestamp: now }), ...userHistoryData].sort((a, b) => a.timestamp - b.timestamp); // Sort chronologically (oldest first)
    console.log(`📊 Analyzing ${allData.length} data points chronologically for user ${userId}`);
    // Find the longest continuous elevated period
    let longestSustainedDuration = 0;
    let currentSustainedStart = null;
    let currentElevatedPoints = [];
    let bestElevatedPoints = [];
    for (const point of allData) {
        if (point.heartRate >= anxietyThreshold && point.worn !== 0) {
            // Heart rate is elevated
            if (currentSustainedStart === null) {
                currentSustainedStart = point.timestamp;
                currentElevatedPoints = [];
            }
            currentElevatedPoints.push(point);
        }
        else {
            // Heart rate dropped below threshold - check if this was our best sustained period
            if (currentSustainedStart !== null) {
                const sustainedDuration = (point.timestamp - currentSustainedStart) / 1000;
                console.log(`📊 User ${userId}: Found elevated period of ${sustainedDuration}s (${currentElevatedPoints.length} points)`);
                if (sustainedDuration > longestSustainedDuration) {
                    longestSustainedDuration = sustainedDuration;
                    bestElevatedPoints = [...currentElevatedPoints];
                }
            }
            // Reset for next potential period
            currentSustainedStart = null;
            currentElevatedPoints = [];
        }
    }
    // Check if the current ongoing period is still elevated (might be our longest)
    if (currentSustainedStart !== null) {
        // For ongoing periods, use the latest data point's timestamp, not current time
        const latestTimestamp = Math.max(...allData.map((p) => p.timestamp));
        const ongoingSustainedDuration = (latestTimestamp - currentSustainedStart) / 1000;
        console.log(`📊 User ${userId}: Current ongoing elevated period: ${ongoingSustainedDuration}s (${currentElevatedPoints.length} points)`);
        if (ongoingSustainedDuration > longestSustainedDuration) {
            longestSustainedDuration = ongoingSustainedDuration;
            bestElevatedPoints = [...currentElevatedPoints];
        }
    }
    // Check if we have 10+ seconds of sustained elevation (reduced for testing)
    if (longestSustainedDuration >= 10 && bestElevatedPoints.length > 0) {
        const avgHR = bestElevatedPoints.reduce((sum, p) => sum + p.heartRate, 0) /
            bestElevatedPoints.length;
        const percentageAbove = Math.round(((avgHR - baselineHR) / baselineHR) * 100);
        console.log(`🚨 User ${userId}: SUSTAINED ANXIETY DETECTED! ${longestSustainedDuration}s at avg ${avgHR} BPM`);
        return {
            isSustained: true,
            sustainedSeconds: Math.floor(longestSustainedDuration),
            averageHR: Math.round(avgHR),
            percentageAbove: percentageAbove,
            severity: getSeverityLevel(avgHR, baselineHR),
            reason: `User ${userId}: Heart rate sustained ${percentageAbove}% above personal baseline for ${Math.floor(longestSustainedDuration)}+ seconds`,
        };
    }
    console.log(`✅ User ${userId}: Heart rate elevated but not sustained (${longestSustainedDuration}s < 10s required)`);
    return {
        isSustained: false,
        durationSeconds: Math.floor(longestSustainedDuration),
        reason: longestSustainedDuration > 0
            ? `User ${userId}: Elevated for ${Math.floor(longestSustainedDuration)}s (need 10s)`
            : `User ${userId}: HR within normal range`,
    };
}
/**
 * Determine severity level based on heart rate elevation
 */
function getSeverityLevel(heartRate, baseline) {
    const percentageAbove = ((heartRate - baseline) / baseline) * 100;
    if (percentageAbove >= 50)
        return "severe";
    if (percentageAbove >= 30)
        return "moderate";
    return "mild";
}
/**
 * Send FCM notification to specific user
 */
async function sendUserAnxietyAlert(alertData) {
    console.log(`🔔 Sending anxiety alert notification to user ${alertData.userId}`);
    try {
        // Get user's FCM token from Firebase
        const fcmToken = await getUserFCMToken(alertData.userId, alertData.deviceId);
        if (!fcmToken) {
            console.log(`⚠️ No FCM token found for user ${alertData.userId}`);
            return null;
        }
        const notificationContent = getUserNotificationContent(alertData);
        const message = {
            token: fcmToken,
            notification: {
                title: notificationContent.title,
                body: notificationContent.body,
            },
            data: {
                type: "anxiety_alert",
                userId: alertData.userId,
                sessionId: alertData.sessionId,
                severity: alertData.severity,
                heartRate: alertData.heartRate.toString(),
                baseline: alertData.baseline.toString(),
                duration: alertData.duration.toString(),
            },
            android: {
                priority: "high",
                notification: {
                    color: notificationContent.color,
                    sound: "anxiety_alert",
                },
            },
        };
        const response = await admin.messaging().send(message);
        console.log(`✅ Notification sent successfully to user ${alertData.userId}:`, response);
        // Store alert in user's personal history
        await storeUserAnxietyAlert(alertData);
        return response;
    }
    catch (error) {
        console.error(`❌ Error sending anxiety notification to user ${alertData.userId}:`, error);
        return null;
    }
}
/**
 * Get user's FCM token for notifications
 * Checks both device-level and user-level token storage
 */
async function getUserFCMToken(userId, deviceId) {
    // First try device-level token (where Flutter app stores it)
    if (deviceId) {
        const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
        const deviceTokenSnapshot = await deviceTokenRef.once("value");
        if (deviceTokenSnapshot.exists()) {
            console.log(`✅ Found FCM token at device level: /devices/${deviceId}/fcmToken`);
            return deviceTokenSnapshot.val();
        }
    }
    // Fallback to user profile token
    const userTokenRef = db.ref(`/users/${userId}/fcmToken`);
    const tokenSnapshot = await userTokenRef.once("value");
    if (tokenSnapshot.exists()) {
        console.log(`✅ Found FCM token at user level: /users/${userId}/fcmToken`);
        return tokenSnapshot.val();
    }
    console.log(`⚠️ No FCM token found in Firebase for user ${userId}${deviceId ? ` or device ${deviceId}` : ''}`);
    return null;
}
/**
 * Get user-specific notification content based on severity
 */
function getUserNotificationContent(alertData) {
    const percentageText = `${Math.round(((alertData.heartRate - alertData.baseline) / alertData.baseline) * 100)}%`;
    switch (alertData.severity) {
        case "severe":
            return {
                title: "🚨 Severe Anxiety Detected",
                body: `Your heart rate was sustained at ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. Consider deep breathing exercises.`,
                color: "#FF0000",
            };
        case "moderate":
            return {
                title: "⚠️ Moderate Anxiety Detected",
                body: `Your heart rate was elevated to ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. Take a moment to relax.`,
                color: "#FF8C00",
            };
        case "mild":
            return {
                title: "📊 Mild Anxiety Detected",
                body: `Your heart rate increased to ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. Check in with yourself.`,
                color: "#FFA500",
            };
        default:
            return {
                title: "📊 Anxiety Alert",
                body: `Heart rate: ${alertData.heartRate} BPM`,
                color: "#4CAF50",
            };
    }
}
/**
 * Store anxiety alert in user's personal alert history
 */
async function storeUserAnxietyAlert(alertData) {
    const userAlertsRef = db.ref(`users/${alertData.userId}/alerts`).push();
    await userAlertsRef.set({
        sessionId: alertData.sessionId,
        deviceId: alertData.deviceId,
        severity: alertData.severity,
        heartRate: alertData.heartRate,
        baseline: alertData.baseline,
        duration: alertData.duration,
        reason: alertData.reason,
        timestamp: admin.database.ServerValue.TIMESTAMP,
        processed: true,
        source: "cloud_function_sustained_detection",
    });
    console.log(`📝 Stored user anxiety alert: ${userAlertsRef.key} for user ${alertData.userId}`);
}
/**
 * Get user's baseline heart rate
 */
async function getUserBaseline(userId, deviceId) {
    // Try to get baseline from device assignment (where it's actually stored)
    const deviceBaselineRef = db.ref(`/devices/${deviceId}/assignment/supabaseSync/baselineHR`);
    const baselineSnapshot = await deviceBaselineRef.once("value");
    if (baselineSnapshot.exists()) {
        const baselineHR = baselineSnapshot.val();
        console.log(`📊 Found user baseline: ${baselineHR} BPM from device assignment`);
        return { baselineHR: baselineHR };
    }
    // Fallback: try Firebase user profile
    const userBaselineRef = db.ref(`/users/${userId}/baseline/heartRate`);
    const userBaselineSnapshot = await userBaselineRef.once("value");
    if (userBaselineSnapshot.exists()) {
        const baselineHR = userBaselineSnapshot.val();
        console.log(`📊 Found user baseline: ${baselineHR} BPM from user profile`);
        return { baselineHR: baselineHR };
    }
    // For now, return a reasonable default based on age/demographics
    console.log(`⚠️ No baseline found for user ${userId}, using default 70 BPM`);
    return { baselineHR: 70 };
}
//# sourceMappingURL=realTimeSustainedAnxietyDetection.js.map