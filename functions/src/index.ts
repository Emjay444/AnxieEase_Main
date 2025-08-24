import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Interface for anxiety data structure
interface AnxietyData {
  severity: string;
  timestamp: number;
  confidence?: number;
}

interface MetricsData {
  heartRate: number;
  anxietyDetected: AnxietyData;
  timestamp: number;
}

// Cloud Function to send FCM notifications when anxiety severity changes
export const onAnxietySeverityChangeV2 = functions.database
  .ref("/devices/AnxieEase001/Metrics")
  .onWrite(async (change, context) => {
    try {
      const beforeData = change.before.val() as MetricsData | null;
      const afterData = change.after.val() as MetricsData | null;

      // Skip if no new data or data was deleted
      if (!afterData || !afterData.anxietyDetected) {
        console.log("No anxiety data found, skipping notification");
        return null;
      }

      const newSeverity = afterData.anxietyDetected.severity?.toLowerCase();
      const heartRate = afterData.heartRate;

      // Skip if severity is unchanged
      const oldSeverity = beforeData?.anxietyDetected?.severity?.toLowerCase();
      if (newSeverity === oldSeverity) {
        console.log(
          `Severity unchanged (${newSeverity}), skipping notification`
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

      // Get notification content based on severity
      const notificationData = getNotificationContent(newSeverity, heartRate);

      // Send FCM notification to all app instances
      const message = {
        data: {
          type: "anxiety_alert",
          severity: newSeverity,
          heartRate: heartRate?.toString() || "N/A",
          timestamp: Date.now().toString(),
        },
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        android: {
          priority: newSeverity === "severe" ? "high" : ("normal" as any),
          notification: {
            channelId: "anxiety_alerts",
            priority: newSeverity === "severe" ? "max" : ("default" as any),
            defaultSound: true,
            defaultVibrateTimings: true,
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

// Helper function to get notification content based on severity
function getNotificationContent(severity: string, heartRate?: number) {
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
          priority: "high" as any,
          notification: {
            channelId: "anxiety_alerts",
            priority: "max" as any,
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
