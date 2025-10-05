import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.database();

// Optional: Supabase server-side persistence for alerts
// Configure via environment variables (Firebase Functions config or runtime env)
const SUPABASE_URL =
  process.env.SUPABASE_URL || functions.config().supabase?.url;
const SUPABASE_SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  functions.config().supabase?.service_role_key;

// Lazy import to avoid hard dependency when not configured
let fetchImpl: any = null;
try {
  // Node 18+ has global fetch; fallback not needed normally
  fetchImpl = (global as any).fetch || require("node-fetch");
} catch {}

// Rate limiting configuration
const RATE_LIMIT_WINDOW_MS = 2 * 60 * 1000; // 2 minutes in milliseconds
const rateLimit = new Map<string, number>(); // userId -> lastNotificationTime

// Sustained anxiety detection configuration
const MIN_SUSTAINED_DURATION_SECONDS = 90; // Require 90+ seconds of continuous elevation (1.5 minutes)

/**
 * Real-time anxiety detection with user-specific analysis
 * Triggers when device current data is updated
 * Only processes if device is assigned to a user
 */
export const realTimeSustainedAnxietyDetection = functions.database
  .ref("/devices/{deviceId}/current")
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const afterData = change.after.val();

    console.log(
      `🔍 Device ${deviceId} data updated, checking for user assignment`
    );

    // Validate required data
    if (
      !afterData ||
      !afterData.heartRate ||
      typeof afterData.heartRate !== "number"
    ) {
      console.log("❌ Missing or invalid heart rate data");
      return null;
    }

    try {
      // STEP 1: Check if device is assigned to a user
      const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
      const assignmentSnapshot = await assignmentRef.once("value");

      if (!assignmentSnapshot.exists()) {
        console.log(
          `⚠️ Device ${deviceId} not assigned to any user - skipping anxiety detection`
        );
        return null;
      }

      const assignment = assignmentSnapshot.val();
      if (!assignment.assignedUser || !assignment.activeSessionId) {
        console.log(`⚠️ Device ${deviceId} assignment incomplete - skipping`);
        return null;
      }

      const userId = assignment.assignedUser;
      const sessionId = assignment.activeSessionId;

      console.log(
        `👤 Device assigned to user: ${userId}, session: ${sessionId}`
      );

      // STEP 2: Get user's personal baseline
      const userBaseline = await getUserBaseline(userId, deviceId);
      if (!userBaseline || !userBaseline.baselineHR) {
        console.log(
          `⚠️ No baseline found for user ${userId} - skipping anxiety detection`
        );
        return null;
      }

      console.log(`📊 User baseline: ${userBaseline.baselineHR} BPM`);

      // STEP 3: Get user's recent session history (not device history!)
      const userHistoryData = await getUserSessionHistory(
        userId,
        sessionId,
        40
      );

      if (userHistoryData.length < 3) {
        console.log(
          `⚠️ Not enough user session history (${userHistoryData.length} points) for sustained detection`
        );
        return null;
      }

      // STEP 4: Analyze for sustained anxiety using USER-SPECIFIC data
      const sustainedAnalysis = analyzeUserSustainedAnxiety(
        userHistoryData,
        userBaseline.baselineHR,
        afterData,
        userId
      );

      if (sustainedAnalysis.isSustained) {
        console.log(`🚨 SUSTAINED ANXIETY DETECTED FOR USER ${userId}`);
        console.log(`📊 Duration: ${sustainedAnalysis.sustainedSeconds}s`);
        console.log(
          `💓 Average HR: ${sustainedAnalysis.averageHR} (${sustainedAnalysis.percentageAbove}% above user's baseline)`
        );

        // Rate limiting check - prevent duplicate notifications
        // Check BEFORE processing to avoid multiple simultaneous triggers
        const now = Date.now();
        const lastNotification = rateLimit.get(userId) || 0;
        const timeSinceLastNotification = now - lastNotification;

        if (timeSinceLastNotification < RATE_LIMIT_WINDOW_MS) {
          const remainingMinutes = Math.ceil(
            (RATE_LIMIT_WINDOW_MS - timeSinceLastNotification) / (60 * 1000)
          );
          console.log(
            `⏱️ Rate limit: User ${userId} was notified ${Math.floor(
              timeSinceLastNotification / 1000
            )}s ago. ` +
              `Skipping notification (${remainingMinutes}min remaining in cooldown)`
          );
          return null;
        }

        // IMMEDIATELY set rate limit to prevent race conditions
        rateLimit.set(userId, now);
        console.log(
          `✅ Rate limit passed for user ${userId}, sending notification`
        );

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
      } else {
        console.log(
          `✅ User ${userId}: Heart rate elevated but not sustained (${sustainedAnalysis.durationSeconds}s < ${MIN_SUSTAINED_DURATION_SECONDS}s required)`
        );
      }

      return null;
    } catch (error) {
      console.error("❌ Error in user-specific anxiety detection:", error);
      return null;
    }
  });

