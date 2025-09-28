import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Optional: Supabase server-side persistence for test notifications
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

// Import and export data cleanup functions
export {
  cleanupHealthData,
  aggregateHealthDataHourly,
  monitorFirebaseUsage,
} from "./dataCleanup";

// Import and export device data copy functions for multi-user support
export {
  copyDeviceDataToUserSession,
  copyDeviceCurrentToUserSession,
  assignDeviceToUser,
  getDeviceAssignment,
  cleanupOldSessions,
} from "./deviceDataCopyService";

// Import and export enhanced rate limiting functions
export {
  handleUserConfirmationResponse,
  getRateLimitStatus,
} from "./enhancedRateLimiting";

// Import auto history creator
export { autoCreateDeviceHistory } from "./autoHistoryCreator";

// Import real-time sustained anxiety detection
export {
  realTimeSustainedAnxietyDetection,
  clearAnxietyRateLimits,
} from "./realTimeSustainedAnxietyDetection";

// Import auto-cleanup functions
export { autoCleanup, manualCleanup, getCleanupStats } from "./autoCleanup";

// Import device assignment sync functions
export {
  syncDeviceAssignment,
  periodicDeviceSync,
  testDeviceSync,
} from "./deviceAssignmentSync";

// Cloud Function to send FCM notifications when anxiety severity changes
export const onAnxietySeverityChangeV2 = functions.database
  .ref("/devices/AnxieEase001/current")
  .onWrite(async (change, context) => {
    try {
      // Legacy function disabled - anxiety detection now requires personalized baseline
      // Use personalizedAnxietyDetection function instead
      console.log(
        "Legacy threshold-based detection disabled - requires baseline from personalizedAnxietyDetection function"
      );
      return null;
    } catch (error) {
      console.error("❌ Error in onAnxietySeverityChangeV2:", error);
      throw error;
    }
  });

// NEW: Send FCM when a native alert is created under devices/<deviceId>/alerts
export const onNativeAlertCreate = functions.database
  .ref("/devices/{deviceId}/alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    try {
      const alert = snapshot.val() as any;
      if (!alert) return null;

      const severity = (alert.severity || "").toLowerCase();
      const heartRate = alert.heartRate;
      const ts = alert.timestamp || Date.now();

      if (!["mild", "moderate", "severe"].includes(severity)) {
        console.log(`Skipping alert with invalid severity: ${severity}`);
        return null;
      }

      const { title, body } = getNotificationContent(severity, heartRate);

      // DATA-ONLY: Include title/body in data; no notification key
      const message = {
        data: {
          type: "anxiety_alert",
          severity,
          heartRate: heartRate?.toString() || "N/A",
          timestamp: ts.toString(),
          notificationId: `${severity}_${ts}`,
          title,
          message: body,
        },
        android: {
          priority: "high" as const,
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ FCM sent from onNativeAlertCreate:", response);
      return response;
    } catch (error) {
      console.error("❌ Error in onNativeAlertCreate:", error);
      throw error;
    }
  });

// Helper function to get notification content based on severity
function getNotificationContent(severity: string, heartRate?: number) {
  const hrText = heartRate ? ` HR: ${heartRate} bpm` : "";

  switch (severity) {
    case "mild":
      return {
        title: "🟢 Mild Alert - 60% Confidence",
        body: `Slight elevation in readings.${hrText}`,
      };
    case "moderate":
      return {
        title: "🟠 Moderate Alert - 70% Confidence",
        body: `Noticeable symptoms detected.${hrText}`,
      };
    case "severe":
      return {
        title: "🔴 Severe Alert - 85% Confidence",
        body: `URGENT: High risk detected!${hrText}`,
      };
    default:
      return {
        title: "📱 AnxieEase Alert",
        body: `Anxiety level detected.${hrText}`,
      };
  }
}

