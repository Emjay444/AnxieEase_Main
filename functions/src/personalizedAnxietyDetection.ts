import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.database();

/**
 * Enhanced anxiety detection with personalized thresholds
 * Triggers when heart rate data is updated in Firebase RTDB
 */
export const detectPersonalizedAnxiety = functions.database
  .ref("/devices/{deviceId}/current/heartRate")
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const newHeartRate = change.after.val();
    const oldHeartRate = change.before.val();

    if (!newHeartRate || typeof newHeartRate !== "number") {
      console.log("Invalid heart rate data, skipping");
      return null;
    }

    console.log(
      `Processing HR update for ${deviceId}: ${oldHeartRate} → ${newHeartRate}`
    );

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
        console.log(
          `No baseline found for user ${deviceData.userId}, skipping anxiety detection - baseline required`
        );
        return null; // No detection without baseline
      }

      // Calculate personalized thresholds
      const thresholds = calculatePersonalizedThresholds(
        userBaseline.baselineHR
      );
      console.log(
        `User baseline: ${userBaseline.baselineHR}, Thresholds:`,
        thresholds
      );

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
    } catch (error) {
      console.error("Error processing anxiety detection:", error);
      return null;
    }
  });

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
    
    // If no userId in metadata, check assignment path (from Supabase webhook sync)
    const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
    const assignmentSnapshot = await assignmentRef.once("value");
    
    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      if (assignment.assignedUser) {
        return {
          userId: assignment.assignedUser,
          deviceId: deviceId,
          source: "supabase_webhook_sync"
        };
      }
    }
    
    console.log(`⚠️ No user assigned to device ${deviceId}`);
    return null;
  } catch (error) {
    console.error("Error fetching device info:", error);
    return null;
  }
}

/**
 * Get user's baseline heart rate from Supabase
 */
async function getUserBaseline(
  userId: string,
  deviceId: string
): Promise<{ baselineHR: number } | null> {
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
  } catch (error) {
    console.error("Error fetching user baseline:", error);
    return null;
  }
}

/**
 * Calculate personalized thresholds based on user's baseline
 */
function calculatePersonalizedThresholds(baselineHR: number) {
  return {
    baseline: baselineHR,
    mild: baselineHR + 15, // +15 BPM above baseline
    moderate: baselineHR + 25, // +25 BPM above baseline
    severe: baselineHR + 35, // +35 BPM above baseline
    // Additional thresholds for more granular detection
    elevated: baselineHR + 10, // +10 BPM (early warning)
    critical: baselineHR + 45, // +45 BPM (emergency)
  };
}

/**
 * Determine severity level based on heart rate and personalized thresholds
 */
function getSeverityLevel(heartRate: number, thresholds: any) {
  if (heartRate >= thresholds.critical) return "critical";
  if (heartRate >= thresholds.severe) return "severe";
  if (heartRate >= thresholds.moderate) return "moderate";
  if (heartRate >= thresholds.mild) return "mild";
  if (heartRate >= thresholds.elevated) return "elevated";
  return "normal";
}

/**
 * Check if notifications are rate-limited for this user
 */
async function isRateLimited(userId: string, severity: string) {
  const now = Date.now();
  const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
  const snapshot = await rateLimitRef.once("value");

  const limits = {
    mild: 300000, // 5 minutes
    moderate: 180000, // 3 minutes
    severe: 60000, // 1 minute
    critical: 30000, // 30 seconds
  };

  const limit = (limits as Record<string, number>)[severity] || 300000;

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
async function sendPersonalizedNotification(data: any) {
  const { userId, deviceId, heartRate, baseline, severity, thresholds } = data;

  // Calculate percentage above baseline
  const percentageAbove = (((heartRate - baseline) / baseline) * 100).toFixed(
    0
  );
  const bpmAbove = (heartRate - baseline).toFixed(0);

  const notificationContent = getPersonalizedNotificationContent(
    severity,
    heartRate,
    baseline,
    percentageAbove,
    bpmAbove
  );

  const message: admin.messaging.TopicMessage = {
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
      priority:
        severity === "severe" || severity === "critical"
          ? ("high" as const)
          : ("normal" as const),
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
    console.log(
      `Personalized notification sent - ${severity}: ${heartRate} BPM (${bpmAbove} above baseline)`
    );

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
  } catch (error: unknown) {
    console.error("Error sending personalized notification:", error);
    const message = (error as Error)?.message ?? "Unknown error";
    return { success: false, error: message };
  }
}

/**
 * Get personalized notification content
 */
function getPersonalizedNotificationContent(
  severity: string,
  heartRate: number,
  baseline: number,
  percentageAbove: string,
  bpmAbove: string
) {
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

  return (
    (templates as Record<string, { title: string; body: string }>)[severity] ||
    templates.mild
  );
}

/**
 * Get notification color based on severity
 */
function getNotificationColor(severity: string) {
  const colors = {
    elevated: "#FFA726", // Orange
    mild: "#66BB6A", // Light Green
    moderate: "#FF9800", // Orange
    severe: "#F44336", // Red
    critical: "#D32F2F", // Dark Red
  };

  return (colors as Record<string, string>)[severity] || colors.mild;
}

/**
 * Store alert in database for history tracking
 */
async function storeAlert(userId: string, deviceId: string, alertData: any) {
  try {
    const alertRef = db.ref(`alerts/${userId}/${deviceId}`).push();
    await alertRef.set({
      ...alertData,
      timestamp: Date.now(),
      resolved: false,
    });
  } catch (error) {
    console.error("Error storing alert:", error);
  }
}

// Export additional helper functions for testing
export {
  calculatePersonalizedThresholds,
  getSeverityLevel,
  getPersonalizedNotificationContent,
};
