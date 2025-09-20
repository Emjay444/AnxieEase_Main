"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyTriggerLogic = exports.analyzeMovement = exports.analyzeSpO2 = exports.analyzeHeartRate = exports.analyzeMultiParameterAnxiety = exports.detectAnxietyMultiParameter = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
/**
 * Multi-parameter anxiety detection Cloud Function
 * Triggers when any health metric is updated
 */
exports.detectAnxietyMultiParameter = functions.database
    .ref('/devices/{deviceId}/current')
    .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const afterData = change.after.val();
    const beforeData = change.before.val();
    console.log(`Processing metrics update for device ${deviceId}`);
    // Validate required data
    if (!afterData || !afterData.heartRate || !afterData.spo2) {
        console.log('Missing required metrics data, skipping');
        return null;
    }
    try {
        // Get device and user information
        const deviceInfo = await getDeviceInfo(deviceId);
        if (!deviceInfo || !deviceInfo.userId) {
            console.log(`No user associated with device ${deviceId}`);
            return null;
        }
        // Get user's baseline
        const baseline = await getUserBaseline(deviceInfo.userId, deviceId);
        if (!baseline) {
            console.log(`No baseline found for user ${deviceInfo.userId}`);
            return null;
        }
        // Run multi-parameter anxiety detection
        const result = await analyzeMultiParameterAnxiety(afterData, beforeData, baseline.baselineHR, deviceInfo.userId, deviceId);
        if (result.triggered) {
            console.log(`Anxiety detected: ${result.reason} (confidence: ${result.confidenceLevel})`);
            return await handleAnxietyDetection(result, deviceInfo.userId, deviceId);
        }
        return null;
    }
    catch (error) {
        console.error('Error in multi-parameter anxiety detection:', error);
        return null;
    }
});
/**
 * Multi-parameter anxiety detection logic
 */
async function analyzeMultiParameterAnxiety(currentData, previousData, restingHR, userId, deviceId) {
    const currentHR = currentData.heartRate;
    const currentSpO2 = currentData.spo2;
    const currentMovement = currentData.movementLevel || 0;
    const bodyTemp = currentData.bodyTemp;
    console.log(`Analyzing metrics - HR: ${currentHR} (baseline: ${restingHR}), SpO2: ${currentSpO2}, Movement: ${currentMovement}`);
    // Analyze each parameter
    const hrAnalysis = analyzeHeartRate(currentHR, restingHR, userId, deviceId);
    const spo2Analysis = analyzeSpO2(currentSpO2);
    const movementAnalysis = analyzeMovement(currentMovement, userId, deviceId);
    // Count abnormal metrics
    const abnormalMetrics = {
        heartRate: hrAnalysis.isAbnormal,
        spO2: spo2Analysis.isAbnormal,
        movement: movementAnalysis.hasSpikes
    };
    const abnormalCount = Object.values(abnormalMetrics).filter(Boolean).length;
    console.log(`Abnormal metrics count: ${abnormalCount}`, abnormalMetrics);
    // Apply trigger logic
    return applyTriggerLogic(hrAnalysis, spo2Analysis, movementAnalysis, abnormalCount, abnormalMetrics, {
        currentHR,
        restingHR,
        currentSpO2,
        currentMovement,
        bodyTemp
    });
}
exports.analyzeMultiParameterAnxiety = analyzeMultiParameterAnxiety;
function analyzeHeartRate(currentHR, restingHR, userId, deviceId) {
    const percentageAbove = ((currentHR - restingHR) / restingHR);
    const isHigh = percentageAbove >= 0.20; // 20% above resting
    const isVeryHigh = percentageAbove >= 0.30; // 30% above resting
    const isLow = currentHR < 50; // Unusually low
    // Check if sustained (would need historical data in real implementation)
    const sustainedFor30Seconds = true; // Placeholder - implement historical check
    return {
        isAbnormal: (isHigh || isLow) && sustainedFor30Seconds,
        type: isVeryHigh ? 'veryHigh' : (isHigh ? 'high' : (isLow ? 'low' : 'normal')),
        percentageAbove: percentageAbove * 100,
        sustainedFor30Seconds
    };
}
exports.analyzeHeartRate = analyzeHeartRate;
/**
 * Analyze SpO2 levels
 */
function analyzeSpO2(currentSpO2) {
    const isCritical = currentSpO2 < 90; // Critical level
    const isLow = currentSpO2 < 94; // Low level requiring confirmation
    return {
        isAbnormal: isLow || isCritical,
        severity: isCritical ? 'critical' : (isLow ? 'low' : 'normal'),
        requiresConfirmation: isLow && !isCritical
    };
}
exports.analyzeSpO2 = analyzeSpO2;
/**
 * Analyze movement patterns
 */
