"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyTriggerLogic = exports.analyzeMovement = exports.analyzeSpO2 = exports.analyzeHeartRate = exports.analyzeMultiParameterAnxiety = exports.detectAnxietyMultiParameter = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
// Helper function to get severity-specific notification configuration
function getSeverityNotificationConfig(severity) {
    switch (severity.toLowerCase()) {
        case "mild":
            return {
                channelId: "mild_anxiety_alerts_v3",
                sound: "mild_alert",
                priority: "high",
                androidPriority: "max", // Use max priority for testing
            };
        case "moderate":
            return {
                channelId: "moderate_anxiety_alerts",
                sound: "moderate_alert",
                priority: "high",
                androidPriority: "high",
            };
        case "severe":
            return {
                channelId: "severe_anxiety_alerts",
                sound: "severe_alert",
                priority: "high",
                androidPriority: "max",
            };
        case "critical":
            return {
                channelId: "critical_anxiety_alerts",
                sound: "critical_alert",
                priority: "high",
                androidPriority: "max",
            };
        default:
            return {
                channelId: "anxiety_alerts",
                sound: "default",
                priority: "normal",
                androidPriority: "default",
            };
    }
}
// Helper function to map detection reason to severity level
function mapReasonToSeverity(reason, confidenceLevel) {
    // High confidence critical situations
    if (confidenceLevel >= 0.9) {
        switch (reason) {
            case "criticalSpO2":
            case "multipleMetrics":
                return "critical";
            case "combinedHRSpO2":
            case "combinedHRMovement":
            case "tremorDetected":
                return "severe";
            default:
                return "moderate";
        }
    }
    // Medium-high confidence
    if (confidenceLevel >= 0.7) {
        switch (reason) {
            case "criticalSpO2":
                return "severe";
            case "multipleMetrics":
            case "combinedHRSpO2":
            case "combinedHRMovement":
                return "moderate";
            default:
                return "mild";
        }
    }
    // Lower confidence
    return "mild";
}
/**
 * Multi-parameter anxiety detection Cloud Function
 * Triggers when any health metric is updated
 */
exports.detectAnxietyMultiParameter = functions.database
    .ref("/devices/{deviceId}/current")
    .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const afterData = change.after.val();
    const beforeData = change.before.val();
    console.log(`Processing metrics update for device ${deviceId}`);
    // Validate required data
    if (!afterData || !afterData.heartRate || !afterData.spo2) {
        console.log("Missing required metrics data, skipping");
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
        console.error("Error in multi-parameter anxiety detection:", error);
        return null;
    }
});
/**
 * Multi-parameter anxiety detection logic
 */
async function analyzeMultiParameterAnxiety(currentData, previousData, restingHR, userId, deviceId) {
    const currentHR = currentData.heartRate;
    const currentSpO2 = currentData.spo2;
    const bodyTemp = currentData.bodyTemp;
    // Extract accelerometer and gyroscope data (real field names from device)
    const accelX = currentData.accelX || 0;
    const accelY = currentData.accelY || 0;
    const accelZ = currentData.accelZ || 0;
    const gyroX = currentData.gyroX || 0;
    const gyroY = currentData.gyroY || 0;
    const gyroZ = currentData.gyroZ || 0;
    // Calculate movement intensity from accelerometer data
    const currentMovement = calculateMovementIntensity(accelX, accelY, accelZ);
    // Calculate gyroscope activity for tremor detection
    const gyroActivity = calculateGyroscopeActivity(gyroX, gyroY, gyroZ);
    console.log(`Analyzing metrics - HR: ${currentHR} (baseline: ${restingHR}), SpO2: ${currentSpO2}, Movement: ${currentMovement.toFixed(1)}, Gyro: ${gyroActivity.toFixed(1)}`);
    // Analyze each parameter
    const hrAnalysis = analyzeHeartRate(currentHR, restingHR, userId, deviceId);
    const spo2Analysis = analyzeSpO2(currentSpO2);
    const movementAnalysis = analyzeMovement(currentMovement, gyroActivity, currentHR, restingHR, userId, deviceId);
    // Count abnormal metrics
    const abnormalMetrics = {
        heartRate: hrAnalysis.isAbnormal,
        spO2: spo2Analysis.isAbnormal,
        movement: movementAnalysis.hasSpikes,
    };
    const abnormalCount = Object.values(abnormalMetrics).filter(Boolean).length;
    console.log(`Abnormal metrics count: ${abnormalCount}`, abnormalMetrics);
    // Apply enhanced trigger logic
    return applyTriggerLogic(hrAnalysis, spo2Analysis, movementAnalysis, abnormalCount, abnormalMetrics, {
        currentHR,
        restingHR,
        currentSpO2,
        currentMovement,
        bodyTemp,
    }, gyroActivity);
}
exports.analyzeMultiParameterAnxiety = analyzeMultiParameterAnxiety;
/**
 * Calculate movement intensity from accelerometer data
 */
