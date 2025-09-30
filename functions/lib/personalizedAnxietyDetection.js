"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPersonalizedNotificationContent = exports.getSeverityLevel = exports.calculatePersonalizedThresholds = exports.detectPersonalizedAnxiety = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const enhancedRateLimiting_1 = require("./enhancedRateLimiting");
const db = admin.database();
// FCM token retrieval function
async function getUserFCMToken(userId, deviceId) {
    // First try assignment-level token (primary location for shared devices)
    if (deviceId) {
        const assignmentTokenRef = db.ref(`/devices/${deviceId}/assignment/fcmToken`);
        const assignmentTokenSnapshot = await assignmentTokenRef.once("value");
        if (assignmentTokenSnapshot.exists()) {
            console.log(`✅ Found FCM token at assignment level: /devices/${deviceId}/assignment/fcmToken`);
            return assignmentTokenSnapshot.val();
        }
    }
    // Fallback to device-level token (legacy location)
    if (deviceId) {
        const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
        const deviceTokenSnapshot = await deviceTokenRef.once("value");
        if (deviceTokenSnapshot.exists()) {
            console.log(`✅ Found FCM token at device level: /devices/${deviceId}/fcmToken`);
            return deviceTokenSnapshot.val();
        }
    }
    // Final fallback to user profile token
    const userTokenRef = db.ref(`/users/${userId}/fcmToken`);
    const tokenSnapshot = await userTokenRef.once("value");
    if (tokenSnapshot.exists()) {
        console.log(`✅ Found FCM token at user level: /users/${userId}/fcmToken`);
        return tokenSnapshot.val();
    }
    console.log(`⚠️ No FCM token found in Firebase for user ${userId}${deviceId ? ` or device ${deviceId}` : ""}`);
    return null;
}
/**
 * Enhanced anxiety detection with personalized thresholds
 * Triggers when heart rate data is updated in Firebase RTDB
 */
exports.detectPersonalizedAnxiety = functions.database
    .ref("/devices/{deviceId}/current/heartRate")
    .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const newHeartRate = change.after.val();
    const oldHeartRate = change.before.val();
    if (!newHeartRate || typeof newHeartRate !== "number") {
        console.log("Invalid heart rate data, skipping");
        return null;
    }
    console.log(`Processing HR update for ${deviceId}: ${oldHeartRate} → ${newHeartRate}`);
    try {
        // Get device and user information
        const deviceData = await getDeviceInfo(deviceId);
        if (!deviceData || !deviceData.userId) {
            console.log(`No user associated with device ${deviceId}`);
            return null;
        }
        // Get user's personalized baseline and thresholds
        const userBaseline = await getUserBaseline(deviceData.userId, deviceId);
        if (!userBaseline) {
            console.log(`No baseline found for user ${deviceData.userId}, skipping anxiety detection - baseline required`);
            return null; // No detection without baseline
        }
        // Calculate personalized thresholds
        const thresholds = calculatePersonalizedThresholds(userBaseline.baselineHR);
        console.log(`User baseline: ${userBaseline.baselineHR}, Thresholds:`, thresholds);
        // Determine new and old severity levels
        const newSeverity = getSeverityLevel(newHeartRate, thresholds);
        const oldSeverity = getSeverityLevel(oldHeartRate || 0, thresholds);
        console.log(`Severity change: ${oldSeverity} → ${newSeverity}`);
        // Skip if severity hasn't changed or is normal
        if (newSeverity === oldSeverity || newSeverity === "normal") {
            console.log("No significant severity change, skipping notification");
            return null;
        }
        // Check enhanced rate limiting (considers user confirmations)
        if (await (0, enhancedRateLimiting_1.isRateLimitedWithConfirmation)(deviceData.userId, newSeverity)) {
            console.log("Rate limited (considering user confirmations), skipping notification");
            return null;
        }
        // Send personalized notification
        return await sendPersonalizedNotification({
            userId: deviceData.userId,
            deviceId: deviceId,
            heartRate: newHeartRate,
            baseline: userBaseline.baselineHR,
            severity: newSeverity,
            thresholds: thresholds,
        });
    }
    catch (error) {
        console.error("Error processing anxiety detection:", error);
        return null;
    }
});
/**
 * Get device information with userId for notifications
 */
