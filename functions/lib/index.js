"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendManualWellnessReminder =
  exports.sendWellnessReminders =
  exports.sendTestNotificationV2 =
  exports.subscribeToAnxietyAlertsV2 =
  exports.onNativeAlertCreate =
  exports.onAnxietySeverityChangeV2 =
    void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin SDK
admin.initializeApp();
// Global variable to track last notification to prevent duplicates
let lastNotification = { severity: "", timestamp: 0, heartRate: 0 };
// Cloud Function to send FCM notifications when anxiety severity changes
exports.onAnxietySeverityChangeV2 = functions.database
  .ref("/devices/AnxieEase001/current")
  .onWrite(async (change, context) => {
    try {
      const beforeData = change.before.val();
      const afterData = change.after.val();
      // Skip if no new data or data was deleted
      if (!afterData || !afterData.heartRate) {
        console.log("No heart rate data found, skipping notification");
        return null;
      }
      const heartRate = afterData.heartRate;
      const currentTime = Date.now();
      // Compute severity from heart rate (same logic as native service)
      let newSeverity;
      if (heartRate >= 120) {
        newSeverity = "severe";
      } else if (heartRate >= 100) {
        newSeverity = "moderate";
      } else if (heartRate >= 85) {
        newSeverity = "mild";
      } else {
        newSeverity = "normal";
      }
      // Skip if severity is normal
      if (newSeverity === "normal") {
        console.log("Heart rate normal, skipping notification");
        return null;
      }
      // Compute old severity for comparison
      const oldHeartRate =
        (beforeData === null || beforeData === void 0
          ? void 0
          : beforeData.heartRate) || 0;
      let oldSeverity = "normal";
      if (oldHeartRate >= 120) {
        oldSeverity = "severe";
      } else if (oldHeartRate >= 100) {
        oldSeverity = "moderate";
      } else if (oldHeartRate >= 85) {
        oldSeverity = "mild";
      }
      // ENHANCED DEDUPLICATION - Multiple checks to prevent flooding:
      // 1. Skip if severity is unchanged
      if (newSeverity === oldSeverity) {
        console.log(
          `Severity unchanged (${newSeverity}), skipping notification`
        );
        return null;
      }
      // 2. Skip if same severity notification was sent within last 2 MINUTES (was 5 minutes)
      if (
        lastNotification.severity === newSeverity &&
        currentTime - lastNotification.timestamp < 120000 // 2 minutes
      ) {
        console.log(
          `Duplicate ${newSeverity} notification within 2 minutes, skipping`
        );
        return null;
      }
      // 3. Skip if heart rate change is too small (< 5 bpm difference, was 10)
      // This prevents notifications from minor fluctuations like 89→91→88
      if (
        Math.abs(heartRate - lastNotification.heartRate) < 5 &&
        newSeverity === lastNotification.severity
      ) {
        console.log(
          `Heart rate fluctuation too small (${lastNotification.heartRate}→${heartRate}), skipping`
        );
        return null;
      }
      // 4. Rate limiting: Maximum 1 notification per 1 minute regardless of severity (was 2 minutes)
      if (currentTime - lastNotification.timestamp < 60000) {
        // 1 minute
        console.log(
          `Rate limit: Last notification was ${
            (currentTime - lastNotification.timestamp) / 1000
          }s ago, skipping`
        );
        return null;
      }
      // DEDUPLICATION: Skip if same severity notification was sent within last 30 seconds
      if (
        lastNotification.severity === newSeverity &&
        currentTime - lastNotification.timestamp < 30000
      ) {
        console.log(
          `Duplicate ${newSeverity} notification within 30 seconds, skipping`
        );
        return null;
      }
      // Skip if severity is not one of the expected values
      if (!["mild", "moderate", "severe"].includes(newSeverity)) {
        console.log(
          `Invalid severity value: ${newSeverity}, skipping notification`
        );
        return null;
      }
      console.log(
        `Anxiety severity changed from ${oldSeverity} to ${newSeverity}, HR: ${heartRate}`
      );
      // Update last notification tracker
      lastNotification = {
        severity: newSeverity,
        timestamp: currentTime,
        heartRate: heartRate,
      };
      // Get notification content based on severity
      const notificationData = getNotificationContent(newSeverity, heartRate);
      // Send FCM notification to all app instances
      const message = {
        data: {
          type: "anxiety_alert",
          severity: newSeverity,
          heartRate:
            (heartRate === null || heartRate === void 0
              ? void 0
              : heartRate.toString()) || "N/A",
          timestamp: currentTime.toString(),
          notificationId: `${newSeverity}_${currentTime}`, // Unique ID
        },
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        android: {
          priority: newSeverity === "severe" ? "high" : "normal",
          notification: {
            channelId: "anxiety_alerts",
            priority: newSeverity === "severe" ? "max" : "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            tag: `anxiety_${newSeverity}_${currentTime}`, // Unique tag to prevent grouping
          },
        },
        // Send to topic so all app instances receive the notification
        topic: "anxiety_alerts",
      };
      const response = await admin.messaging().send(message);
      console.log("✅ FCM notification sent successfully:", response);
      return response;
    } catch (error) {
      console.error("❌ Error sending FCM notification:", error);
      throw error;
    }
  });