function calculateMovementIntensity(accelX, accelY, accelZ) {
    // Calculate magnitude of acceleration vector
    const magnitude = Math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
    // Subtract gravity (approximately 9.8 m/s²) to get movement component
    const movementComponent = Math.abs(magnitude - 9.8);
    // Scale to 0-100 for easier interpretation (multiply by 10 for sensitivity)
    return Math.min(100, movementComponent * 10);
}
/**
 * Calculate gyroscope activity level for tremor/restlessness detection
 */
function calculateGyroscopeActivity(gyroX, gyroY, gyroZ) {
    // Calculate magnitude of rotational velocity
    const magnitude = Math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
    // Scale to 0-100 (multiply by 100 for sensitivity as gyro values are typically small)
    return Math.min(100, magnitude * 100);
}
/**
 * Detect if current movement pattern indicates exercise
 */
function isExercisePattern(movementIntensity, gyroActivity, heartRate, restingHR) {
    const hrElevation = (heartRate - restingHR) / restingHR;
    // Exercise typically shows:
    // - Sustained high movement (>30)
    // - Moderate to high heart rate elevation (>20%)
    // - Relatively steady gyroscope activity (not erratic)
    const sustainedMovement = movementIntensity > 30;
    const moderateHRIncrease = hrElevation > 0.2 && hrElevation < 0.8; // 20-80% increase
    const steadyActivity = gyroActivity < 50; // Not too erratic
    return sustainedMovement && moderateHRIncrease && steadyActivity;
}
/**
 * Detect tremor patterns from gyroscope data
 */
function isTremorPattern(gyroActivity, movementIntensity) {
    // Tremors typically show:
    // - High gyroscope activity (rapid rotational changes)
    // - Low to moderate movement intensity (small but rapid movements)
    const highGyroActivity = gyroActivity > 40;
    const lowToModerateMovement = movementIntensity > 5 && movementIntensity < 30;
    return highGyroActivity && lowToModerateMovement;
}
function analyzeHeartRate(currentHR, restingHR, userId, deviceId) {
    const percentageAbove = (currentHR - restingHR) / restingHR;
    const isHigh = percentageAbove >= 0.2; // 20% above resting
    const isVeryHigh = percentageAbove >= 0.3; // 30% above resting
    const isLow = currentHR < 50; // Unusually low
    // Check if sustained (would need historical data in real implementation)
    const sustainedFor30Seconds = true; // Placeholder - implement historical check
    return {
        isAbnormal: (isHigh || isLow) && sustainedFor30Seconds,
        type: isVeryHigh ? "veryHigh" : isHigh ? "high" : isLow ? "low" : "normal",
        percentageAbove: percentageAbove * 100,
        sustainedFor30Seconds,
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
        severity: isCritical ? "critical" : isLow ? "low" : "normal",
        requiresConfirmation: isLow && !isCritical,
    };
}
exports.analyzeSpO2 = analyzeSpO2;
/**
 * Analyze enhanced movement patterns with accelerometer/gyroscope data
 */