/**
 * Get user's session history data (from user sessions, not raw device data)
 */
async function getUserSessionHistory(
  userId: string,
  sessionId: string,
  seconds: number
): Promise<
  Array<{
    timestamp: number;
    heartRate: number;
    spo2?: number;
    bodyTemp?: number;
    worn?: number;
  }>
> {
  const userSessionRef = db.ref(
    `/users/${userId}/sessions/${sessionId}/history`
  );
  const cutoffTime = Date.now() - seconds * 1000;

  try {
    const snapshot = await userSessionRef
      .orderByChild("timestamp")
      .startAt(cutoffTime)
      .once("value");

    if (!snapshot.exists()) {
      console.log(
        `📊 No user session history found for ${userId}/${sessionId} in last ${seconds}s`
      );
      return [];
    }

    const historyData: any[] = [];
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

    console.log(
      `📊 Retrieved ${historyData.length} user session history points for analysis`
    );
    return historyData;
  } catch (error) {
    console.error("❌ Error fetching user session history:", error);
    return [];
  }
}

/**
 * Calculate movement intensity from accelerometer data to detect exercise vs anxiety
 */
function calculateMovementIntensity(
  accelX: number = 0,
  accelY: number = 0,
  accelZ: number = 0
): number {
  // Calculate magnitude of acceleration vector
  const magnitude = Math.sqrt(
    accelX * accelX + accelY * accelY + accelZ * accelZ
  );

  // Subtract gravity (approximately 9.8 m/s²) to get movement component
  const movementComponent = Math.abs(magnitude - 9.8);

  // Scale to 0-100 for easier interpretation (multiply by 10 for sensitivity)
  return Math.min(100, movementComponent * 10);
}

/**
 * Detect if movement pattern suggests exercise (to prevent false positives)
 */
function isExercisePattern(
  movementIntensity: number,
  heartRate: number,
  restingHR: number
): boolean {
  const hrElevation = (heartRate - restingHR) / restingHR;

  // Exercise typically shows:
  // - High movement intensity (>30) with proportional HR increase
  // - OR very high movement (>50) regardless of HR pattern
  if (movementIntensity > 50) {
    console.log(
      `🏃 High movement detected (${movementIntensity.toFixed(
        1
      )}) - likely exercise`
    );
    return true;
  }

  if (movementIntensity > 30 && hrElevation > 0.3) {
    console.log(`🚶 Moderate movement with high HR - likely physical activity`);
    return true;
  }

  return false;
}

/**
 * Enhanced sustained anxiety analysis with movement-based false positive prevention
 */
