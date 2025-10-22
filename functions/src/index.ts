import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Optional: Supabase server-side persistence for test notifications
// Configure via environment variables (Firebase Functions config or runtime env)
// const SUPABASE_URL =
//   process.env.SUPABASE_URL || functions.config().supabase?.url;
// const SUPABASE_SERVICE_ROLE_KEY =
//   process.env.SUPABASE_SERVICE_ROLE_KEY ||
//   functions.config().supabase?.service_role_key;

// Lazy import to avoid hard dependency when not configured
// let fetchImpl: any = null;
// try {
//   // Node 18+ has global fetch; fallback not needed normally
//   fetchImpl = (global as any).fetch || require("node-fetch");
// } catch {}

// Import and export data cleanup functions
export {
  cleanupHealthData,
  aggregateHealthDataHourly,
  monitorFirebaseUsage,
} from "./dataCleanup";

// Import and export SMART device data sync (eliminates redundancy)
export {
  smartDeviceDataSync,
  removeTimestampDuplicates,
  monitorDuplicationPrevention,
} from "./smartDeviceDataSync";

// Import legacy device functions for compatibility (assignment functions still needed)
// NOTE: Removed copyDeviceDataToUserSession and copyDeviceCurrentToUserSession
// as they create timestamp duplicates. smartDeviceDataSync now handles this properly.
export {
  assignDeviceToUser,
  getDeviceAssignment,
  cleanupOldSessions,
} from "./deviceDataCopyService";

// Import and export enhanced rate limiting functions (remove testing functions)
export { handleUserConfirmationResponse } from "./enhancedRateLimiting";

// Import auto history creator
export { autoCreateDeviceHistory } from "./autoHistoryCreator";

// Import real-time sustained anxiety detection
export {
  realTimeSustainedAnxietyDetection,
  clearAnxietyRateLimits,
} from "./realTimeSustainedAnxietyDetection";

// Import auto-cleanup functions
export { autoCleanup } from "./autoCleanup";
export { manualCleanup } from "./autoCleanup";
export { getCleanupStats } from "./autoCleanup";

// Import device assignment sync functions (remove testing functions)
export {
  syncDeviceAssignment,
  periodicDeviceSync,
} from "./deviceAssignmentSync";

// Remove appointment expiration functions - appointments are handled in Supabase, not Firebase
// export {
//   checkExpiredAppointments,
//   expireAppointmentsNow,
//   triggerAppointmentExpiration,
// } from "./appointmentExpiration";