// NEW: Send FCM when a native alert is created under devices/<deviceId>/alerts
exports.onNativeAlertCreate = functions.database
  .ref("/devices/{deviceId}/alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    try {
      const alert = snapshot.val();
      if (!alert) return null;
      const severity = (alert.severity || "").toLowerCase();
      const heartRate = alert.heartRate;
      const ts = alert.timestamp || Date.now();
      if (!["mild", "moderate", "severe"].includes(severity)) {
        console.log(`Skipping alert with invalid severity: ${severity}`);
        return null;
      }
      const { title, body } = getNotificationContent(severity, heartRate);
      const message = {
        data: {
          type: "anxiety_alert",
          severity,
          heartRate:
            (heartRate === null || heartRate === void 0
              ? void 0
              : heartRate.toString()) || "N/A",
          timestamp: ts.toString(),
          notificationId: `${severity}_${ts}`,
        },
        notification: {
          title,
          body,
        },
        android: {
          priority: severity === "severe" ? "high" : "normal",
          notification: {
            channelId: "anxiety_alerts",
            priority: severity === "severe" ? "max" : "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            tag: `anxiety_${severity}_${ts}`,
          },
        },
        topic: "anxiety_alerts",
      };
      const response = await admin.messaging().send(message);
      console.log("✅ FCM sent from onNativeAlertCreate:", response);
      return response;
    } catch (error) {
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
        title: "🟢 Mild Alert",
        body: `Slight elevation in readings.${hrText}`,
      };
    case "moderate":
      return {
        title: "🟠 Moderate Alert",
        body: `Noticeable symptoms detected.${hrText}`,
      };
    case "severe":
      return {
        title: "🔴 Severe Alert",
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
exports.subscribeToAnxietyAlertsV2 = functions.https.onCall(
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
exports.sendTestNotificationV2 = functions.https.onCall(
  async (data, context) => {
    try {
      const { severity = "mild", heartRate = 75 } = data;
      const notificationData = getNotificationContent(severity, heartRate);
      const message = {
        data: {
          type: "test_alert",
          severity: severity,
          heartRate: heartRate.toString(),
          timestamp: Date.now().toString(),
        },
        notification: {
          title: `[TEST] ${notificationData.title}`,
          body: notificationData.body,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "anxiety_alerts",
            priority: "max",
            defaultSound: true,
          },
        },
        topic: "anxiety_alerts",
      };
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
let sentWellnessMessages = {
  morning: [],
  afternoon: [],
  evening: [],
};
// Scheduled wellness reminders - runs multiple times daily
exports.sendWellnessReminders = functions.pubsub
  .schedule("0 9,17,23 * * *") // 9 AM, 5 PM, 11 PM daily
  .timeZone("America/New_York") // Adjust timezone as needed
  .onRun(async (context) => {
    try {
      const currentHour = new Date().getHours();
      let timeCategory;
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
    } catch (error) {
      console.error("❌ Error sending wellness reminder:", error);
      throw error;
    }
  });
// Manual wellness reminder trigger (for testing and immediate sending)
exports.sendManualWellnessReminder = functions.https.onCall(
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
  const randomIndex =
    availableIndices[Math.floor(Math.random() * availableIndices.length)];
  const selectedMessage = messages[randomIndex];
  // Mark this message as sent
  sentWellnessMessages[timeCategory].push(randomIndex);
  return selectedMessage;
}
//# sourceMappingURL=index.js.map