function analyzeUserSustainedAnxiety(
  userHistoryData: any[],
  baselineHR: number,
  currentData: any,
  userId: string
) {
  if (userHistoryData.length < 3) {
    return { isSustained: false, durationSeconds: 0 };
  }

  // User-specific anxiety threshold (20% above their personal baseline)
  const anxietyThreshold = baselineHR * 1.2;
  const now = Date.now();

  console.log(
    `📊 User ${userId} analysis: threshold=${anxietyThreshold} BPM, current=${currentData.heartRate} BPM`
  );

  // Include current data point and sort by timestamp
  const allData = [{ ...currentData, timestamp: now }, ...userHistoryData].sort(
    (a, b) => a.timestamp - b.timestamp
  ); // Sort chronologically (oldest first)

  console.log(
    `📊 Analyzing ${allData.length} data points chronologically for user ${userId}`
  );

  // Find the longest continuous elevated period
  let longestSustainedDuration = 0;
  let currentSustainedStart = null;
  let currentElevatedPoints: any[] = [];
  let bestElevatedPoints: any[] = [];

  for (const point of allData) {
    // Extract accelerometer data if available
    const accelX = point.accelX || 0;
    const accelY = point.accelY || 0;
    const accelZ = point.accelZ || 0;

    // Calculate movement intensity
    const movementIntensity = calculateMovementIntensity(
      accelX,
      accelY,
      accelZ
    );

    // Check if this looks like exercise (to prevent false positives)
    const isExercise = isExercisePattern(
      movementIntensity,
      point.heartRate,
      baselineHR
    );

    if (
      point.heartRate >= anxietyThreshold &&
      point.worn !== 0 &&
      !isExercise
    ) {
      // Heart rate is elevated AND it doesn't look like exercise
      console.log(
        `📊 Valid anxiety point: HR=${
          point.heartRate
        }, Movement=${movementIntensity.toFixed(1)}, Exercise=${isExercise}`
      );

      if (currentSustainedStart === null) {
        currentSustainedStart = point.timestamp;
        currentElevatedPoints = [];
      }
      currentElevatedPoints.push(point);
    } else {
      // Heart rate dropped below threshold OR exercise detected - check if this was our best sustained period
      if (isExercise) {
        console.log(
          `🏃 Skipping point due to exercise: HR=${
            point.heartRate
          }, Movement=${movementIntensity.toFixed(1)}`
        );
      }

      if (currentSustainedStart !== null) {
        const sustainedDuration =
          (point.timestamp - currentSustainedStart) / 1000;
        console.log(
          `📊 User ${userId}: Found elevated period of ${sustainedDuration}s (${currentElevatedPoints.length} points)`
        );

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
    const ongoingSustainedDuration =
      (latestTimestamp - currentSustainedStart) / 1000;
    console.log(
      `📊 User ${userId}: Current ongoing elevated period: ${ongoingSustainedDuration}s (${currentElevatedPoints.length} points)`
    );

    if (ongoingSustainedDuration > longestSustainedDuration) {
      longestSustainedDuration = ongoingSustainedDuration;
      bestElevatedPoints = [...currentElevatedPoints];
    }
  }

  // Check if we have required duration of sustained elevation for true anxiety detection
  if (longestSustainedDuration >= MIN_SUSTAINED_DURATION_SECONDS && bestElevatedPoints.length > 0) {
    const avgHR =
      bestElevatedPoints.reduce((sum, p) => sum + p.heartRate, 0) /
      bestElevatedPoints.length;
    const percentageAbove = Math.round(
      ((avgHR - baselineHR) / baselineHR) * 100
    );

    console.log(
      `🚨 User ${userId}: SUSTAINED ANXIETY DETECTED! ${longestSustainedDuration}s at avg ${avgHR} BPM`
    );

    return {
      isSustained: true,
      sustainedSeconds: Math.floor(longestSustainedDuration),
      averageHR: Math.round(avgHR),
      percentageAbove: percentageAbove,
      severity: getSeverityLevel(avgHR, baselineHR),
      reason: `User ${userId}: Heart rate sustained ${percentageAbove}% above personal baseline for ${Math.floor(
        longestSustainedDuration
      )}+ seconds`,
    };
  }

  console.log(
    `✅ User ${userId}: Heart rate elevated but not sustained (${longestSustainedDuration}s < 10s required)`
  );

  return {
    isSustained: false,
    durationSeconds: Math.floor(longestSustainedDuration),
    reason:
      longestSustainedDuration > 0
        ? `User ${userId}: Elevated for ${Math.floor(
            longestSustainedDuration
          )}s (need 10s)`
        : `User ${userId}: HR within normal range`,
  };
}

/**
 * Determine severity level based on heart rate elevation
 */
function getSeverityLevel(heartRate: number, baseline: number): string {
  const percentageAbove = ((heartRate - baseline) / baseline) * 100;

  // Critical: 80%+ above baseline (emergency level)
  if (percentageAbove >= 80) return "critical";
  // Severe: 50-79% above baseline
  if (percentageAbove >= 50) return "severe";
  // Moderate: 30-49% above baseline
  if (percentageAbove >= 30) return "moderate";
  // Mild: 20-29% above baseline
  return "mild";
}

/**
 * Get the correct channel ID for severity level to match Flutter app
 */
function getChannelIdForSeverity(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "mild_anxiety_alerts_v4"; // Bumped to align with client channel recreation
    case "moderate":
      return "moderate_anxiety_alerts_v2";
    case "severe":
      return "severe_anxiety_alerts_v2";
    case "critical":
      return "critical_anxiety_alerts_v2";
    default:
      return "anxiease_channel"; // Fallback to general channel
  }
}

/**
 * Get the correct sound file for severity level to match Flutter app
 */
function getSoundForSeverity(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "mild_alert.mp3";
    case "moderate":
      return "moderate_alert.mp3";
    case "severe":
      return "severe_alert.mp3";
    case "critical":
      return "critical_alert.mp3";
    default:
      return "default"; // System default sound
  }
}