async function getDeviceInfo(deviceId) {
    try {
        // First, check metadata path
        const metadataRef = db.ref(`devices/${deviceId}/metadata`);
        const metadataSnapshot = await metadataRef.once("value");
        if (metadataSnapshot.exists()) {
            const metadata = metadataSnapshot.val();
            if (metadata.userId) {
                return metadata;
            }
        }
        // If no userId in metadata, check assignment path (from Supabase webhook sync)
        const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
        const assignmentSnapshot = await assignmentRef.once("value");
        if (assignmentSnapshot.exists()) {
            const assignment = assignmentSnapshot.val();
            if (assignment.assignedUser) {
                return {
                    userId: assignment.assignedUser,
                    deviceId: deviceId,
                    source: "supabase_webhook_sync",
                };
            }
        }
        console.log(`⚠️ No user assigned to device ${deviceId}`);
        return null;
    }
    catch (error) {
        console.error("Error fetching device info:", error);
        return null;
    }
}
/**
 * Get user's baseline heart rate from Supabase
 */
async function getUserBaseline(userId, deviceId) {
    try {
        // In a real implementation, query Supabase:
        // SELECT * FROM baseline_heart_rates
        // WHERE user_id = ? AND device_id = ? AND is_active = true
        // ORDER BY created_at DESC LIMIT 1
        // For now, we'll store it in Firebase as a fallback
        const baselineRef = db.ref(`baselines/${userId}/${deviceId}`);
        const snapshot = await baselineRef.once("value");
        if (snapshot.exists()) {
            return snapshot.val();
        }
        return null;
    }
    catch (error) {
        console.error("Error fetching user baseline:", error);
        return null;
    }
}
/**
 * Calculate personalized thresholds based on user's baseline
 */
function calculatePersonalizedThresholds(baselineHR) {
    return {
        baseline: baselineHR,
        mild: baselineHR + 15,
        moderate: baselineHR + 25,
        severe: baselineHR + 35,
        // Additional thresholds for more granular detection
        elevated: baselineHR + 10,
        critical: baselineHR + 45, // +45 BPM (emergency)
    };
}
exports.calculatePersonalizedThresholds = calculatePersonalizedThresholds;
/**
 * Determine severity level based on heart rate and personalized thresholds
 */
function getSeverityLevel(heartRate, thresholds) {
    if (heartRate >= thresholds.critical)
        return "critical";
    if (heartRate >= thresholds.severe)
        return "severe";
    if (heartRate >= thresholds.moderate)
        return "moderate";
    if (heartRate >= thresholds.mild)
        return "mild";
    if (heartRate >= thresholds.elevated)
        return "elevated";
    return "normal";
}
exports.getSeverityLevel = getSeverityLevel;
// Rate limiting functionality moved to enhancedRateLimiting.ts
/**
 * Send personalized notification with baseline context
 */