// Cloud Function to subscribe new users to the anxiety alerts topic
export const subscribeToAnxietyAlertsV2 = functions.https.onCall(
  async (data, context) => {
    try {
      const { fcmToken } = data;

      if (!fcmToken) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "FCM token is required"
        );
      }

      // Subscribe the token to the anxiety_alerts topic
      const response = await admin
        .messaging()
        .subscribeToTopic([fcmToken], "anxiety_alerts");

      console.log(
        "✅ Successfully subscribed to anxiety_alerts topic:",
        response
      );
      return { success: true, message: "Subscribed to anxiety alerts" };
    } catch (error) {
      console.error("❌ Error subscribing to topic:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to subscribe to notifications"
      );
    }
  }
);

// Cloud Function to test FCM notifications (for debugging)
export const sendTestNotificationV2 = functions.https.onCall(
  async (data, context) => {
    try {
      const { severity = "mild", heartRate = 75 } = data;

      const notificationData = getNotificationContent(severity, heartRate);

      // DATA-ONLY test message so background handler processes it
      const message = {
        data: {
          type: "anxiety_alert",
          severity: severity,
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `[TEST] ${notificationData.title}`,
          message: notificationData.body,
        },
        android: {
          priority: "high" as const,
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Test FCM notification sent successfully:", response);

      return { success: true, messageId: response };
    } catch (error) {
      console.error("❌ Error sending test notification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send test notification"
      );
    }
  }
);

// HTTP-based test notification function for easy testing
export const testNotificationHTTP = functions.https.onRequest(
  async (req, res) => {
    // Enable CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight requests
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const { severity = "mild", heartRate = 75 } =
        req.method === "POST" ? req.body : req.query;

      console.log(
        `📧 Testing notification: ${severity} alert with HR: ${heartRate}`
      );

      const notificationData = getNotificationContent(severity, heartRate);

      // DATA-ONLY HTTP test message
      const message = {
        data: {
          type: "anxiety_alert",
          severity: severity as string,
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `[TEST] ${notificationData.title}`,
          message: notificationData.body,
        },
        android: {
          priority: "high" as const,
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Test FCM notification sent successfully:", response);

      // Additionally, persist test alert to Supabase if configured
      try {
        if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && fetchImpl) {
          await persistTestAlertToSupabase(
            severity as string,
            heartRate,
            notificationData
          );
          console.log("✅ Test alert also saved to Supabase");
        } else {
          console.log(
            "ℹ️ Supabase env not configured; skipping test alert storage"
          );
        }
      } catch (e) {
        console.error("❌ Failed to persist test alert to Supabase:", e);
      }

      res.status(200).json({
        success: true,
        messageId: response,
        severity,
        heartRate,
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        message: "Test notification sent successfully! Check your device.",
      });
    } catch (error) {
      console.error("❌ Error sending test notification:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
        message: "Failed to send test notification",
      });
    }
  }
);

/**
 * Persist test alert to Supabase (similar to realTimeSustainedAnxietyDetection)
 */
async function persistTestAlertToSupabase(
  severity: string,
  heartRate: number,
  notificationContent: any
) {
  const url = `${SUPABASE_URL}/rest/v1/notifications`;
  const payload = {
    // Keep payload aligned with app-side SupabaseService.createNotification schema
    user_id: "5afad7d4-3dcd-4353-badb-4f155303419a", // Real user ID for testing
    title: `[TEST] ${notificationContent.title}`,
    message: notificationContent.body,
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
    throw new Error(`Supabase test insert failed: ${res.status} ${text}`);
  }

  const json = await res.json();
  console.log("🗃️ Supabase test insert success:", json);
}

// Wellness message categories with varied content for different times of day
const WELLNESS_MESSAGES = {
  morning: [
    {
      title: "Good Morning! 🌅",
      body: "Start your day with 5 deep breaths. Inhale positivity, exhale tension.",
      type: "breathing",
    },
    {
      title: "Rise & Shine ✨",
      body: "Try the 5-4-3-2-1 grounding: 5 things you see, 4 you feel, 3 you hear, 2 you smell, 1 you taste.",
      type: "grounding",
    },
    {
      title: "Morning Mindfulness 🧘",
      body: "Today is a fresh start. Set a positive intention for the hours ahead.",
      type: "affirmation",
    },
    {
      title: "Breathe & Begin 💚",
      body: "Box breathing: Inhale 4 counts, hold 4, exhale 4, hold 4. Repeat 3 times.",
      type: "breathing",
    },
    {
      title: "New Day Energy ⚡",
      body: "Gentle reminder: You have the strength to handle whatever today brings.",
      type: "affirmation",
    },
  ],
  afternoon: [
    {
      title: "Midday Reset 🔄",
      body: "Feeling overwhelmed? Try progressive muscle relaxation - tense and release each muscle group.",
      type: "relaxation",
    },
    {
      title: "Afternoon Check-in 💭",
      body: "Pause and breathe. How are you feeling right now? Acknowledge without judgment.",
      type: "mindfulness",
    },
    {
      title: "Energy Boost 🚀",
      body: "4-7-8 breathing: Inhale for 4, hold for 7, exhale for 8. Perfect for afternoon stress.",
      type: "breathing",
    },
    {
      title: "Grounding Moment 🌱",
      body: "Notice your feet on the ground. Feel your connection to the earth beneath you.",
      type: "grounding",
    },
    {
      title: "Stress Relief 🌸",
      body: "Quick tip: Drink some water and stretch your shoulders. Your body will thank you.",
      type: "wellness",
    },
  ],
  evening: [
    {
      title: "Evening Reflection 🌙",
      body: "What went well today? Celebrate one small victory before bed.",
      type: "reflection",
    },
    {
      title: "Wind Down Time 🕯️",
      body: "Belly breathing: Place one hand on chest, one on belly. Breathe so only the belly hand moves.",
      type: "breathing",
    },
    {
      title: "Night Gratitude ⭐",
      body: "Name three things you're grateful for today, no matter how small.",
      type: "gratitude",
    },
    {
      title: "Sleep Preparation 😴",
      body: "Release today's tension. Tomorrow is a new opportunity to thrive.",
      type: "affirmation",
    },
    {
      title: "Peaceful Evening 🌺",
      body: "Try the 'body scan' - mentally check each part of your body and consciously relax it.",
      type: "relaxation",
    },
  ],
};

// Track sent wellness messages to prevent repetition
let sentWellnessMessages: {
  morning: number[];
  afternoon: number[];
  evening: number[];
} = {
  morning: [],
  afternoon: [],
  evening: [],
};

// Scheduled wellness reminders - runs multiple times daily
export const sendWellnessReminders = functions.pubsub
  .schedule("0 9,17,23 * * *") // 9 AM, 5 PM, 11 PM daily
  .timeZone("America/New_York") // Adjust timezone as needed
  .onRun(async (context) => {
    try {
      const currentHour = new Date().getHours();
      let timeCategory: keyof typeof WELLNESS_MESSAGES;

      // Determine time category
      if (currentHour >= 6 && currentHour < 12) {
        timeCategory = "morning";
      } else if (currentHour >= 12 && currentHour < 18) {
        timeCategory = "afternoon";
      } else {
        timeCategory = "evening";
      }

      // Get a non-repeating message
      const message = getRandomWellnessMessage(timeCategory);

      if (!message) {
        console.log("No new messages available for", timeCategory);
        return null;
      }

      // Send FCM notification
      const fcmMessage = {
        data: {
          type: "wellness_reminder",
          category: timeCategory,
          messageType: message.type,
          timestamp: Date.now().toString(),
        },
        notification: {
          title: message.title,
          body: message.body,
        },
        android: {
          priority: "normal" as const,
          notification: {
            channelId: "wellness_reminders",
            priority: "default" as const,
            defaultSound: true,
            tag: `wellness_${timeCategory}_${Date.now()}`,
          },
        },
        topic: "wellness_reminders",
      };

      const response = await admin.messaging().send(fcmMessage);
      console.log(`✅ ${timeCategory} wellness reminder sent:`, response);

      return response;
    } catch (error) {
      console.error("❌ Error sending wellness reminder:", error);
      throw error;
    }
  });

// Manual wellness reminder trigger (for testing and immediate sending)
export const sendManualWellnessReminder = functions.https.onCall(
  async (data, context) => {
    try {
      const { timeCategory } = data;

      if (!["morning", "afternoon", "evening"].includes(timeCategory)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid time category"
        );
      }

      const message = getRandomWellnessMessage(timeCategory);

      if (!message) {
        return { success: false, message: "No new messages available" };
      }

      const fcmMessage = {
        data: {
          type: "wellness_reminder",
          category: timeCategory,
          messageType: message.type,
          timestamp: Date.now().toString(),
        },
        notification: {
          title: message.title,
          body: message.body,
        },
        android: {
          priority: "normal" as const,
          notification: {
            channelId: "wellness_reminders",
            priority: "default" as const,
            defaultSound: true,
            tag: `manual_wellness_${timeCategory}_${Date.now()}`,
          },
        },
        topic: "wellness_reminders",
      };

      const response = await admin.messaging().send(fcmMessage);
      console.log("✅ Manual wellness reminder sent:", response);

      return { success: true, messageId: response, message: message };
    } catch (error) {
      console.error("❌ Error sending manual wellness reminder:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send wellness reminder"
      );
    }
  }
);