// Send FCM when a MANUAL TEST alert is created under devices/<deviceId>/alerts
// Used for testing/demo purposes ONLY (e.g., test_anxiety_alerts.js)
// Real anxiety alerts from realTimeSustainedAnxietyDetection are handled there
// IMPORTANT: Must be in same region as RTDB (asia-southeast1)
export const onNativeAlertCreate = functions
  .region("asia-southeast1")
  .database.ref("/devices/{deviceId}/alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    try {
      const alert = snapshot.val() as any;
      if (!alert) return null;

      const deviceId = context.params.deviceId;
      const severity = (alert.severity || "").toLowerCase();
      const heartRate = alert.heartRate;
      const ts = alert.timestamp || Date.now();
      const baseline = alert.baseline || 73.2; // Get baseline from alert or use default
      const userId = alert.userId; // Get userId if provided
      const source = alert.source || "unknown"; // NEW: Check if this is a manual test

      // CRITICAL: Only process MANUAL test alerts (from test scripts)
      // Real anxiety alerts are handled by realTimeSustainedAnxietyDetection
      if (source !== "sensor" && source !== "test") {
        console.log(
          `⚠️ onNativeAlertCreate: Skipping alert from unknown source: ${source}`
        );
        return null;
      }

      // For manual tests (test_anxiety_alerts.js), source will be "sensor" or "test"
      console.log(
        `📱 onNativeAlertCreate: Processing MANUAL test alert (source: ${source})`
      );

      if (!["mild", "moderate", "severe", "critical"].includes(severity)) {
        console.log(`Skipping alert with invalid severity: ${severity}`);
        return null;
      }

      // Get the assigned user's FCM token from device assignment
      let fcmToken = null;
      try {
        const assignmentSnapshot = await admin
          .database()
          .ref(`/devices/${deviceId}/assignment`)
          .once("value");

        if (assignmentSnapshot.exists()) {
          const assignment = assignmentSnapshot.val();
          fcmToken = assignment.fcmToken;
          const assignedUserId = assignment.assignedUser;

          console.log(
            `📱 Device ${deviceId} assigned to user: ${assignedUserId}`
          );
          console.log(`🔑 FCM Token found: ${fcmToken ? "Yes" : "No"}`);

          if (!fcmToken) {
            console.log(
              `⚠️ No FCM token found for device ${deviceId} assignment`
            );
            return null;
          }
        } else {
          console.log(`⚠️ No assignment found for device ${deviceId}`);
          return null;
        }
      } catch (error) {
        console.error(`❌ Error fetching device assignment: ${error}`);
        return null;
      }

      // Calculate percentage above baseline
      const percentageAbove =
        baseline > 0
          ? Math.round(((heartRate - baseline) / baseline) * 100)
          : 0;

      const { title, body } = getNotificationContent(
        severity,
        heartRate,
        baseline
      );

      // RATE LIMITING: Check if user was recently notified (same 5-min cooldown as realTimeSustainedAnxietyDetection)
      // Get userId from assignment
      const assignedUserId = (
        await admin
          .database()
          .ref(`/devices/${deviceId}/assignment/assignedUser`)
          .once("value")
      ).val();

      if (assignedUserId) {
        const RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000; // 5 minutes
        const now = Date.now();
        const rateLimitRef = admin
          .database()
          .ref(`/users/${assignedUserId}/lastAnxietyNotification`);

        // Use transaction to prevent race conditions
        const rateLimitResult = await rateLimitRef.transaction(
          (currentValue) => {
            const lastNotificationTime = currentValue || 0;
            const timeSinceLastNotification = now - lastNotificationTime;

            // If within cooldown window, abort transaction
            if (timeSinceLastNotification < RATE_LIMIT_WINDOW_MS) {
              return; // Abort
            }

            // Outside cooldown - update with current time
            return now;
          }
        );

        // Check if transaction succeeded
        if (!rateLimitResult.committed) {
          const lastNotificationSnapshot = await rateLimitRef.once("value");
          const lastNotification = lastNotificationSnapshot.val() || 0;
          const timeSinceLastNotification = now - lastNotification;
          const remainingSeconds = Math.ceil(
            (RATE_LIMIT_WINDOW_MS - timeSinceLastNotification) / 1000
          );
          console.log(
            `⏱️ onNativeAlertCreate: Rate limit blocked for user ${assignedUserId}. ` +
              `Last notification ${Math.floor(
                timeSinceLastNotification / 1000
              )}s ago (${remainingSeconds}s remaining)`
          );
          return null; // Skip sending notification
        }

        console.log(
          `✅ onNativeAlertCreate: Rate limit passed for user ${assignedUserId}, sending notification`
        );
      }

      // Enhanced notification structure with proper sound support and complete data
      // Send to SPECIFIC USER TOKEN as DATA-ONLY (app handles display)
      const message = {
        token: fcmToken, // ✅ Target specific user!
        data: {
          type: "anxiety_alert",
          severity: severity,
          heartRate: heartRate?.toString() || "N/A",
          baseline: baseline.toString(),
          percentageAbove: percentageAbove.toString(),
          timestamp: ts.toString(),
          notificationId: `${severity}_${ts}`,
          deviceId: deviceId,
          userId: userId || "",
          title: title,
          message: body,
          channelId: getChannelIdForSeverity(severity),
          sound: getSoundForSeverity(severity),
          color: getSeverityColor(severity),
          requiresConfirmation: "false",
          alertType: "direct",
          // Enhanced features - ALL must be strings
          vibrationPattern: getVibrationPattern(severity),
          importance: getNotificationImportance(severity),
          largeIcon: getSeverityIcon(severity),
          badge: getBadgeCount(severity).toString(), // ✅ Convert number to string
          category: "ANXIETY_ALERT",
          showTimestamp: "true",
          autoCancel: "false",
          ongoing: (
            severity === "critical" || severity === "severe"
          ).toString(),
        },
        android: {
          priority: "high" as const,
          // Removed notification config - data-only for app handling
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1, // Silent push for data-only
              category: "ANXIETY_ALERT",
              badge: getBadgeCount(severity),
              sound: getSoundForSeverity(severity).replace(".mp3", ""), // iOS doesn't need .mp3 extension
            },
          },
        },
      } as any;

      const response = await admin.messaging().send(message);
      console.log(
        `✅ FCM sent to specific user token from onNativeAlertCreate: ${response}`
      );
      console.log(
        `✅ FCM sent to specific user token from onNativeAlertCreate: ${response}`
      );
      return response;
    } catch (error) {
      console.error("❌ Error in onNativeAlertCreate:", error);
      throw error;
    }
  });