function analyzeMovement(currentMovement, gyroActivity, heartRate, restingHR, userId, deviceId) {
    // Enhanced movement analysis using real sensor data
    // Detect sudden movement spikes (potential anxiety indicator)
    const hasSpikes = currentMovement > 40; // Threshold for movement spikes
    // Check for tremor patterns (high gyro activity + moderate movement)
    const tremorDetected = isTremorPattern(gyroActivity, currentMovement);
    // Check if this looks like exercise (should prevent false anxiety alerts)
    const exerciseDetected = isExercisePattern(currentMovement, gyroActivity, heartRate, restingHR);
    // Anxiety indicators:
    // - High heart rate with low movement (resting anxiety)
    // - Tremor patterns detected
    // - Movement spikes without exercise pattern
    const restingAnxiety = heartRate > restingHR * 1.2 && currentMovement < 15;
    const indicatesAnxiety = tremorDetected || (hasSpikes && !exerciseDetected) || restingAnxiety;
    console.log(`Movement analysis - Movement: ${currentMovement.toFixed(1)}, Gyro: ${gyroActivity.toFixed(1)}, Exercise: ${exerciseDetected}, Tremor: ${tremorDetected}, Anxiety: ${indicatesAnxiety}`);
    return {
        hasSpikes,
        indicatesAnxiety,
        intensity: currentMovement,
    };
}
exports.analyzeMovement = analyzeMovement;
/**
 * Apply enhanced trigger logic with exercise detection
 */