async function sendPersonalizedNotification(data) {
    var _a;
    const { userId, deviceId, heartRate, baseline, severity, thresholds } = data;
    // Calculate percentage above baseline
    const percentageAbove = (((heartRate - baseline) / baseline) * 100).toFixed(0);
    const bpmAbove = (heartRate - baseline).toFixed(0);
    // Get user's FCM token (check assignment-level first, then fallbacks)
    const fcmToken = await getUserFCMToken(userId, deviceId);
    if (!fcmToken) {
        console.log(`⚠️ No FCM token found for user ${userId} in personalized detection`);
        return null;
    }
    const notificationContent = getPersonalizedNotificationContent(severity, heartRate, baseline, percentageAbove, bpmAbove);
    const message = {
        token: fcmToken,
        data: {
            type: "anxiety_alert_personalized",
            severity: severity,
            heartRate: heartRate.toString(),
            baseline: baseline.toString(),
            percentageAbove: percentageAbove,
            bpmAbove: bpmAbove,
            deviceId: deviceId,
            timestamp: Date.now().toString(),
        },
        notification: {
            title: notificationContent.title,
            body: notificationContent.body,
        },
        android: {
            priority: severity === "severe" || severity === "critical"
                ? "high"
                : "normal",
            notification: {
                channelId: getAndroidChannelId(severity),
                defaultSound: false,
                sound: getCustomSoundName(severity),
                defaultVibrateTimings: true,
                color: getNotificationColor(severity),
            },
        },
        apns: {
            payload: {
                aps: {
                    badge: 1,
                    sound: "default",
                },
            },
        },
    };
    try {
        await admin.messaging().send(message);
        console.log(`Personalized notification sent - ${severity}: ${heartRate} BPM (${bpmAbove} above baseline)`);
        // Update rate limit timestamp after successful notification
        await (0, enhancedRateLimiting_1.updateRateLimitTimestamp)(userId, severity);
        // Store alert in database
        await storeAlert(userId, deviceId, {
            heartRate,
            baseline,
            severity,
            percentageAbove: parseFloat(percentageAbove),
            bpmAbove: parseFloat(bpmAbove),
            thresholds,
        });
        return { success: true, severity, heartRate, baseline };
    }
    catch (error) {
        console.error("Error sending personalized notification:", error);
        const message = (_a = error === null || error === void 0 ? void 0 : error.message) !== null && _a !== void 0 ? _a : "Unknown error";
        return { success: false, error: message };
    }
}
/**
 * Get personalized notification content
 */
function getPersonalizedNotificationContent(severity, heartRate, baseline, percentageAbove, bpmAbove) {
    const templates = {
        elevated: {
            title: "Heart Rate Elevated",
            body: `Your heart rate is ${bpmAbove} BPM above your baseline (${heartRate} vs ${baseline} BPM). Take a moment to breathe.`,
        },
        mild: {
            title: "Mild Anxiety Detected",
            body: `Heart rate ${percentageAbove}% above baseline (${heartRate} BPM). Try some breathing exercises.`,
        },
        moderate: {
            title: "Moderate Anxiety Alert",
            body: `Heart rate significantly elevated: ${heartRate} BPM (${bpmAbove} above your baseline). Consider grounding techniques.`,
        },
        severe: {
            title: "High Anxiety Detected",
            body: `Heart rate very high: ${heartRate} BPM (${percentageAbove}% above baseline). Please use your coping strategies.`,
        },
        critical: {
            title: "Critical Alert",
            body: `Heart rate critically high: ${heartRate} BPM. Please seek immediate support if needed.`,
        },
    };
    return (templates[severity] ||
        templates.mild);
}
exports.getPersonalizedNotificationContent = getPersonalizedNotificationContent;
/**
 * Get Android channel ID based on severity
 */
function getAndroidChannelId(severity) {
    const channelMap = {
        mild: "mild_anxiety_alerts",
        moderate: "moderate_anxiety_alerts",
        severe: "severe_anxiety_alerts",
        critical: "critical_anxiety_alerts",
        elevated: "mild_anxiety_alerts",
    };
    return channelMap[severity] || "anxiety_alerts";
}
/**
 * Get custom sound name for Android notifications
 */
function getCustomSoundName(severity) {
    const soundMap = {
        mild: "mild_alert",
        moderate: "moderate_alert",
        severe: "severe_alert",
        critical: "critical_alert",
        elevated: "mild_alert",
    };
    return soundMap[severity] || "default";
}
/**
 * Get notification color based on severity
 */
function getNotificationColor(severity) {
    const colors = {
        elevated: "#FFA726",
        mild: "#66BB6A",
        moderate: "#FF9800",
        severe: "#F44336",
        critical: "#D32F2F", // Dark Red
    };
    return colors[severity] || colors.mild;
}
/**
 * Store alert in database for history tracking
 */
async function storeAlert(userId, deviceId, alertData) {
    try {
        const alertRef = db.ref(`alerts/${userId}/${deviceId}`).push();
        await alertRef.set(Object.assign(Object.assign({}, alertData), { timestamp: Date.now(), resolved: false }));
    }
    catch (error) {
        console.error("Error storing alert:", error);
    }
}
//# sourceMappingURL=personalizedAnxietyDetection.js.map