// Helper function to get notification content based on severity
// Now matches the friendly, conversational tone from realTimeSustainedAnxietyDetection
function getNotificationContent(
  severity: string,
  heartRate?: number,
  baseline?: number
) {
  const hrText = heartRate ? ` ${heartRate} BPM` : "";
  const percentageText =
    heartRate && baseline && baseline > 0
      ? ` (${Math.round(
          ((heartRate - baseline) / baseline) * 100
        )}% above baseline)`
      : "";

  switch (severity) {
    case "mild":
      return {
        title: "🟢 Mild Alert - 60% Confidence",
        body: `I noticed a slight increase in your heart rate to${hrText}${percentageText}. Are you experiencing any anxiety or is this just normal activity?`,
      };
    case "moderate":
      return {
        title: "� Moderate Alert - 70% Confidence",
        body: `Your heart rate increased to${hrText}${percentageText}. How are you feeling? Is everything alright?`,
      };
    case "severe":
      return {
        title: "🔴 Severe Alert - 85% Confidence",
        body: `Hi there! I noticed your heart rate was elevated to${hrText}${percentageText}. Are you experiencing any anxiety or stress right now?`,
      };
    case "critical":
      return {
        title: "🚨 Critical Alert - 95% Confidence",
        body: `URGENT: Your heart rate has been critically elevated at${hrText}${percentageText}. This indicates a severe anxiety episode. Please seek immediate support if needed.`,
      };
    default:
      return {
        title: "📱 AnxieEase Alert",
        body: `Heart rate check:${hrText}${percentageText}`,
      };
  }
}

// Helper function to get correct channel ID for severity
function getChannelIdForSeverity(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "mild_anxiety_alerts_v4";
    case "moderate":
      return "moderate_anxiety_alerts_v2";
    case "severe":
      return "severe_anxiety_alerts_v2";
    case "critical":
      return "critical_anxiety_alerts_v2";
    default:
      return "anxiease_channel";
  }
}

// Helper function to get correct sound for severity
// Uses PLURAL filenames to match actual MP3 files (mild_alerts.mp3, etc.)
function getSoundForSeverity(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "mild_alerts.mp3";
    case "moderate":
      return "moderate_alerts.mp3";
    case "severe":
      return "severe_alerts.mp3";
    case "critical":
      return "critical_alerts.mp3";
    default:
      return "default";
  }
}

// Helper function to get color for severity
// Synced with realTimeSustainedAnxietyDetection for consistency
function getSeverityColor(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "#4CAF50"; // Green
    case "moderate":
      return "#FFFF00"; // Yellow (matches realTimeSustainedAnxietyDetection)
    case "severe":
      return "#FFA500"; // Orange (matches realTimeSustainedAnxietyDetection)
    case "critical":
      return "#FF0000"; // Red (matches realTimeSustainedAnxietyDetection)
    default:
      return "#2196F3"; // Blue
  }
}

// Helper function to get vibration pattern for severity
// Pattern format: [delay, vibrate, delay, vibrate, ...]
function getVibrationPattern(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "0,200,100,200"; // Short double vibrate
    case "moderate":
      return "0,300,200,300"; // Medium double vibrate
    case "severe":
      return "0,400,200,400,200,400"; // Triple vibrate
    case "critical":
      return "0,500,300,500,300,500,300,500"; // Urgent quad vibrate
    default:
      return "0,250"; // Single vibrate
  }
}

// Helper function to get notification importance/priority
function getNotificationImportance(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "default"; // Normal importance
    case "moderate":
      return "high"; // High importance
    case "severe":
      return "max"; // Maximum importance
    case "critical":
      return "max"; // Maximum importance + urgent
    default:
      return "default";
  }
}