function applyTriggerLogic(hrAnalysis, spo2Analysis, movementAnalysis, abnormalCount, abnormalMetrics, metrics, gyroActivity) {
    let triggered = false;
    let reason = "normal";
    let confidenceLevel = 0.0;
    let requiresUserConfirmation = false;
    // Check if this appears to be exercise first (prevents false alarms)
    const exerciseDetected = isExercisePattern(metrics.currentMovement, gyroActivity, metrics.currentHR, metrics.restingHR);
    // Check for tremor patterns (anxiety indicator)
    const tremorDetected = isTremorPattern(gyroActivity, metrics.currentMovement);
    console.log(`Applying trigger logic - abnormal count: ${abnormalCount}, exercise: ${exerciseDetected}, tremor: ${tremorDetected}`);
    // If exercise is detected, reduce likelihood of anxiety alert (unless other critical signs)
    if (exerciseDetected && !spo2Analysis.isAbnormal) {
        console.log("Exercise pattern detected - suppressing anxiety alert unless critical");
        return {
            triggered: false,
            reason: "exerciseDetected",
            confidenceLevel: 0.1,
            requiresUserConfirmation: false,
            abnormalMetrics,
            metrics: Object.assign(Object.assign({}, metrics), { percentageAboveResting: hrAnalysis.percentageAbove, sustainedHR: hrAnalysis.sustainedFor30Seconds }),
        };
    }
    // Critical SpO2 - Always trigger immediately (even during exercise)
    if (spo2Analysis.severity === "critical") {
        triggered = true;
        reason = "criticalSpO2";
        confidenceLevel = 1.0;
        requiresUserConfirmation = false;
    }
    // Multiple metrics abnormal - High confidence trigger
    else if (abnormalCount >= 2) {
        triggered = true;
        confidenceLevel = 0.85 + (abnormalCount - 2) * 0.1; // 0.85-1.0
        // Check if this falls into mild/moderate levels for confirmation requirement
        const hrElevation = metrics.currentHR - metrics.restingHR;
        const isMildLevel = hrElevation >= 15 && hrElevation < 25; // +15 to +24 BPM
        const isModerateLevel = hrElevation >= 25 && hrElevation < 35; // +25 to +34 BPM
        // ALWAYS require confirmation for mild and moderate levels, even with multiple metrics
        requiresUserConfirmation = isMildLevel || isModerateLevel;
        if (hrAnalysis.isAbnormal && movementAnalysis.hasSpikes) {
            reason = "combinedHRMovement";
            confidenceLevel = Math.min(1.0, confidenceLevel + 0.1); // Extra confidence for this combo
        }
        else if (hrAnalysis.isAbnormal && spo2Analysis.isAbnormal) {
            reason = "combinedHRSpO2";
        }
        else if (spo2Analysis.isAbnormal && movementAnalysis.hasSpikes) {
            reason = "combinedSpO2Movement";
        }
        else {
            reason = "multipleMetrics";
        }
    }
    // Tremor detection - Special case for anxiety
    else if (tremorDetected) {
        triggered = true;
        reason = "tremorDetected";
        confidenceLevel = 0.8; // High confidence for tremors
        // Check severity level even for tremors
        const hrElevation = metrics.currentHR - metrics.restingHR;
        const isMildLevel = hrElevation >= 15 && hrElevation < 25; // +15 to +24 BPM
        const isModerateLevel = hrElevation >= 25 && hrElevation < 35; // +25 to +34 BPM
        // ALWAYS require confirmation for mild and moderate levels, even for tremors
        requiresUserConfirmation = isMildLevel || isModerateLevel;
        console.log("Tremor pattern detected - likely anxiety");
    }
    // Single metric abnormal - Request confirmation
    else if (abnormalCount === 1) {
        triggered = true;
        confidenceLevel = 0.6;
        requiresUserConfirmation = true;
        if (hrAnalysis.isAbnormal) {
            reason =
                hrAnalysis.type === "high" || hrAnalysis.type === "veryHigh"
                    ? "highHR"
                    : "lowHR";
            // Increase confidence for very high HR (but not during exercise)
            if (hrAnalysis.type === "veryHigh") {
                confidenceLevel = 0.75;
            }
            // Calculate severity level for confirmation requirements
            const hrElevation = metrics.currentHR - metrics.restingHR;
            const isMildLevel = hrElevation >= 15 && hrElevation < 25; // +15 to +24 BPM
            const isModerateLevel = hrElevation >= 25 && hrElevation < 35; // +25 to +34 BPM
            // Special case: High HR while resting (very likely anxiety)
            if (metrics.currentMovement < 15 && hrAnalysis.type === "high") {
                confidenceLevel = 0.85;
                // ALWAYS require confirmation for mild and moderate levels
                if (isMildLevel || isModerateLevel) {
                    requiresUserConfirmation = true;
                    console.log(`${isMildLevel ? "Mild" : "Moderate"} anxiety level detected - requesting user confirmation`);
                }
                else {
                    requiresUserConfirmation = false;
                }
                reason = "highHR";
                console.log("High heart rate while resting - likely anxiety");
            }
        }
        else if (spo2Analysis.isAbnormal) {
            reason = "lowSpO2";
        }
        else if (movementAnalysis.hasSpikes) {
            reason = "movementSpikes";
        }
    }
    // Boost confidence if movement indicates anxiety patterns (but not exercise)
    if (movementAnalysis.indicatesAnxiety && triggered && !exerciseDetected) {
        confidenceLevel = Math.min(1.0, confidenceLevel + 0.15);
        console.log("Anxiety movement patterns detected - boosting confidence");
    }
    return {
        triggered,
        reason,
        confidenceLevel: Math.round(confidenceLevel * 100) / 100,
        requiresUserConfirmation,
        abnormalMetrics,
        metrics: Object.assign(Object.assign({}, metrics), { percentageAboveResting: hrAnalysis.percentageAbove, sustainedHR: hrAnalysis.sustainedFor30Seconds }),
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
        console.error("Error handling anxiety detection:", error);
        const message = (_a = error === null || error === void 0 ? void 0 : error.message) !== null && _a !== void 0 ? _a : "Unknown error";
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
    // Map reason and confidence to severity level for proper notification channel
    const severity = mapReasonToSeverity(result.reason, result.confidenceLevel);
    const notificationConfig = getSeverityNotificationConfig(severity);
    const message = {
        data: {
            type: "anxiety_alert_multiparameter",
            reason: result.reason,
            severity: severity,
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
            priority: notificationConfig.priority,
            notification: {
                channelId: notificationConfig.channelId,
                priority: notificationConfig.androidPriority,
                defaultSound: false,
                sound: notificationConfig.sound,
                defaultVibrateTimings: true,
                color: getNotificationColor(result.reason),
            },
        },
        topic: `user_${userId}`,
    };
    await admin.messaging().send(message);
    console.log(`Anxiety notification sent: ${result.reason} -> ${severity} severity (confidence: ${result.confidenceLevel})`);
}
/**
 * Send confirmation request notification
 */
async function sendConfirmationRequest(result, userId, deviceId) {
    const message = {
        data: {
            type: "anxiety_confirmation_request",
            reason: result.reason,
            confidence: result.confidenceLevel.toString(),
            heartRate: result.metrics.currentHR.toString(),
            spO2: result.metrics.currentSpO2.toString(),
            movement: result.metrics.currentMovement.toString(),
            deviceId: deviceId,
            timestamp: Date.now().toString(),
        },
        notification: {
            title: "Are you feeling anxious?",
            body: `We detected some changes in your vitals (${result.reason}). Tap to confirm or dismiss.`,
        },
        topic: `user_${userId}`,
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
            title: "Critical Alert: Low Oxygen",
            body: `Your blood oxygen level is critically low (${result.metrics.currentSpO2}%). Please seek immediate medical attention if you feel unwell.`,
        },
        combinedHRMovement: {
            title: "Anxiety Alert: Heart Rate + Movement",
            body: `Elevated heart rate (${result.metrics.currentHR} BPM) and unusual movement detected. Try your breathing exercises.`,
        },
        combinedHRSpO2: {
            title: "Anxiety Alert: Heart Rate + Oxygen",
            body: `High heart rate (${result.metrics.currentHR} BPM) and low oxygen (${result.metrics.currentSpO2}%) detected.`,
        },
        highHR: {
            title: "High Heart Rate Detected",
            body: `Your heart rate is elevated (${result.metrics.currentHR} BPM, ${((_a = result.metrics.percentageAboveResting) !== null && _a !== void 0 ? _a : 0).toFixed(0)}% above baseline). Consider using relaxation techniques.`,
        },
        lowHR: {
            title: "Unusually Low Heart Rate",
            body: `Your heart rate is unusually low (${result.metrics.currentHR} BPM). Please monitor how you feel.`,
        },
        lowSpO2: {
            title: "Low Oxygen Levels",
            body: `Your oxygen levels are below normal (${result.metrics.currentSpO2}%). Are you feeling okay?`,
        },
        movementSpikes: {
            title: "Unusual Movement Detected",
            body: "We detected some unusual movement patterns. Are you experiencing anxiety or restlessness?",
        },
    };
    return (templates[result.reason] || {
        title: "Anxiety Alert",
        body: "We detected some changes that might indicate anxiety. Take a moment to check in with yourself.",
    });
}
/**
 * Get notification color based on reason
 */
function getNotificationColor(reason) {
    const colors = {
        criticalSpO2: "#D32F2F",
        combinedHRMovement: "#F44336",
        combinedHRSpO2: "#F44336",
        highHR: "#FF9800",
        lowHR: "#FF5722",
        lowSpO2: "#9C27B0",
        movementSpikes: "#FFC107", // Amber
    };
    return colors[reason] || "#2196F3"; // Blue default
}
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
        // If no userId in metadata, check assignment path (from webhook sync)
        const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
        const assignmentSnapshot = await assignmentRef.once("value");
        if (assignmentSnapshot.exists()) {
            const assignment = assignmentSnapshot.val();
            if (assignment.assignedUser) {
                return {
                    userId: assignment.assignedUser,
                    deviceId: deviceId,
                    source: "assignment_sync",
                };
            }
        }
        console.log(`⚠️ No user assigned to device ${deviceId} in either metadata or assignment`);
        return null;
    }
    catch (error) {
        console.error("Error fetching device info:", error);
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
        const snapshot = await baselineRef.once("value");
        return snapshot.exists() ? snapshot.val() : null;
    }
    catch (error) {
        console.error("Error fetching baseline:", error);
        return null;
    }
}
//# sourceMappingURL=multiParameterAnxietyDetection.js.map