function analyzeMovement(currentMovement, userId, deviceId) {
    // In real implementation, would analyze historical movement data
    const hasSpikes = currentMovement > 50; // Simplified spike detection
    const indicatesAnxiety = currentMovement > 70; // High sustained movement
    return {
        hasSpikes,
        indicatesAnxiety,
        intensity: currentMovement
    };
}
exports.analyzeMovement = analyzeMovement;
/**
 * Apply trigger logic based on all analyses
 */
function applyTriggerLogic(hrAnalysis, spo2Analysis, movementAnalysis, abnormalCount, abnormalMetrics, metrics) {
    let triggered = false;
    let reason = 'normal';
    let confidenceLevel = 0.0;
    let requiresUserConfirmation = false;
    console.log(`Applying trigger logic - abnormal count: ${abnormalCount}`);
    // Critical SpO2 - Always trigger immediately
    if (spo2Analysis.severity === 'critical') {
        triggered = true;
        reason = 'criticalSpO2';
        confidenceLevel = 1.0;
        requiresUserConfirmation = false;
    }
    // Multiple metrics abnormal - High confidence trigger  
    else if (abnormalCount >= 2) {
        triggered = true;
        confidenceLevel = 0.85 + (abnormalCount - 2) * 0.1; // 0.85-1.0
        requiresUserConfirmation = false;
        if (hrAnalysis.isAbnormal && movementAnalysis.hasSpikes) {
            reason = 'combinedHRMovement';
            confidenceLevel = Math.min(1.0, confidenceLevel + 0.1); // Extra confidence for this combo
        }
        else if (hrAnalysis.isAbnormal && spo2Analysis.isAbnormal) {
            reason = 'combinedHRSpO2';
        }
        else if (spo2Analysis.isAbnormal && movementAnalysis.hasSpikes) {
            reason = 'combinedSpO2Movement';
        }
        else {
            reason = 'multipleMetrics';
        }
    }
    // Single metric abnormal - Request confirmation
    else if (abnormalCount === 1) {
        triggered = true;
        confidenceLevel = 0.6;
        requiresUserConfirmation = true;
        if (hrAnalysis.isAbnormal) {
            reason = hrAnalysis.type === 'high' || hrAnalysis.type === 'veryHigh' ? 'highHR' : 'lowHR';
            // Increase confidence for very high HR
            if (hrAnalysis.type === 'veryHigh') {
                confidenceLevel = 0.75;
            }
        }
        else if (spo2Analysis.isAbnormal) {
            reason = 'lowSpO2';
        }
        else if (movementAnalysis.hasSpikes) {
            reason = 'movementSpikes';
        }
    }
    // Boost confidence if movement indicates anxiety patterns
    if (movementAnalysis.indicatesAnxiety && triggered) {
        confidenceLevel = Math.min(1.0, confidenceLevel + 0.1);
    }
    return {
        triggered,
        reason,
        confidenceLevel: Math.round(confidenceLevel * 100) / 100,
        requiresUserConfirmation,
        abnormalMetrics,
        metrics: Object.assign(Object.assign({}, metrics), { percentageAboveResting: hrAnalysis.percentageAbove, sustainedHR: hrAnalysis.sustainedFor30Seconds })
    };
}
exports.applyTriggerLogic = applyTriggerLogic;
/**
 * Handle anxiety detection result
 */
async function handleAnxietyDetection(result, userId, deviceId) {
    var _a;
    const timestamp = Date.now();
    try {
        // Store the detection result
        await storeAnxietyDetection(result, userId, deviceId, timestamp);
        // Send notification based on confidence and confirmation requirement
        if (!result.requiresUserConfirmation || result.confidenceLevel >= 0.8) {
            await sendAnxietyNotification(result, userId, deviceId);
        }
        else {
            await sendConfirmationRequest(result, userId, deviceId);
        }
        return { success: true, result };
    }
    catch (error) {
        console.error('Error handling anxiety detection:', error);
        const message = (_a = error === null || error === void 0 ? void 0 : error.message) !== null && _a !== void 0 ? _a : 'Unknown error';
        return { success: false, error: message };
    }
}
/**
 * Store anxiety detection result
 */
async function storeAnxietyDetection(result, userId, deviceId, timestamp) {
    const alertRef = db.ref(`anxiety_detections/${userId}/${deviceId}/${timestamp}`);
    await alertRef.set(Object.assign(Object.assign({}, result), { timestamp,
        userId,
        deviceId, resolved: false }));
    console.log(`Stored anxiety detection: ${result.reason}`);
}
/**
 * Send anxiety notification
 */
