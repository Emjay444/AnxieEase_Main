import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.database();

/**
 * Multi-parameter anxiety detection Cloud Function
 * Triggers when any health metric is updated
 */
export const detectAnxietyMultiParameter = functions.database
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
      const result = await analyzeMultiParameterAnxiety(
        afterData,
        beforeData,
        baseline.baselineHR,
        deviceInfo.userId,
        deviceId
      );

      if (result.triggered) {
        console.log(
          `Anxiety detected: ${result.reason} (confidence: ${result.confidenceLevel})`
        );
        return await handleAnxietyDetection(
          result,
          deviceInfo.userId,
          deviceId
        );
      }

      return null;
    } catch (error) {
      console.error("Error in multi-parameter anxiety detection:", error);
      return null;
    }
  });

/**
 * Multi-parameter anxiety detection logic
 */
async function analyzeMultiParameterAnxiety(
  currentData: any,
  previousData: any,
  restingHR: number,
  userId: string,
  deviceId: string
) {
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

  console.log(
    `Analyzing metrics - HR: ${currentHR} (baseline: ${restingHR}), SpO2: ${currentSpO2}, Movement: ${currentMovement.toFixed(1)}, Gyro: ${gyroActivity.toFixed(1)}`
  );

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
  return applyTriggerLogic(
    hrAnalysis,
    spo2Analysis,
    movementAnalysis,
    abnormalCount,
    abnormalMetrics,
    {
      currentHR,
      restingHR,
      currentSpO2,
      currentMovement,
      bodyTemp,
    },
    gyroActivity
  );
}

/**
 * Analyze heart rate patterns
 */
type HRAnalysis = {
  isAbnormal: boolean;
  type: "veryHigh" | "high" | "low" | "normal";
  percentageAbove: number; // percent
  sustainedFor30Seconds: boolean;
};

type SpO2Analysis = {
  isAbnormal: boolean;
  severity: "critical" | "low" | "normal";
  requiresConfirmation: boolean;
};

type MovementAnalysis = {
  hasSpikes: boolean;
  indicatesAnxiety: boolean;
  intensity: number;
};

type AbnormalMetrics = { heartRate: boolean; spO2: boolean; movement: boolean };

type DetectionMetrics = {
  currentHR: number;
  restingHR: number;
  currentSpO2: number;
  currentMovement: number;
  bodyTemp?: number;
  percentageAboveResting?: number;
  sustainedHR?: boolean;
};

type DetectionResult = {
  triggered: boolean;
  reason:
    | "criticalSpO2"
    | "combinedHRMovement"
    | "combinedHRSpO2"
    | "combinedSpO2Movement"
    | "multipleMetrics"
    | "highHR"
    | "lowHR"
    | "lowSpO2"
    | "movementSpikes"
    | "exerciseDetected"
    | "tremorDetected"
    | "normal"
    | string;
  confidenceLevel: number; // 0-1
  requiresUserConfirmation: boolean;
  abnormalMetrics: AbnormalMetrics;
  metrics: DetectionMetrics;
};

/**
 * Calculate movement intensity from accelerometer data
 */
