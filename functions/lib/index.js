"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendWellnessReminder = exports.monitorDeviceBattery = exports.sendDailyBreathingReminder = exports.sendManualWellnessReminder = exports.sendWellnessReminders = exports.testCriticalNotification = exports.testSevereNotification = exports.testModerateNotification = exports.testMildNotification = exports.subscribeToAnxietyAlertsV2 = exports.onNativeAlertCreate = exports.periodicDeviceSync = exports.syncDeviceAssignment = exports.getCleanupStats = exports.manualCleanup = exports.autoCleanup = exports.clearAnxietyRateLimits = exports.realTimeSustainedAnxietyDetection = exports.autoCreateDeviceHistory = exports.handleUserConfirmationResponse = exports.cleanupOldSessions = exports.getDeviceAssignment = exports.assignDeviceToUser = exports.monitorDuplicationPrevention = exports.removeTimestampDuplicates = exports.smartDeviceDataSync = exports.monitorFirebaseUsage = exports.aggregateHealthDataHourly = exports.cleanupHealthData = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
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
var dataCleanup_1 = require("./dataCleanup");
Object.defineProperty(exports, "cleanupHealthData", { enumerable: true, get: function () { return dataCleanup_1.cleanupHealthData; } });
Object.defineProperty(exports, "aggregateHealthDataHourly", { enumerable: true, get: function () { return dataCleanup_1.aggregateHealthDataHourly; } });
Object.defineProperty(exports, "monitorFirebaseUsage", { enumerable: true, get: function () { return dataCleanup_1.monitorFirebaseUsage; } });
// Import and export SMART device data sync (eliminates redundancy)
var smartDeviceDataSync_1 = require("./smartDeviceDataSync");
Object.defineProperty(exports, "smartDeviceDataSync", { enumerable: true, get: function () { return smartDeviceDataSync_1.smartDeviceDataSync; } });
Object.defineProperty(exports, "removeTimestampDuplicates", { enumerable: true, get: function () { return smartDeviceDataSync_1.removeTimestampDuplicates; } });
Object.defineProperty(exports, "monitorDuplicationPrevention", { enumerable: true, get: function () { return smartDeviceDataSync_1.monitorDuplicationPrevention; } });
// Import legacy device functions for compatibility (assignment functions still needed)
// NOTE: Removed copyDeviceDataToUserSession and copyDeviceCurrentToUserSession
// as they create timestamp duplicates. smartDeviceDataSync now handles this properly.
var deviceDataCopyService_1 = require("./deviceDataCopyService");
Object.defineProperty(exports, "assignDeviceToUser", { enumerable: true, get: function () { return deviceDataCopyService_1.assignDeviceToUser; } });
Object.defineProperty(exports, "getDeviceAssignment", { enumerable: true, get: function () { return deviceDataCopyService_1.getDeviceAssignment; } });
Object.defineProperty(exports, "cleanupOldSessions", { enumerable: true, get: function () { return deviceDataCopyService_1.cleanupOldSessions; } });
// Import and export enhanced rate limiting functions (remove testing functions)
var enhancedRateLimiting_1 = require("./enhancedRateLimiting");
Object.defineProperty(exports, "handleUserConfirmationResponse", { enumerable: true, get: function () { return enhancedRateLimiting_1.handleUserConfirmationResponse; } });
// Import auto history creator
var autoHistoryCreator_1 = require("./autoHistoryCreator");
Object.defineProperty(exports, "autoCreateDeviceHistory", { enumerable: true, get: function () { return autoHistoryCreator_1.autoCreateDeviceHistory; } });
// Import real-time sustained anxiety detection
var realTimeSustainedAnxietyDetection_1 = require("./realTimeSustainedAnxietyDetection");
Object.defineProperty(exports, "realTimeSustainedAnxietyDetection", { enumerable: true, get: function () { return realTimeSustainedAnxietyDetection_1.realTimeSustainedAnxietyDetection; } });
Object.defineProperty(exports, "clearAnxietyRateLimits", { enumerable: true, get: function () { return realTimeSustainedAnxietyDetection_1.clearAnxietyRateLimits; } });
// Import auto-cleanup functions
var autoCleanup_1 = require("./autoCleanup");
Object.defineProperty(exports, "autoCleanup", { enumerable: true, get: function () { return autoCleanup_1.autoCleanup; } });
var autoCleanup_2 = require("./autoCleanup");
Object.defineProperty(exports, "manualCleanup", { enumerable: true, get: function () { return autoCleanup_2.manualCleanup; } });
var autoCleanup_3 = require("./autoCleanup");
Object.defineProperty(exports, "getCleanupStats", { enumerable: true, get: function () { return autoCleanup_3.getCleanupStats; } });
// Import device assignment sync functions (remove testing functions)
var deviceAssignmentSync_1 = require("./deviceAssignmentSync");
Object.defineProperty(exports, "syncDeviceAssignment", { enumerable: true, get: function () { return deviceAssignmentSync_1.syncDeviceAssignment; } });
Object.defineProperty(exports, "periodicDeviceSync", { enumerable: true, get: function () { return deviceAssignmentSync_1.periodicDeviceSync; } });
// Remove appointment expiration functions - appointments are handled in Supabase, not Firebase
// export {
//   checkExpiredAppointments,
//   expireAppointmentsNow,
//   triggerAppointmentExpiration,
// } from "./appointmentExpiration";
// NEW: Send FCM when a native alert is created under devices/<deviceId>/alerts
exports.onNativeAlertCreate = functions.database
    .ref("/devices/{deviceId}/alerts/{alertId}")
    .onCreate(async (snapshot, context) => {
    try {
        const alert = snapshot.val();
        if (!alert)
            return null;
        const deviceId = context.params.deviceId;
        const severity = (alert.severity || "").toLowerCase();
        const heartRate = alert.heartRate;
        const ts = alert.timestamp || Date.now();
        const baseline = alert.baseline || 73.2; // Get baseline from alert or use default
        const userId = alert.userId; // Get userId if provided
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
                console.log(`📱 Device ${deviceId} assigned to user: ${assignedUserId}`);
                console.log(`🔑 FCM Token found: ${fcmToken ? 'Yes' : 'No'}`);
                if (!fcmToken) {
                    console.log(`⚠️ No FCM token found for device ${deviceId} assignment`);
                    return null;
                }
            }
            else {
                console.log(`⚠️ No assignment found for device ${deviceId}`);
                return null;
            }
        }
        catch (error) {
            console.error(`❌ Error fetching device assignment: ${error}`);
            return null;
        }
        // Calculate percentage above baseline
        const percentageAbove = baseline > 0
            ? Math.round(((heartRate - baseline) / baseline) * 100)
            : 0;
        const { title, body } = getNotificationContent(severity, heartRate);
        // Enhanced notification structure with proper sound support and complete data
        // Send to SPECIFIC USER TOKEN as DATA-ONLY (app handles display)
        const message = {
            token: fcmToken,
            data: {
                type: "anxiety_alert",
                severity,
                heartRate: (heartRate === null || heartRate === void 0 ? void 0 : heartRate.toString()) || "N/A",
                baseline: baseline.toString(),
                percentageAbove: percentageAbove.toString(),
                timestamp: ts.toString(),
                notificationId: `${severity}_${ts}`,
                deviceId: deviceId,
                userId: userId || "",
                title,
                message: body,
                channelId: getChannelIdForSeverity(severity),
                sound: getSoundForSeverity(severity),
                color: getSeverityColor(severity),
                requiresConfirmation: "false",
                alertType: "direct",
            },
            android: {
                priority: "high",
                // Removed notification config - data-only for app handling
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
        };
        const response = await admin.messaging().send(message);
        console.log(`✅ FCM sent to specific user token from onNativeAlertCreate: ${response}`);
        console.log(`✅ FCM sent to specific user token from onNativeAlertCreate: ${response}`);
        return response;
    }
    catch (error) {
        console.error("❌ Error in onNativeAlertCreate:", error);
        throw error;
    }
});
// Helper function to get notification content based on severity
function getNotificationContent(severity, heartRate) {
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
        case "critical":
            return {
                title: "🚨 CRITICAL Alert - 95% Confidence",
                body: `EMERGENCY: Critical anxiety detected!${hrText}`,
            };
        default:
            return {
                title: "📱 AnxieEase Alert",
                body: `Anxiety level detected.${hrText}`,
            };
    }
}
// Helper function to get correct channel ID for severity
function getChannelIdForSeverity(severity) {
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
function getSoundForSeverity(severity) {
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
function getSeverityColor(severity) {
    switch (severity.toLowerCase()) {
        case "mild":
            return "#4CAF50"; // Green
        case "moderate":
            return "#FF9800"; // Orange
        case "severe":
            return "#F44336"; // Red
        case "critical":
            return "#8B0000"; // Dark Red
        default:
            return "#2196F3"; // Blue
    }
}
// Cloud Function to subscribe new users to the anxiety alerts topic
exports.subscribeToAnxietyAlertsV2 = functions.https.onCall(async (data, context) => {
    try {
        const { fcmToken } = data;
        if (!fcmToken) {
            throw new functions.https.HttpsError("invalid-argument", "FCM token is required");
        }
        // Subscribe the token to the anxiety_alerts topic
        const response = await admin
            .messaging()
            .subscribeToTopic([fcmToken], "anxiety_alerts");
        console.log("✅ Successfully subscribed to anxiety_alerts topic:", response);
        return { success: true, message: "Subscribed to anxiety alerts" };
    }
    catch (error) {
        console.error("❌ Error subscribing to topic:", error);
        throw new functions.https.HttpsError("internal", "Failed to subscribe to notifications");
    }
});
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
exports.testMildNotification = functions.https.onRequest(async (req, res) => {
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
                priority: "high",
                notification: {
                    channelId: getChannelIdForSeverity("mild"),
                    sound: "mild_alerts",
                    priority: "max",
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
        };
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
    }
    catch (error) {
        console.error("❌ Error sending mild notification:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error",
        });
    }
});
exports.testModerateNotification = functions.https.onRequest(async (req, res) => {
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
                priority: "high",
                notification: {
                    channelId: getChannelIdForSeverity("moderate"),
                    sound: "moderate_alerts",
                    priority: "max",
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
        };
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
    }
    catch (error) {
        console.error("❌ Error sending moderate notification:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error",
        });
    }
});
exports.testSevereNotification = functions.https.onRequest(async (req, res) => {
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
                priority: "high",
                notification: {
                    channelId: getChannelIdForSeverity("severe"),
                    sound: "severe_alerts",
                    priority: "max",
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
        };
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
    }
    catch (error) {
        console.error("❌ Error sending severe notification:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error",
        });
    }
});
exports.testCriticalNotification = functions.https.onRequest(async (req, res) => {
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
                priority: "high",
                notification: {
                    channelId: getChannelIdForSeverity("critical"),
                    sound: "critical_alerts",
                    priority: "max",
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
        };
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
    }
    catch (error) {
        console.error("❌ Error sending critical notification:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error",
        });
    }
});
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
let sentWellnessMessages = {
    morning: [],
    afternoon: [],
    evening: [],
};
// Scheduled wellness reminders - runs 5 times daily for better anxiety prevention
exports.sendWellnessReminders = functions.pubsub
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
        let timeCategory;
        // Determine time category based on Philippine time - updated for 5 daily reminders
        if (currentHour >= 6 && currentHour < 11) {
            timeCategory = "morning";
        }
        else if (currentHour >= 11 && currentHour < 17) {
            timeCategory = "afternoon";
        }
        else {
            timeCategory = "evening";
        }
        console.log(`🕐 Philippine time hour: ${currentHour}, category: ${timeCategory}`);
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
                priority: "normal",
                notification: {
                    channelId: "wellness_reminders",
                    priority: "default",
                    defaultSound: true,
                    tag: `wellness_${timeCategory}_${Date.now()}`,
                },
            },
            topic: "wellness_reminders",
        };
        const response = await admin.messaging().send(fcmMessage);
        console.log(`✅ ${timeCategory} wellness reminder sent:`, response);
        return response;
    }
    catch (error) {
        console.error("❌ Error sending wellness reminder:", error);
        throw error;
    }
});
// Manual wellness reminder trigger (for testing and immediate sending)
exports.sendManualWellnessReminder = functions.https.onCall(async (data, context) => {
    try {
        const { timeCategory } = data;
        if (!["morning", "afternoon", "evening"].includes(timeCategory)) {
            throw new functions.https.HttpsError("invalid-argument", "Invalid time category");
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
                priority: "normal",
                notification: {
                    channelId: "wellness_reminders",
                    priority: "default",
                    defaultSound: true,
                    tag: `manual_wellness_${timeCategory}_${Date.now()}`,
                },
            },
            topic: "wellness_reminders",
        };
        const response = await admin.messaging().send(fcmMessage);
        console.log("✅ Manual wellness reminder sent:", response);
        return { success: true, messageId: response, message: message };
    }
    catch (error) {
        console.error("❌ Error sending manual wellness reminder:", error);
        throw new functions.https.HttpsError("internal", "Failed to send wellness reminder");
    }
});
// Daily breathing exercise reminder - runs once daily at 2 PM
exports.sendDailyBreathingReminder = functions.pubsub
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
        const message = breathingMessages[Math.floor(Math.random() * breathingMessages.length)];
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
                priority: "normal",
                notification: {
                    channelId: "wellness_reminders",
                    priority: "default",
                    defaultSound: true,
                    tag: `breathing_daily_${Date.now()}`,
                },
            },
            topic: "wellness_reminders",
        };
        const response = await admin.messaging().send(fcmMessage);
        console.log("✅ Daily breathing reminder sent:", response);
        return response;
    }
    catch (error) {
        console.error("❌ Error sending daily breathing reminder:", error);
        throw error;
    }
});
// Helper function to get random wellness message without repetition
function getRandomWellnessMessage(timeCategory) {
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
    const randomIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)];
    const selectedMessage = messages[randomIndex];
    // Mark this message as sent
    sentWellnessMessages[timeCategory].push(randomIndex);
    return selectedMessage;
}
// ========================
// BATTERY MONITORING FUNCTIONS
// ========================
// Cloud Function to monitor device battery levels and send FCM notifications
exports.monitorDeviceBattery = functions.database
    .ref("/devices/{deviceId}/current/battPerc")
    .onUpdate(async (change, context) => {
    try {
        const deviceId = context.params.deviceId;
        const beforeBattery = change.before.val();
        const afterBattery = change.after.val();
        console.log(`🔋 Battery changed for device ${deviceId}: ${beforeBattery}% → ${afterBattery}%`);
        // Only trigger notifications on battery decrease (not increase/charging)
        if (afterBattery >= beforeBattery) {
            console.log("✅ Battery increased or stayed same, no notification needed");
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
            assignedUserId = assignmentData === null || assignmentData === void 0 ? void 0 : assignmentData.assignedUser;
        }
        // Get user FCM token for this device (with user validation)
        const fcmToken = await getDeviceFCMToken(deviceId, assignedUserId);
        if (!fcmToken) {
            console.log(`❌ No FCM token found for device ${deviceId}${assignedUserId ? ` (assigned to user: ${assignedUserId})` : ""}`);
            return null;
        }
        // Check if we need to send notifications
        const shouldSendLowBattery = afterBattery <= 10 && beforeBattery > 10;
        const shouldSendCriticalBattery = afterBattery <= 5 && beforeBattery > 5;
        const shouldSendDeviceOffline = afterBattery === 0 && beforeBattery > 0;
        if (shouldSendDeviceOffline) {
            await sendBatteryNotification(fcmToken, "device_offline", afterBattery, deviceId);
        }
        else if (shouldSendCriticalBattery) {
            await sendBatteryNotification(fcmToken, "critical_battery", afterBattery, deviceId);
        }
        else if (shouldSendLowBattery) {
            await sendBatteryNotification(fcmToken, "low_battery", afterBattery, deviceId);
        }
        return null;
    }
    catch (error) {
        console.error("❌ Error in battery monitoring:", error);
        return null;
    }
});
// Helper function to get FCM token for a device with user validation
async function getDeviceFCMToken(deviceId, userId) {
    const db = admin.database();
    try {
        // Try to get FCM token from device assignment with validation
        const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
        const assignmentSnapshot = await assignmentRef.once("value");
        if (assignmentSnapshot.exists()) {
            const assignmentData = assignmentSnapshot.val();
            const fcmToken = assignmentData === null || assignmentData === void 0 ? void 0 : assignmentData.fcmToken;
            const assignedUser = assignmentData === null || assignmentData === void 0 ? void 0 : assignmentData.assignedUser;
            if (fcmToken) {
                // If userId is provided, validate that the token belongs to that user
                if (userId && assignedUser && assignedUser !== userId) {
                    console.log(`⚠️ Assignment FCM token for device ${deviceId} belongs to user ${assignedUser}, not requesting user ${userId}`);
                    return null;
                }
                console.log(`✅ Found FCM token via assignment for device ${deviceId}${userId ? ` (user: ${userId})` : ""}`);
                return fcmToken;
            }
        }
        // Fallback: try to get from device level (legacy location)
        const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
        const deviceSnapshot = await deviceTokenRef.once("value");
        if (deviceSnapshot.exists()) {
            console.log(`✅ Found FCM token at legacy device level for device ${deviceId}`);
            return deviceSnapshot.val();
        }
        console.log(`❌ No FCM token found for device ${deviceId}`);
        return null;
    }
    catch (error) {
        console.error(`❌ Error getting FCM token for device ${deviceId}:`, error);
        return null;
    }
}
// Helper function to send battery notifications
async function sendBatteryNotification(fcmToken, type, batteryLevel, deviceId) {
    try {
        const { title, body, icon } = getBatteryNotificationContent(type, batteryLevel);
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
                priority: "high",
                notification: {
                    icon: "ic_notification",
                    color: type === "critical_battery" || type === "device_offline"
                        ? "#FF0000"
                        : "#FF6B00",
                    priority: "high",
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
        console.log(`✅ Battery notification sent successfully: ${type} for device ${deviceId}`, response);
    }
    catch (error) {
        console.error(`❌ Error sending battery notification: ${type} for device ${deviceId}:`, error);
    }
}
// Helper function to get battery notification content
function getBatteryNotificationContent(type, batteryLevel) {
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
exports.sendWellnessReminder = functions.https.onCall(async (data, context) => {
    try {
        const { title, body, type = "wellness_reminder" } = data;
        if (!title || !body) {
            throw new functions.https.HttpsError("invalid-argument", "Title and body are required");
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
            const sendPromise = sendWellnessReminderToUser(userId, title, body, type);
            sendPromises.push(sendPromise);
        }
        // Wait for all notifications to be sent
        const results = await Promise.allSettled(sendPromises);
        results.forEach((result, index) => {
            if (result.status === "fulfilled" && result.value) {
                sentCount++;
            }
            else {
                console.log(`⚠️ Failed to send wellness reminder to user ${userIds[index]}`);
            }
        });
        console.log(`✅ Wellness reminder sent to ${sentCount}/${userIds.length} users`);
        return {
            success: true,
            message: `Wellness reminder sent successfully`,
            sentCount,
            totalUsers: userIds.length,
        };
    }
    catch (error) {
        console.error("❌ Error sending wellness reminder:", error);
        throw new functions.https.HttpsError("internal", "Failed to send wellness reminder");
    }
});
/**
 * Helper function to send wellness reminder to a specific user
 */
async function sendWellnessReminderToUser(userId, title, body, type) {
    try {
        // Import the getUserFCMToken function from the anxiety detection module
        const { getUserFCMToken } = await Promise.resolve().then(() => require("./realTimeSustainedAnxietyDetection"));
        // Get user-level FCM token for wellness notifications
        const fcmToken = await getUserFCMToken(userId, undefined, "wellness_reminder");
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
                priority: "normal",
                notification: {
                    icon: "ic_notification",
                    color: "#2D9254",
                    channelId: "wellness_reminders",
                    priority: "default",
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
    }
    catch (error) {
        console.error(`❌ Error sending wellness reminder to user ${userId}:`, error);
        return false;
    }
}
//# sourceMappingURL=index.js.map