/**
 * Send FCM notification to specific user
 */
async function sendUserAnxietyAlert(alertData: any) {
  console.log(
    `🔔 Sending anxiety alert notification to user ${alertData.userId}`
  );

  try {
    // Get user's FCM token specifically for anxiety alerts (assignment-level)
    const fcmToken = await getUserFCMToken(
      alertData.userId,
      alertData.deviceId,
      "anxiety_alert"
    );

    if (!fcmToken) {
      console.log(
        `⚠️ No anxiety alert FCM token found for user ${alertData.userId} - user may not have device assigned`
      );
      return null;
    }

    const notificationContent = getUserNotificationContent(alertData);

    const message = {
      token: fcmToken,
      // DATA-ONLY PAYLOAD - No 'notification' key for 100% reliability
      data: {
        type: "anxiety_alert",
        userId: alertData.userId,
        sessionId: alertData.sessionId,
        severity: alertData.severity,
        heartRate: alertData.heartRate.toString(),
        baseline: alertData.baseline.toString(),
        duration: alertData.duration.toString(),
        // Flutter will use these fields to create local notification
        title: notificationContent.title,
        message: notificationContent.body,
        timestamp: Date.now().toString(),
        reason: alertData.reason || "Sustained elevated heart rate detected",
        deviceId: alertData.deviceId || "",
        color: notificationContent.color,
        channelId: getChannelIdForSeverity(alertData.severity),
        sound: getSoundForSeverity(alertData.severity),
        // New fields for confirmation system
        requiresConfirmation:
          notificationContent.requiresConfirmation.toString(),
        alertType: notificationContent.alertType,
        // For critical alerts, automatically count as anxiety attack
        autoConfirm: (alertData.severity === "critical").toString(),
      },
      android: {
        priority: "high" as const,
        // Remove notification config since we're data-only
      },
      apns: {
        headers: {
          "apns-priority": "10", // High priority for iOS
        },
        payload: {
          aps: {
            "content-available": 1, // Silent push for iOS data-only
            category: "ANXIETY_ALERT",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(
      `✅ Notification sent successfully to user ${alertData.userId}:`,
      response
    );

    // Store alert in user's personal history (Firebase RTDB)
    await storeUserAnxietyAlert(alertData);

    // Additionally, persist to Supabase (single source for app UI) if configured
    try {
      if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && fetchImpl) {
        await persistAlertToSupabase(alertData);
      } else {
        console.log(
          "ℹ️ Supabase env not configured; skipping server-side Supabase insert"
        );
      }
    } catch (e) {
      console.error("❌ Failed to persist alert to Supabase:", e);
    }

    return response;
  } catch (error) {
    console.error(
      `❌ Error sending anxiety notification to user ${alertData.userId}:`,
      error
    );
    return null;
  }
}

/**
 * Persist alert to Supabase as the system source of truth
 */
async function persistAlertToSupabase(alertData: any) {
  const url = `${SUPABASE_URL}/rest/v1/notifications`;
  const content = getUserNotificationContent(alertData);
  const payload = {
    // Keep payload aligned with app-side SupabaseService.createNotification schema
    user_id: alertData.userId || null,
    title: content.title,
    message: content.body,
    type: "alert", // match enum used by app (alert|reminder)
    related_screen: "notifications",
    created_at: new Date().toISOString(),
  } as any;

  const res = await fetchImpl(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      Prefer: "return=representation",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase insert failed: ${res.status} ${text}`);
  }

  const json = await res.json();
  console.log("🗃️ Supabase insert success:", json);
}

/**
 * Get user's FCM token for notifications with context-aware retrieval and validation
 * For anxiety alerts: Use assignment-level token (device-assigned users only)
 * For wellness notifications: Use user-level token (all users)
 */
export async function getUserFCMToken(
  userId: string,
  deviceId?: string,
  notificationType: string = "anxiety_alert"
): Promise<string | null> {
  // For ANXIETY ALERTS: Only get token from assignment level (device-assigned users)
  if (notificationType === "anxiety_alert" && deviceId) {
    const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
    const assignmentSnapshot = await assignmentRef.once("value");

    if (assignmentSnapshot.exists()) {
      const assignmentData = assignmentSnapshot.val();
      const fcmToken = assignmentData?.fcmToken;
      const assignedUser = assignmentData?.assignedUser;

      // VALIDATION: Ensure the token belongs to the requesting user
      if (fcmToken && assignedUser === userId) {
        console.log(
          `✅ Found verified anxiety alert FCM token for user ${userId} at device ${deviceId}`
        );
        return fcmToken;
      } else if (fcmToken && assignedUser !== userId) {
        console.log(
          `⚠️ Assignment FCM token exists for device ${deviceId} but belongs to different user (${assignedUser}) not requesting user (${userId})`
        );
        return null;
      } else if (fcmToken && !assignedUser) {
        console.log(
          `⚠️ Assignment FCM token exists for device ${deviceId} but no assignedUser field - possible legacy token`
        );
        // For backward compatibility, allow legacy tokens without assignedUser field
        return fcmToken;
      }
    }

    console.log(
      `⚠️ No valid assignment-level FCM token found for anxiety alert to user ${userId}, device ${deviceId}`
    );
    return null;
  }

  // For WELLNESS NOTIFICATIONS: Get token from user level (all users)
  if (
    notificationType === "wellness_reminder" ||
    notificationType === "general"
  ) {
    const userTokenRef = db.ref(`/users/${userId}/fcmToken`);
    const tokenSnapshot = await userTokenRef.once("value");

    if (tokenSnapshot.exists()) {
      const tokenData = tokenSnapshot.val();
      // Handle both new structure {token: "...", updatedAt: "..."} and legacy string format
      const token =
        typeof tokenData === "string" ? tokenData : tokenData?.token;

      if (token) {
        console.log(
          `✅ Found wellness FCM token at user level: /users/${userId}/fcmToken`
        );
        return token;
      }
    }

    console.log(
      `⚠️ No user-level FCM token found for wellness notification to user ${userId}`
    );
    return null;
  }

  // FALLBACK: Try legacy locations for backward compatibility
  if (deviceId) {
    // Legacy device-level token
    const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
    const deviceTokenSnapshot = await deviceTokenRef.once("value");

    if (deviceTokenSnapshot.exists()) {
      console.log(
        `✅ Found FCM token at legacy device level: /devices/${deviceId}/fcmToken`
      );
      return deviceTokenSnapshot.val();
    }
  }

  // Legacy user profile token (string format)
  const userTokenRef = db.ref(`/users/${userId}/fcmToken`);
  const tokenSnapshot = await userTokenRef.once("value");

  if (tokenSnapshot.exists()) {
    const tokenData = tokenSnapshot.val();
    const token = typeof tokenData === "string" ? tokenData : tokenData?.token;

    if (token) {
      console.log(
        `✅ Found FCM token at user level (fallback): /users/${userId}/fcmToken`
      );
      return token;
    }
  }

  console.log(
    `⚠️ No FCM token found in Firebase for user ${userId}${
      deviceId ? ` or device ${deviceId}` : ""
    } for notification type: ${notificationType}`
  );
  return null;
}

/**
 * Get user-specific notification content based on severity
 */
function getUserNotificationContent(alertData: any) {
  const percentageText = `${Math.round(
    ((alertData.heartRate - alertData.baseline) / alertData.baseline) * 100
  )}%`;

  // Calculate confidence based on severity level (higher severity = higher confidence)
  const getConfidenceLevel = (severity: string) => {
    switch (severity) {
      case "critical":
        return "95% Confidence";
      case "severe":
        return "85% Confidence";
      case "moderate":
        return "70% Confidence";
      case "mild":
        return "60% Confidence";
      default:
        return "50% Confidence";
    }
  };

  const confidence = getConfidenceLevel(alertData.severity);

  switch (alertData.severity) {
    case "critical":
      return {
        title: `🚨 Critical Alert - ${confidence}`,
        body: `URGENT: Your heart rate has been critically elevated at ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. This indicates a severe anxiety episode. Please seek immediate support if needed.`,
        color: "#FF0000", // RED for critical
        sound: "critical_alert",
        requiresConfirmation: false, // Critical = definitive anxiety, no confirmation needed
        alertType: "definitive_anxiety",
      };
    case "severe":
      return {
        title: `� Severe Alert - ${confidence}`,
        body: `Hi there! I noticed your heart rate was elevated to ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. Are you experiencing any anxiety or stress right now?`,
        color: "#FFA500", // ORANGE for severe
        sound: "severe_alert",
        requiresConfirmation: true,
        alertType: "check_in_severe",
      };
    case "moderate":
      return {
        title: `🟡 Moderate Alert - ${confidence}`,
        body: `Your heart rate increased to ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. How are you feeling? Is everything alright?`,
        color: "#FFFF00", // YELLOW for moderate
        sound: "moderate_alert",
        requiresConfirmation: true,
        alertType: "check_in_moderate",
      };
    case "mild":
      return {
        title: `🟢 Mild Alert - ${confidence}`,
        body: `I noticed a slight increase in your heart rate to ${alertData.heartRate} BPM (${percentageText} above your baseline) for ${alertData.duration}s. Are you experiencing any anxiety or is this just normal activity?`,
        color: "#4CAF50", // GREEN for mild (not orange!)
        sound: "mild_alert",
        requiresConfirmation: true,
        alertType: "check_in_mild",
      };
    default:
      return {
        title: `📊 Heart Rate Check - 50% Confidence`,
        body: `Heart rate: ${alertData.heartRate} BPM`,
        color: "#4CAF50",
        sound: "mild_alert",
        requiresConfirmation: true,
        alertType: "check_in_mild",
      };
  }
}

/**
 * Store anxiety alert in user's personal alert history
 */
async function storeUserAnxietyAlert(alertData: any) {
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

  console.log(
    `📝 Stored user anxiety alert: ${userAlertsRef.key} for user ${alertData.userId}`
  );
}

/**
 * Get user's baseline heart rate
 */
async function getUserBaseline(
  userId: string,
  deviceId: string
): Promise<{ baselineHR: number } | null> {
  // Try to get baseline from device assignment (where it's actually stored)
  const deviceBaselineRef = db.ref(
    `/devices/${deviceId}/assignment/supabaseSync/baselineHR`
  );
  const baselineSnapshot = await deviceBaselineRef.once("value");

  if (baselineSnapshot.exists()) {
    const baselineHR = baselineSnapshot.val();
    console.log(
      `📊 Found user baseline: ${baselineHR} BPM from device assignment`
    );
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

/**
 * Clear rate limits for testing purposes
 */
export const clearAnxietyRateLimits = functions.https.onRequest(
  async (req, res) => {
    try {
      rateLimit.clear();
      console.log("🧹 Cleared all anxiety notification rate limits");
      res.status(200).json({
        success: true,
        message: "Rate limits cleared successfully",
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error("❌ Error clearing rate limits:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);