async function sendAnxietyNotification(result, userId, deviceId) {
    const notificationContent = getNotificationContent(result);
    const message = {
        data: {
            type: 'anxiety_alert_multiparameter',
            reason: result.reason,
            confidence: result.confidenceLevel.toString(),
            heartRate: result.metrics.currentHR.toString(),
            baselineHR: result.metrics.restingHR.toString(),
            spO2: result.metrics.currentSpO2.toString(),
            movement: result.metrics.currentMovement.toString(),
            deviceId: deviceId,
            timestamp: Date.now().toString(),
        },
        notification: {
            title: notificationContent.title,
            body: notificationContent.body,
        },
        android: {
            priority: (result.confidenceLevel >= 0.8 ? 'high' : 'normal'),
            notification: {
                channelId: 'anxiety_alerts',
                // Admin SDK types don't include AndroidNotification.priority in some versions; omit to avoid type errors
                defaultSound: true,
                defaultVibrateTimings: true,
                color: getNotificationColor(result.reason),
            },
        },
        topic: `user_${userId}`
    };
    await admin.messaging().send(message);
    console.log(`Anxiety notification sent: ${result.reason} (confidence: ${result.confidenceLevel})`);
}
/**
 * Send confirmation request notification
 */
async function sendConfirmationRequest(result, userId, deviceId) {
    const message = {
        data: {
            type: 'anxiety_confirmation_request',
            reason: result.reason,
            confidence: result.confidenceLevel.toString(),
            heartRate: result.metrics.currentHR.toString(),
            spO2: result.metrics.currentSpO2.toString(),
            movement: result.metrics.currentMovement.toString(),
            deviceId: deviceId,
            timestamp: Date.now().toString(),
        },
        notification: {
            title: 'Are you feeling anxious?',
            body: `We detected some changes in your vitals (${result.reason}). Tap to confirm or dismiss.`,
        },
        topic: `user_${userId}`
    };
    await admin.messaging().send(message);
    console.log(`Confirmation request sent: ${result.reason}`);
}
/**
 * Get notification content based on detection result
 */
function getNotificationContent(result) {
    var _a;
    const templates = {
        criticalSpO2: {
            title: 'Critical Alert: Low Oxygen',
            body: `Your blood oxygen level is critically low (${result.metrics.currentSpO2}%). Please seek immediate medical attention if you feel unwell.`
        },
        combinedHRMovement: {
            title: 'Anxiety Alert: Heart Rate + Movement',
            body: `Elevated heart rate (${result.metrics.currentHR} BPM) and unusual movement detected. Try your breathing exercises.`
        },
        combinedHRSpO2: {
            title: 'Anxiety Alert: Heart Rate + Oxygen',
            body: `High heart rate (${result.metrics.currentHR} BPM) and low oxygen (${result.metrics.currentSpO2}%) detected.`
        },
        highHR: {
            title: 'High Heart Rate Detected',
            body: `Your heart rate is elevated (${result.metrics.currentHR} BPM, ${(((_a = result.metrics.percentageAboveResting) !== null && _a !== void 0 ? _a : 0)).toFixed(0)}% above baseline). Consider using relaxation techniques.`
        },
        lowHR: {
            title: 'Unusually Low Heart Rate',
            body: `Your heart rate is unusually low (${result.metrics.currentHR} BPM). Please monitor how you feel.`
        },
        lowSpO2: {
            title: 'Low Oxygen Levels',
            body: `Your oxygen levels are below normal (${result.metrics.currentSpO2}%). Are you feeling okay?`
        },
        movementSpikes: {
            title: 'Unusual Movement Detected',
            body: 'We detected some unusual movement patterns. Are you experiencing anxiety or restlessness?'
        }
    };
    return templates[result.reason] || {
        title: 'Anxiety Alert',
        body: 'We detected some changes that might indicate anxiety. Take a moment to check in with yourself.'
    };
}
/**
 * Get notification color based on reason
 */
function getNotificationColor(reason) {
    const colors = {
        criticalSpO2: '#D32F2F',
        combinedHRMovement: '#F44336',
        combinedHRSpO2: '#F44336',
        highHR: '#FF9800',
        lowHR: '#FF5722',
        lowSpO2: '#9C27B0',
        movementSpikes: '#FFC107' // Amber
    };
    return colors[reason] || '#2196F3'; // Blue default
}
/**
 * Get device information
 */
async function getDeviceInfo(deviceId) {
    try {
        const deviceRef = db.ref(`devices/${deviceId}/metadata`);
        const snapshot = await deviceRef.once('value');
        return snapshot.exists() ? snapshot.val() : null;
    }
    catch (error) {
        console.error('Error fetching device info:', error);
        return null;
    }
}
/**
 * Get user baseline
 */
async function getUserBaseline(userId, deviceId) {
    try {
        // In real implementation, query Supabase here
        const baselineRef = db.ref(`baselines/${userId}/${deviceId}`);
        const snapshot = await baselineRef.once('value');
        return snapshot.exists() ? snapshot.val() : null;
    }
    catch (error) {
        console.error('Error fetching baseline:', error);
        return null;
    }
}
//# sourceMappingURL=multiParameterAnxietyDetection.js.map