// Helper function to get large icon for severity
function getSeverityIcon(severity: string): string {
  switch (severity.toLowerCase()) {
    case "mild":
      return "ic_mild_alert"; // Green icon
    case "moderate":
      return "ic_moderate_alert"; // Yellow icon
    case "severe":
      return "ic_severe_alert"; // Orange icon
    case "critical":
      return "ic_critical_alert"; // Red icon
    default:
      return "ic_notification"; // Default icon
  }
}

// Helper function to get badge count (for app icon badge)
function getBadgeCount(severity: string): number {
  switch (severity.toLowerCase()) {
    case "mild":
      return 1;
    case "moderate":
      return 2;
    case "severe":
      return 3;
    case "critical":
      return 5; // Highest badge for critical
    default:
      return 1;
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

// Cloud Function to test FCM notifications (for debugging) - REMOVED TO REDUCE FUNCTION COUNT
/*
export const sendTestNotificationV2 = functions.https.onCall(
  async (data, context) => {
    try {
      const { severity = "mild", heartRate = 75 } = data;

      const notificationData = getNotificationContent(severity, heartRate);

      // DATA-ONLY test message with proper channel and sound
      const message = {
        data: {
          type: "anxiety_alert",
          severity: severity,
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `[TEST] ${notificationData.title}`,
          message: notificationData.body,
          // Add proper channel and sound for test notifications
          channelId: getChannelIdForSeverity(severity),
          sound: getSoundForSeverity(severity),
          color: getSeverityColor(severity),
          requiresConfirmation: "false",
          alertType: "test",
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
*/

// Individual HTTP endpoints for testing each severity level
export const testMildNotification = functions.https.onRequest(
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const heartRate = 88;
      const notificationContent = getNotificationContent("mild", heartRate);

      const message = {
        data: {
          type: "anxiety_alert",
          severity: "mild",
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `${notificationContent.title}`,
          message: notificationContent.body,
          channelId: getChannelIdForSeverity("mild"),
          sound: getSoundForSeverity("mild"),
          color: getSeverityColor("mild"),
          requiresConfirmation: "false",
          alertType: "http_test",
        },
        notification: {
          title: notificationContent.title,
          body: notificationContent.body,
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: getChannelIdForSeverity("mild"),
            sound: "mild_alerts", // Remove .mp3 extension for Android
            priority: "max" as const,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
              sound: "mild_alerts.mp3", // iOS can use .mp3
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Mild notification sent:", response);

      res.status(200).json({
        success: true,
        messageId: response,
        severity: "mild",
        heartRate: heartRate,
        sound: getSoundForSeverity("mild"),
        channelId: getChannelIdForSeverity("mild"),
        message: "Mild anxiety notification sent successfully!",
      });
    } catch (error) {
      console.error("❌ Error sending mild notification:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

export const testModerateNotification = functions.https.onRequest(
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const heartRate = 108;
      const notificationContent = getNotificationContent("moderate", heartRate);

      const message = {
        data: {
          type: "anxiety_alert",
          severity: "moderate",
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `${notificationContent.title}`,
          message: notificationContent.body,
          channelId: getChannelIdForSeverity("moderate"),
          sound: getSoundForSeverity("moderate"),
          color: getSeverityColor("moderate"),
          requiresConfirmation: "false",
          alertType: "http_test",
        },
        notification: {
          title: notificationContent.title,
          body: notificationContent.body,
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: getChannelIdForSeverity("moderate"),
            sound: "moderate_alerts", // Remove .mp3 extension for Android
            priority: "max" as const,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
              sound: "moderate_alerts.mp3", // iOS can use .mp3
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Moderate notification sent:", response);

      res.status(200).json({
        success: true,
        messageId: response,
        severity: "moderate",
        heartRate: heartRate,
        sound: getSoundForSeverity("moderate"),
        channelId: getChannelIdForSeverity("moderate"),
        message: "Moderate anxiety notification sent successfully!",
      });
    } catch (error) {
      console.error("❌ Error sending moderate notification:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

export const testSevereNotification = functions.https.onRequest(
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const heartRate = 125;
      const notificationContent = getNotificationContent("severe", heartRate);

      const message = {
        data: {
          type: "anxiety_alert",
          severity: "severe",
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `${notificationContent.title}`,
          message: notificationContent.body,
          channelId: getChannelIdForSeverity("severe"),
          sound: getSoundForSeverity("severe"),
          color: getSeverityColor("severe"),
          requiresConfirmation: "false",
          alertType: "http_test",
        },
        notification: {
          title: notificationContent.title,
          body: notificationContent.body,
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: getChannelIdForSeverity("severe"),
            sound: "severe_alerts", // Remove .mp3 extension for Android
            priority: "max" as const,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
              sound: "severe_alerts.mp3", // iOS can use .mp3
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Severe notification sent:", response);

      res.status(200).json({
        success: true,
        messageId: response,
        severity: "severe",
        heartRate: heartRate,
        sound: getSoundForSeverity("severe"),
        channelId: getChannelIdForSeverity("severe"),
        message: "Severe anxiety notification sent successfully!",
      });
    } catch (error) {
      console.error("❌ Error sending severe notification:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

export const testCriticalNotification = functions.https.onRequest(
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const heartRate = 145;
      const notificationContent = getNotificationContent("critical", heartRate);

      const message = {
        data: {
          type: "anxiety_alert",
          severity: "critical",
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `${notificationContent.title}`,
          message: notificationContent.body,
          channelId: getChannelIdForSeverity("critical"),
          sound: getSoundForSeverity("critical"),
          color: getSeverityColor("critical"),
          requiresConfirmation: "false",
          alertType: "http_test",
        },
        notification: {
          title: notificationContent.title,
          body: notificationContent.body,
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: getChannelIdForSeverity("critical"),
            sound: "critical_alerts", // Remove .mp3 extension for Android
            priority: "max" as const,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              "content-available": 1,
              category: "ANXIETY_ALERT",
              sound: "critical_alerts.mp3", // iOS can use .mp3
            },
          },
        },
        topic: "anxiety_alerts",
      } as any;

      const response = await admin.messaging().send(message);
      console.log("✅ Critical notification sent:", response);

      res.status(200).json({
        success: true,
        messageId: response,
        severity: "critical",
        heartRate: heartRate,
        sound: getSoundForSeverity("critical"),
        channelId: getChannelIdForSeverity("critical"),
        message: "CRITICAL anxiety notification sent successfully!",
      });
    } catch (error) {
      console.error("❌ Error sending critical notification:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/* Commented out - replaced with individual test functions for each severity level
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

      // DATA-ONLY HTTP test message with proper channel and sound
      const message = {
        data: {
          type: "anxiety_alert",
          severity: severity as string,
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
          title: `[TEST] ${notificationData.title}`,
          message: notificationData.body,
          // Add proper channel and sound for HTTP test notifications
          channelId: getChannelIdForSeverity(severity as string),
          sound: getSoundForSeverity(severity as string),
          color: getSeverityColor(severity as string),
          requiresConfirmation: "false",
          alertType: "http_test",
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
*/

/*
// Commented out - only used by the commented testNotificationHTTP function
// Persist test alert to Supabase (similar to realTimeSustainedAnxietyDetection)
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
*/

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
    {
      title: "Morning Gratitude 🙏",
      body: "Start with thanks: Name one thing you're grateful for right now, even something small.",
      type: "gratitude",
    },
    {
      title: "Hydration First 💧",
      body: "Before coffee or tasks, drink a glass of water. Your brain needs hydration to think clearly.",
      type: "wellness",
    },
    {
      title: "Gentle Awakening 🌸",
      body: "No need to rush. Take 3 deep breaths and ease into your day with kindness to yourself.",
      type: "mindfulness",
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
    {
      title: "Midday Motivation 💪",
      body: "You're halfway through the day! Every small step forward counts. Keep going.",
      type: "affirmation",
    },
    {
      title: "Tension Release 😌",
      body: "Clench your fists tight for 5 seconds, then release. Feel the tension leave your body.",
      type: "relaxation",
    },
    {
      title: "Progress Check ✅",
      body: "What's one thing you've accomplished today? Celebrate it, no matter how small.",
      type: "reflection",
    },
    {
      title: "Afternoon Reset 🔄",
      body: "Feeling scattered? Place your hand on your heart and take 5 conscious breaths.",
      type: "grounding",
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
    {
      title: "Day's End Wisdom 🦉",
      body: "You survived today's challenges. That's not nothing - that's everything. Be proud.",
      type: "affirmation",
    },
    {
      title: "Transition Ritual 🕯️",
      body: "Create a boundary between day and night. Put down your worries, pick up peace.",
      type: "mindfulness",
    },
    {
      title: "Tomorrow's Promise 🌠",
      body: "Rest knowing tomorrow brings new possibilities. You don't have to solve everything tonight.",
      type: "comfort",
    },
    {
      title: "Gentle Night 🌙",
      body: "Progressive relaxation: Start with your toes, tense for 3 seconds, then release. Work upward.",
      type: "relaxation",
    },
    {
      title: "Self-Compassion 💜",
      body: "Speak to yourself like you would a dear friend. You deserve the same kindness you give others.",
      type: "affirmation",
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

// Scheduled wellness reminders - runs 5 times daily for better anxiety prevention
export const sendWellnessReminders = functions.pubsub
  .schedule("0 8,12,16,20,22 * * *") // 8 AM, 12 PM, 4 PM, 8 PM, 10 PM daily
  .timeZone("Asia/Manila") // Philippine time zone
  .onRun(async (context) => {
    try {
      // Get Philippine time instead of server time
      const philippineTime = new Date().toLocaleString("en-US", {
        timeZone: "Asia/Manila",
        hour12: false,
      });
      const currentHour = parseInt(philippineTime.split(", ")[1].split(":")[0]);

      let timeCategory: keyof typeof WELLNESS_MESSAGES;

      // Determine time category based on Philippine time - updated for 5 daily reminders
      if (currentHour >= 6 && currentHour < 11) {
        timeCategory = "morning";
      } else if (currentHour >= 11 && currentHour < 17) {
        timeCategory = "afternoon";
      } else {
        timeCategory = "evening";
      }

      console.log(
        `🕐 Philippine time hour: ${currentHour}, category: ${timeCategory}`
      );

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

// Daily breathing exercise reminder - runs once daily at 2 PM
export const sendDailyBreathingReminder = functions.pubsub
  .schedule("0 14 * * *") // 2 PM daily
  .timeZone("Asia/Manila") // Philippine time zone
  .onRun(async (context) => {
    try {
      const breathingMessages = [
        {
          title: "🫁 Daily Breathing Exercise",
          body: "Take 5 minutes for deep breathing. Inhale slowly, hold, then exhale completely. Your mind will thank you.",
        },
        {
          title: "🌬️ Breathe & Reset",
          body: "Try the 4-7-8 technique: Inhale for 4, hold for 7, exhale for 8. Perfect for releasing tension.",
        },
        {
          title: "💨 Mindful Breathing",
          body: "Box breathing time: Inhale 4 counts, hold 4, exhale 4, hold 4. Repeat 3 times for instant calm.",
        },
        {
          title: "🍃 Breathing Break",
          body: "Belly breathing: Place one hand on chest, one on belly. Breathe so only the belly hand moves.",
        },
        {
          title: "🌟 Deep Breath Moment",
          body: "Take 3 deep breaths right now. Feel your shoulders relax and your mind clear with each exhale.",
        },
      ];

      // Get a random breathing message
      const message =
        breathingMessages[Math.floor(Math.random() * breathingMessages.length)];

      // Send FCM notification
      const fcmMessage = {
        data: {
          type: "breathing_reminder",
          category: "daily_breathing",
          messageType: "breathing",
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
            tag: `breathing_daily_${Date.now()}`,
          },
        },
        topic: "wellness_reminders",
      };

      const response = await admin.messaging().send(fcmMessage);
      console.log("✅ Daily breathing reminder sent:", response);

      return response;
    } catch (error) {
      console.error("❌ Error sending daily breathing reminder:", error);
      throw error;
    }
  });

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

// ========================
// BATTERY MONITORING FUNCTIONS
// ========================

// Cloud Function to monitor device battery levels and send FCM notifications
export const monitorDeviceBattery = functions.database
  .ref("/devices/{deviceId}/current/battPerc")
  .onUpdate(async (change, context) => {
    try {
      const deviceId = context.params.deviceId;
      const beforeBattery = change.before.val();
      const afterBattery = change.after.val();

      console.log(
        `🔋 Battery changed for device ${deviceId}: ${beforeBattery}% → ${afterBattery}%`
      );

      // Only trigger notifications on battery decrease (not increase/charging)
      if (afterBattery >= beforeBattery) {
        console.log(
          "✅ Battery increased or stayed same, no notification needed"
        );
        return null;
      }

      // Get assigned user ID from device assignment
      const assignmentRef = admin
        .database()
        .ref(`/devices/${deviceId}/assignment`);
      const assignmentSnapshot = await assignmentRef.once("value");
      let assignedUserId = null;

      if (assignmentSnapshot.exists()) {
        const assignmentData = assignmentSnapshot.val();
        assignedUserId = assignmentData?.assignedUser;
      }

      // Get user FCM token for this device (with user validation)
      const fcmToken = await getDeviceFCMToken(deviceId, assignedUserId);
      if (!fcmToken) {
        console.log(
          `❌ No FCM token found for device ${deviceId}${
            assignedUserId ? ` (assigned to user: ${assignedUserId})` : ""
          }`
        );
        return null;
      }

      // Check if we need to send notifications
      const shouldSendLowBattery = afterBattery <= 10 && beforeBattery > 10;
      const shouldSendCriticalBattery = afterBattery <= 5 && beforeBattery > 5;
      const shouldSendDeviceOffline = afterBattery === 0 && beforeBattery > 0;

      if (shouldSendDeviceOffline) {
        await sendBatteryNotification(
          fcmToken,
          "device_offline",
          afterBattery,
          deviceId
        );
      } else if (shouldSendCriticalBattery) {
        await sendBatteryNotification(
          fcmToken,
          "critical_battery",
          afterBattery,
          deviceId
        );
      } else if (shouldSendLowBattery) {
        await sendBatteryNotification(
          fcmToken,
          "low_battery",
          afterBattery,
          deviceId
        );
      }

      return null;
    } catch (error) {
      console.error("❌ Error in battery monitoring:", error);
      return null;
    }
  });

// Helper function to get FCM token for a device with user validation
async function getDeviceFCMToken(
  deviceId: string,
  userId?: string
): Promise<string | null> {
  const db = admin.database();

  try {
    // Try to get FCM token from device assignment with validation
    const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
    const assignmentSnapshot = await assignmentRef.once("value");

    if (assignmentSnapshot.exists()) {
      const assignmentData = assignmentSnapshot.val();
      const fcmToken = assignmentData?.fcmToken;
      const assignedUser = assignmentData?.assignedUser;

      if (fcmToken) {
        // If userId is provided, validate that the token belongs to that user
        if (userId && assignedUser && assignedUser !== userId) {
          console.log(
            `⚠️ Assignment FCM token for device ${deviceId} belongs to user ${assignedUser}, not requesting user ${userId}`
          );
          return null;
        }

        console.log(
          `✅ Found FCM token via assignment for device ${deviceId}${
            userId ? ` (user: ${userId})` : ""
          }`
        );
        return fcmToken;
      }
    }

    // Fallback: try to get from device level (legacy location)
    const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
    const deviceSnapshot = await deviceTokenRef.once("value");

    if (deviceSnapshot.exists()) {
      console.log(
        `✅ Found FCM token at legacy device level for device ${deviceId}`
      );
      return deviceSnapshot.val();
    }

    console.log(`❌ No FCM token found for device ${deviceId}`);
    return null;
  } catch (error) {
    console.error(`❌ Error getting FCM token for device ${deviceId}:`, error);
    return null;
  }
}

// Helper function to send battery notifications
async function sendBatteryNotification(
  fcmToken: string,
  type: "low_battery" | "critical_battery" | "device_offline",
  batteryLevel: number,
  deviceId: string
): Promise<void> {
  try {
    const { title, body, icon } = getBatteryNotificationContent(
      type,
      batteryLevel
    );

    const message = {
      token: fcmToken,
      data: {
        type: type,
        device_id: deviceId,
        battery_level: batteryLevel.toString(),
        title: title,
        body: body,
        timestamp: Date.now().toString(),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      // For background notifications to show properly
      notification: {
        title: title,
        body: body,
        icon: icon,
      },
      android: {
        priority: "high" as const,
        notification: {
          icon: "ic_notification",
          color:
            type === "critical_battery" || type === "device_offline"
              ? "#FF0000"
              : "#FF6B00",
          priority: "high" as const,
          defaultSound: true,
          channelId: "device_alerts_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(
      `✅ Battery notification sent successfully: ${type} for device ${deviceId}`,
      response
    );
  } catch (error) {
    console.error(
      `❌ Error sending battery notification: ${type} for device ${deviceId}:`,
      error
    );
  }
}

// Helper function to get battery notification content
function getBatteryNotificationContent(
  type: "low_battery" | "critical_battery" | "device_offline",
  batteryLevel: number
) {
  switch (type) {
    case "low_battery":
      return {
        title: "⚠️ Low Battery Warning",
        body: `Your wearable device battery is at ${batteryLevel}%. Consider charging soon.`,
        icon: "battery_warning",
      };
    case "critical_battery":
      return {
        title: "🔋 Critical Battery Alert!",
        body: `Your wearable device battery is at ${batteryLevel}%. Please charge immediately!`,
        icon: "battery_alert",
      };
    case "device_offline":
      return {
        title: "📱 Device Disconnected",
        body: "Your wearable device has gone offline due to low battery. Charge and reconnect to resume monitoring.",
        icon: "device_offline",
      };
    default:
      return {
        title: "Battery Alert",
        body: `Device battery: ${batteryLevel}%`,
        icon: "battery_unknown",
      };
  }
}

/**
 * Send wellness reminder to all users (uses user-level FCM tokens)
 * This function sends general wellness notifications to all users regardless of device assignment
 */
export const sendWellnessReminder = functions.https.onCall(
  async (data, context) => {
    try {
      const { title, body, type = "wellness_reminder" } = data;

      if (!title || !body) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Title and body are required"
        );
      }

      console.log(`📢 Sending wellness reminder to all users: ${title}`);

      // Get all users from Firebase Database
      const usersSnapshot = await admin.database().ref("/users").once("value");
      const users = usersSnapshot.val();

      if (!users) {
        console.log("⚠️ No users found for wellness reminder");
        return { success: true, message: "No users to send to", sentCount: 0 };
      }

      const userIds = Object.keys(users);
      console.log(`👥 Found ${userIds.length} users for wellness reminder`);

      let sentCount = 0;
      const sendPromises = [];

      for (const userId of userIds) {
        const sendPromise = sendWellnessReminderToUser(
          userId,
          title,
          body,
          type
        );
        sendPromises.push(sendPromise);
      }

      // Wait for all notifications to be sent
      const results = await Promise.allSettled(sendPromises);

      results.forEach((result, index) => {
        if (result.status === "fulfilled" && result.value) {
          sentCount++;
        } else {
          console.log(
            `⚠️ Failed to send wellness reminder to user ${userIds[index]}`
          );
        }
      });

      console.log(
        `✅ Wellness reminder sent to ${sentCount}/${userIds.length} users`
      );

      return {
        success: true,
        message: `Wellness reminder sent successfully`,
        sentCount,
        totalUsers: userIds.length,
      };
    } catch (error) {
      console.error("❌ Error sending wellness reminder:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send wellness reminder"
      );
    }
  }
);

/**
 * Helper function to send wellness reminder to a specific user
 */
async function sendWellnessReminderToUser(
  userId: string,
  title: string,
  body: string,
  type: string
): Promise<boolean> {
  try {
    // Import the getUserFCMToken function from the anxiety detection module
    const { getUserFCMToken } = await import(
      "./realTimeSustainedAnxietyDetection"
    );

    // Get user-level FCM token for wellness notifications
    const fcmToken = await getUserFCMToken(
      userId,
      undefined,
      "wellness_reminder"
    );

    if (!fcmToken) {
      console.log(`⚠️ No wellness FCM token found for user ${userId}`);
      return false;
    }

    const message = {
      token: fcmToken,
      data: {
        type: type,
        userId: userId,
        title: title,
        body: body,
        timestamp: Date.now().toString(),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: "normal" as const,
        notification: {
          icon: "ic_notification",
          color: "#2D9254", // AnxieEase green color
          channelId: "wellness_reminders",
          priority: "default" as const,
          defaultSound: true,
        },
      },
      apns: {
        headers: {
          "apns-priority": "5", // Normal priority for wellness reminders
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ Wellness reminder sent to user ${userId}:`, response);
    return true;
  } catch (error) {
    console.error(
      `❌ Error sending wellness reminder to user ${userId}:`,
      error
    );
    return false;
  }
}
