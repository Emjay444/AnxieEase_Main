"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTestNotificationV2 = exports.subscribeToAnxietyAlertsV2 = exports.onAnxietySeverityChangeV2 = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin SDK
admin.initializeApp();
// Cloud Function to send FCM notifications when anxiety severity changes
exports.onAnxietySeverityChangeV2 = functions.database
    .ref("/devices/AnxieEase001/Metrics")
    .onWrite(async (change, context) => {
    var _a, _b, _c;
    try {
        const beforeData = change.before.val();
        const afterData = change.after.val();
        // Skip if no new data or data was deleted
        if (!afterData || !afterData.anxietyDetected) {
            console.log("No anxiety data found, skipping notification");
            return null;
        }
        const newSeverity = (_a = afterData.anxietyDetected.severity) === null || _a === void 0 ? void 0 : _a.toLowerCase();
        const heartRate = afterData.heartRate;
        // Skip if severity is unchanged
        const oldSeverity = (_c = (_b = beforeData === null || beforeData === void 0 ? void 0 : beforeData.anxietyDetected) === null || _b === void 0 ? void 0 : _b.severity) === null || _c === void 0 ? void 0 : _c.toLowerCase();
        if (newSeverity === oldSeverity) {
            console.log(`Severity unchanged (${newSeverity}), skipping notification`);
            return null;
        }
        // Skip if severity is not one of the expected values
        if (!["mild", "moderate", "severe"].includes(newSeverity)) {
            console.log(`Invalid severity value: ${newSeverity}, skipping notification`);
            return null;
        }
        console.log(`Anxiety severity changed from ${oldSeverity} to ${newSeverity}, HR: ${heartRate}`);
        // Get notification content based on severity
        const notificationData = getNotificationContent(newSeverity, heartRate);
        // Send FCM notification to all app instances
        const message = {
            data: {
                type: "anxiety_alert",
                severity: newSeverity,
                heartRate: (heartRate === null || heartRate === void 0 ? void 0 : heartRate.toString()) || "N/A",
                timestamp: Date.now().toString(),
            },
            notification: {
                title: notificationData.title,
                body: notificationData.body,
            },
            android: {
                // Use high priority to wake the device and deliver while app is background/terminated
                priority: "high",
                notification: {
                    // Avoid strict channel requirement; let Android use default channel if custom not present
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
    }
    catch (error) {
        console.error("❌ Error sending FCM notification:", error);
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
// Cloud Function to test FCM notifications (for debugging)
exports.sendTestNotificationV2 = functions.https.onCall(async (data, context) => {
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
    }
    catch (error) {
        console.error("❌ Error sending test notification:", error);
        throw new functions.https.HttpsError("internal", "Failed to send test notification");
    }
});
//# sourceMappingURL=index.js.map