"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPersonalizedNotificationContent = exports.getSeverityLevel = exports.calculatePersonalizedThresholds = exports.detectPersonalizedAnxiety = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
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
        // Check rate limiting
        if (await isRateLimited(deviceData.userId, newSeverity)) {
            console.log("Rate limited, skipping notification");
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
 * Get device information from Supabase
 */
async function getDeviceInfo(deviceId) {
    try {
        // In a real implementation, you'd query Supabase here
        // For now, we'll get it from Firebase device metadata
        const deviceRef = db.ref(`devices/${deviceId}/metadata`);
        const snapshot = await deviceRef.once("value");
        if (snapshot.exists()) {
            return snapshot.val();
        }
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
/**
 * Check if notifications are rate-limited for this user
 */
async function isRateLimited(userId, severity) {
    const now = Date.now();
    const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
    const snapshot = await rateLimitRef.once("value");
    const limits = {
        mild: 300000,
        moderate: 180000,
        severe: 60000,
        critical: 30000, // 30 seconds
    };
    const limit = limits[severity] || 300000;
    if (snapshot.exists()) {
        const lastNotification = snapshot.val();
        if (now - lastNotification < limit) {
            return true;
        }
    }
    // Update rate limit timestamp
    await rateLimitRef.set(now);
    return false;
}
/**
 * Send personalized notification with baseline context
 */
async function sendPersonalizedNotification(data) {
    var _a;
    const { userId, deviceId, heartRate, baseline, severity, thresholds } = data;
    // Calculate percentage above baseline
    const percentageAbove = (((heartRate - baseline) / baseline) * 100).toFixed(0);
    const bpmAbove = (heartRate - baseline).toFixed(0);
    const notificationContent = getPersonalizedNotificationContent(severity, heartRate, baseline, percentageAbove, bpmAbove);
    const message = {
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
                channelId: "anxiety_alerts",
                // omit notification.priority to avoid type incompatibilities across SDK versions
                defaultSound: true,
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
        topic: `user_${userId}`,
    };
    try {
        await admin.messaging().send(message);
        console.log(`Personalized notification sent - ${severity}: ${heartRate} BPM (${bpmAbove} above baseline)`);
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