function calculateMovementIntensity(accelX: number, accelY: number, accelZ: number): number {
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
function calculateGyroscopeActivity(gyroX: number, gyroY: number, gyroZ: number): number {
  // Calculate magnitude of rotational velocity
  const magnitude = Math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
  
  // Scale to 0-100 (multiply by 100 for sensitivity as gyro values are typically small)
  return Math.min(100, magnitude * 100);
}

/**
 * Detect if current movement pattern indicates exercise
 */
function isExercisePattern(movementIntensity: number, gyroActivity: number, heartRate: number, restingHR: number): boolean {
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
function isTremorPattern(gyroActivity: number, movementIntensity: number): boolean {
  // Tremors typically show:
  // - High gyroscope activity (rapid rotational changes)
  // - Low to moderate movement intensity (small but rapid movements)
  
  const highGyroActivity = gyroActivity > 40;
  const lowToModerateMovement = movementIntensity > 5 && movementIntensity < 30;
  
  return highGyroActivity && lowToModerateMovement;
}

function analyzeHeartRate(
  currentHR: number,
  restingHR: number,
  userId: string,
  deviceId: string
): HRAnalysis {
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

/**
 * Analyze SpO2 levels
 */
function analyzeSpO2(currentSpO2: number): SpO2Analysis {
  const isCritical = currentSpO2 < 90; // Critical level
  const isLow = currentSpO2 < 94; // Low level requiring confirmation

  return {
    isAbnormal: isLow || isCritical,
    severity: isCritical ? "critical" : isLow ? "low" : "normal",
    requiresConfirmation: isLow && !isCritical,
  };
}

/**
 * Analyze enhanced movement patterns with accelerometer/gyroscope data
 */
function analyzeMovement(
  currentMovement: number,
  gyroActivity: number,
  heartRate: number,
  restingHR: number,
  userId: string,
  deviceId: string
): MovementAnalysis {
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

/**
 * Apply enhanced trigger logic with exercise detection
 */
function applyTriggerLogic(
  hrAnalysis: HRAnalysis,
  spo2Analysis: SpO2Analysis,
  movementAnalysis: MovementAnalysis,
  abnormalCount: number,
  abnormalMetrics: AbnormalMetrics,
  metrics: DetectionMetrics,
  gyroActivity: number
): DetectionResult {
  let triggered = false;
  let reason = "normal";
  let confidenceLevel = 0.0;
  let requiresUserConfirmation = false;

  // Check if this appears to be exercise first (prevents false alarms)
  const exerciseDetected = isExercisePattern(
    metrics.currentMovement, 
    gyroActivity, 
    metrics.currentHR, 
    metrics.restingHR
  );
  
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
      metrics: {
        ...metrics,
        percentageAboveResting: hrAnalysis.percentageAbove,
        sustainedHR: hrAnalysis.sustainedFor30Seconds,
      },
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
    const hrElevation = (metrics.currentHR - metrics.restingHR);
    const isMildLevel = hrElevation >= 15 && hrElevation < 25; // +15 to +24 BPM
    const isModerateLevel = hrElevation >= 25 && hrElevation < 35; // +25 to +34 BPM
    
    // ALWAYS require confirmation for mild and moderate levels, even with multiple metrics
    requiresUserConfirmation = isMildLevel || isModerateLevel;

    if (hrAnalysis.isAbnormal && movementAnalysis.hasSpikes) {
      reason = "combinedHRMovement";
      confidenceLevel = Math.min(1.0, confidenceLevel + 0.1); // Extra confidence for this combo
    } else if (hrAnalysis.isAbnormal && spo2Analysis.isAbnormal) {
      reason = "combinedHRSpO2";
    } else if (spo2Analysis.isAbnormal && movementAnalysis.hasSpikes) {
      reason = "combinedSpO2Movement";
    } else {
      reason = "multipleMetrics";
    }
  }
  // Tremor detection - Special case for anxiety
  else if (tremorDetected) {
    triggered = true;
    reason = "tremorDetected";
    confidenceLevel = 0.8; // High confidence for tremors
    
    // Check severity level even for tremors
    const hrElevation = (metrics.currentHR - metrics.restingHR);
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
      const hrElevation = (metrics.currentHR - metrics.restingHR);
      const isMildLevel = hrElevation >= 15 && hrElevation < 25; // +15 to +24 BPM
      const isModerateLevel = hrElevation >= 25 && hrElevation < 35; // +25 to +34 BPM
      
      // Special case: High HR while resting (very likely anxiety)
      if (metrics.currentMovement < 15 && hrAnalysis.type === "high") {
        confidenceLevel = 0.85;
        // ALWAYS require confirmation for mild and moderate levels
        if (isMildLevel || isModerateLevel) {
          requiresUserConfirmation = true;
          console.log(`${isMildLevel ? 'Mild' : 'Moderate'} anxiety level detected - requesting user confirmation`);
        } else {
          requiresUserConfirmation = false;
        }
        reason = "highHR";
        console.log("High heart rate while resting - likely anxiety");
      }
    } else if (spo2Analysis.isAbnormal) {
      reason = "lowSpO2";
    } else if (movementAnalysis.hasSpikes) {
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
    confidenceLevel: Math.round(confidenceLevel * 100) / 100, // Round to 2 decimal places
    requiresUserConfirmation,
    abnormalMetrics,
    metrics: {
      ...metrics,
      percentageAboveResting: hrAnalysis.percentageAbove,
      sustainedHR: hrAnalysis.sustainedFor30Seconds,
    },
  };
}

/**
 * Handle anxiety detection result
 */
async function handleAnxietyDetection(
  result: DetectionResult,
  userId: string,
  deviceId: string
) {
  const timestamp = Date.now();

  try {
    // Store the detection result
    await storeAnxietyDetection(result, userId, deviceId, timestamp);

    // Send notification based on confidence and confirmation requirement
    if (!result.requiresUserConfirmation || result.confidenceLevel >= 0.8) {
      await sendAnxietyNotification(result, userId, deviceId);
    } else {
      await sendConfirmationRequest(result, userId, deviceId);
    }

    return { success: true, result };
  } catch (error: unknown) {
    console.error("Error handling anxiety detection:", error);
    const message = (error as Error)?.message ?? "Unknown error";
    return { success: false, error: message };
  }
}

/**
 * Store anxiety detection result
 */
async function storeAnxietyDetection(
  result: DetectionResult,
  userId: string,
  deviceId: string,
  timestamp: number
) {
  const alertRef = db.ref(
    `anxiety_detections/${userId}/${deviceId}/${timestamp}`
  );

  await alertRef.set({
    ...result,
    timestamp,
    userId,
    deviceId,
    resolved: false,
  });

  console.log(`Stored anxiety detection: ${result.reason}`);
}

/**
 * Send anxiety notification
 */
async function sendAnxietyNotification(
  result: DetectionResult,
  userId: string,
  deviceId: string
) {
  const notificationContent = getNotificationContent(result);

  const message: admin.messaging.TopicMessage = {
    data: {
      type: "anxiety_alert_multiparameter",
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
      priority: result.confidenceLevel >= 0.8 ? "high" : "normal",
      notification: {
        channelId: "anxiety_alerts",
        // Admin SDK types don't include AndroidNotification.priority in some versions; omit to avoid type errors
        defaultSound: true,
        defaultVibrateTimings: true,
        color: getNotificationColor(result.reason),
      },
    },
    topic: `user_${userId}`,
  };

  await admin.messaging().send(message);
  console.log(
    `Anxiety notification sent: ${result.reason} (confidence: ${result.confidenceLevel})`
  );
}

/**
 * Send confirmation request notification
 */
async function sendConfirmationRequest(
  result: DetectionResult,
  userId: string,
  deviceId: string
) {
  const message: admin.messaging.TopicMessage = {
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
function getNotificationContent(result: DetectionResult) {
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
      body: `Your heart rate is elevated (${result.metrics.currentHR} BPM, ${(
        result.metrics.percentageAboveResting ?? 0
      ).toFixed(0)}% above baseline). Consider using relaxation techniques.`,
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

  return (
    (templates as Record<string, { title: string; body: string }>)[
      result.reason
    ] || {
      title: "Anxiety Alert",
      body: "We detected some changes that might indicate anxiety. Take a moment to check in with yourself.",
    }
  );
}

/**
 * Get notification color based on reason
 */
function getNotificationColor(reason: string) {
  const colors = {
    criticalSpO2: "#D32F2F", // Dark Red
    combinedHRMovement: "#F44336", // Red
    combinedHRSpO2: "#F44336", // Red
    highHR: "#FF9800", // Orange
    lowHR: "#FF5722", // Deep Orange
    lowSpO2: "#9C27B0", // Purple
    movementSpikes: "#FFC107", // Amber
  };

  return (colors as Record<string, string>)[reason] || "#2196F3"; // Blue default
}

/**
 * Get device information with userId for notifications
 */
async function getDeviceInfo(deviceId: string): Promise<any> {
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
          source: "assignment_sync"
        };
      }
    }
    
    console.log(`⚠️ No user assigned to device ${deviceId} in either metadata or assignment`);
    return null;
  } catch (error) {
    console.error("Error fetching device info:", error);
    return null;
  }
}

/**
 * Get user baseline
 */
async function getUserBaseline(
  userId: string,
  deviceId: string
): Promise<{ baselineHR: number } | null> {
  try {
    // In real implementation, query Supabase here
    const baselineRef = db.ref(`baselines/${userId}/${deviceId}`);
    const snapshot = await baselineRef.once("value");
    return snapshot.exists() ? snapshot.val() : null;
  } catch (error) {
    console.error("Error fetching baseline:", error);
    return null;
  }
}

// Export internal functions for testing
export {
  analyzeMultiParameterAnxiety,
  analyzeHeartRate,
  analyzeSpO2,
  analyzeMovement,
  applyTriggerLogic,
};