// Helper function to get random wellness message without repetition
function getRandomWellnessMessage(
  timeCategory: keyof typeof WELLNESS_MESSAGES
) {
  const messages = WELLNESS_MESSAGES[timeCategory];
  const sentIndices = sentWellnessMessages[timeCategory];

  // If all messages have been sent, reset the tracker
  if (sentIndices.length >= messages.length) {
    sentWellnessMessages[timeCategory] = [];
  }

  // Get available message indices
  const availableIndices = messages
    .map((_, index) => index)
    .filter((index) => !sentIndices.includes(index));

  if (availableIndices.length === 0) {
    return null;
  }

  // Select random available message
  const randomIndex =
    availableIndices[Math.floor(Math.random() * availableIndices.length)];
  const selectedMessage = messages[randomIndex];

  // Mark this message as sent
  sentWellnessMessages[timeCategory].push(randomIndex);

  return selectedMessage;
}

// Multi-parameter anxiety detection Cloud Function
export const detectAnxietyMultiParameter = functions.database
  .ref("/devices/{deviceId}/current")
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const afterData = change.after.val();

    console.log(`Processing metrics update for device ${deviceId}`);

    // Validate required data
    if (!afterData || !afterData.heartRate || !afterData.spo2) {
      console.log("Missing required metrics data, skipping");
      return null;
    }

    try {
      // Get device info to find user
      const deviceRef = admin.database().ref(`/devices/${deviceId}/metadata`);
      const deviceSnapshot = await deviceRef.once("value");
      const deviceInfo = deviceSnapshot.val();

      if (!deviceInfo || !deviceInfo.userId) {
        console.log("Device info or userId not found");
        return null;
      }

      // Get user's baseline HR from Supabase
      const userRef = admin
        .database()
        .ref(`/users/${deviceInfo.userId}/baseline`);
      const baselineSnapshot = await userRef.once("value");
      const baseline = baselineSnapshot.val();

      if (!baseline || !baseline.baselineHR) {
        console.log(`No baseline found for user ${deviceInfo.userId}`);
        return null;
      }

      // Analyze heart rate (20-30% above baseline)
      const currentHR = afterData.heartRate;
      const restingHR = baseline.baselineHR;
      const hrThreshold = restingHR * 1.2; // 20% above
      const severityThreshold = restingHR * 1.3; // 30% above

      let hrAnalysis = { abnormal: false, severity: "normal", confidence: 0.6 };
      if (currentHR > severityThreshold) {
        hrAnalysis = { abnormal: true, severity: "high", confidence: 0.8 };
      } else if (currentHR > hrThreshold) {
        hrAnalysis = { abnormal: true, severity: "elevated", confidence: 0.7 };
      }

      // Analyze SpO2 levels
      const currentSpO2 = afterData.spo2;
      let spo2Analysis = {
        abnormal: false,
        severity: "normal",
        confidence: 0.6,
      };
      if (currentSpO2 < 90) {
        spo2Analysis = {
          abnormal: true,
          severity: "critical",
          confidence: 1.0,
        };
      } else if (currentSpO2 < 94) {
        spo2Analysis = { abnormal: true, severity: "low", confidence: 0.8 };
      }

      // Analyze movement (simple spike detection)
      const currentMovement = afterData.movementLevel || 0;
      let movementAnalysis = {
        abnormal: false,
        severity: "normal",
        confidence: 0.6,
      };
      if (currentMovement > 80) {
        movementAnalysis = {
          abnormal: true,
          severity: "high",
          confidence: 0.7,
        };
      }

      // Count abnormal metrics
      const abnormalMetrics = [
        hrAnalysis,
        spo2Analysis,
        movementAnalysis,
      ].filter((a) => a.abnormal);
      const abnormalCount = abnormalMetrics.length;

      // Apply trigger logic
      let triggered = false;
      let requiresUserConfirmation = true;
      let overallConfidence = 0.6;
      let reason = "normal";

      if (spo2Analysis.abnormal && spo2Analysis.severity === "critical") {
        // Critical SpO2 always triggers immediately
        triggered = true;
        requiresUserConfirmation = false;
        overallConfidence = 1.0;
        reason = "criticalSpO2";
      } else if (abnormalCount >= 2) {
        // Multiple abnormal metrics - auto-trigger
        triggered = true;
        requiresUserConfirmation = false;
        overallConfidence = 0.85;
        reason = "multipleAbnormal";
      } else if (abnormalCount === 1) {
        // Single abnormal metric - request user confirmation
        triggered = true;
        requiresUserConfirmation = true;
        overallConfidence = 0.65;
        reason =
          abnormalMetrics[0].severity === "critical"
            ? "singleCritical"
            : "singleAbnormal";
      }

      if (triggered) {
        console.log(
          `Anxiety detected: ${reason} (confidence: ${overallConfidence})`
        );

        // Store alert
        const alertData = {
          deviceId,
          userId: deviceInfo.userId,
          timestamp: Date.now(),
          reason,
          confidence: overallConfidence,
          requiresUserConfirmation,
          metrics: {
            heartRate: currentHR,
            baselineHR: restingHR,
            spO2: currentSpO2,
            movement: currentMovement,
          },
          analysis: {
            heartRate: hrAnalysis,
            spO2: spo2Analysis,
            movement: movementAnalysis,
          },
        };

        await admin
          .database()
          .ref(`/devices/${deviceId}/anxiety_alerts`)
          .push(alertData);

        // Send notification
        const notificationTitle = requiresUserConfirmation
          ? "Are you feeling anxious?"
          : "Anxiety Alert Detected";

        const notificationBody = requiresUserConfirmation
          ? `We detected some changes in your metrics. HR: ${currentHR} BPM, SpO2: ${currentSpO2}%`
          : `Multiple concerning metrics detected. Please check your wellbeing.`;

        const message = {
          data: {
            type: "anxiety_detection",
            reason,
            confidence: overallConfidence.toString(),
            requiresConfirmation: requiresUserConfirmation.toString(),
            heartRate: currentHR.toString(),
            spO2: currentSpO2.toString(),
            deviceId,
            timestamp: Date.now().toString(),
          },
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          topic: `user_${deviceInfo.userId}_anxiety_alerts`,
        };

        await admin.messaging().send(message);
        console.log("Notification sent successfully");
      }

      return {
        processed: true,
        triggered,
        reason,
        confidence: overallConfidence,
      };
    } catch (error) {
      console.error("Error in anxiety detection:", error);
      return null;
    }
  });
