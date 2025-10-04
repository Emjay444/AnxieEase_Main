"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testCriticalNotification = exports.testSevereNotification = exports.testModerateNotification = exports.testMildNotification = exports.sendDailyBreathingReminder = exports.sendWellnessReminders = exports.subscribeToAnxietyAlertsV2 = exports.onNativeAlertCreate = exports.realTimeSustainedAnxietyDetection = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin SDK
admin.initializeApp();
// Core anxiety detection and notification functions only
// 1. CORE ANXIETY DETECTION - Real-time sustained anxiety detection
var realTimeSustainedAnxietyDetection_1 = require("./realTimeSustainedAnxietyDetection");
Object.defineProperty(exports, "realTimeSustainedAnxietyDetection", { enumerable: true, get: function () { return realTimeSustainedAnxietyDetection_1.realTimeSustainedAnxietyDetection; } });
// 2. NOTIFICATION FUNCTIONS - Essential notification system
exports.onNativeAlertCreate = functions.database
    .ref("/devices/{deviceId}/alerts/{alertId}")
    .onCreate(async (snapshot, context) => {
    try {
        const alert = snapshot.val();
        if (!alert)
            return null;
        const severity = (alert.severity || "").toLowerCase();
        const heartRate = alert.heartRate;
        const ts = alert.timestamp || Date.now();
        if (!["mild", "moderate", "severe", "critical"].includes(severity)) {
            console.log(`Skipping alert with invalid severity: ${severity}`);
            return null;
        }
        const { title, body } = getNotificationContent(severity, heartRate);
        // DATA-ONLY: Include title/body in data with proper channel and sound
        const message = {
            data: {
                type: "anxiety_alert",
                severity,
                heartRate: (heartRate === null || heartRate === void 0 ? void 0 : heartRate.toString()) || "N/A",
                timestamp: ts.toString(),
                notificationId: `${severity}_${ts}`,
                title,
                message: body,
                // Add proper channel and sound for custom notification handling
                channelId: getChannelIdForSeverity(severity),
                sound: getSoundForSeverity(severity),
                color: getSeverityColor(severity),
                requiresConfirmation: "false",
                alertType: "direct",
            },
            android: {
                priority: "high",
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
        };
        const response = await admin.messaging().send(message);
        console.log("✅ FCM sent from onNativeAlertCreate:", response);
        return response;
    }
    catch (error) {
        console.error("❌ Error in onNativeAlertCreate:", error);
        throw error;
    }
});
// 3. USER SUBSCRIPTION - Allow users to subscribe to anxiety alerts
exports.subscribeToAnxietyAlertsV2 = functions.https.onCall(async (data, context) => {
    try {
        const { fcmToken } = data;
        if (!fcmToken) {
            throw new functions.https.HttpsError("invalid-argument", "FCM token is required");
        }
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
// 4. SCHEDULED WELLNESS NOTIFICATIONS
exports.sendWellnessReminders = functions.pubsub
    .schedule("0 8,12,16,20,22 * * *") // 5 times daily
    .timeZone("Asia/Manila")
    .onRun(async (context) => {
    try {
        const philippineTime = new Date().toLocaleString("en-US", {
            timeZone: "Asia/Manila",
            hour12: false,
        });
        const currentHour = parseInt(philippineTime.split(", ")[1].split(":")[0]);
        let timeCategory;
        if (currentHour >= 6 && currentHour < 11) {
            timeCategory = "morning";
        }
        else if (currentHour >= 11 && currentHour < 17) {
            timeCategory = "afternoon";
        }
        else {
            timeCategory = "evening";
        }
        const message = getRandomWellnessMessage(timeCategory);
        if (!message) {
            console.log("No new messages available for", timeCategory);
            return null;
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
// 5. SCHEDULED BREATHING REMINDERS
exports.sendDailyBreathingReminder = functions.pubsub
    .schedule("0 14 * * *") // 2 PM daily
    .timeZone("Asia/Manila")
    .onRun(async (context) => {
    try {
        const breathingMessages = [
            {
                title: "🫁 Daily Breathing Exercise",
                body: "Take 5 minutes for deep breathing. Your mind will thank you.",
            },
            {
                title: "🌬️ Breathe & Reset",
                body: "Try the 4-7-8 technique: Inhale for 4, hold for 7, exhale for 8.",
            },
            {
                title: "💨 Mindful Breathing",
                body: "Box breathing time: Inhale 4, hold 4, exhale 4, hold 4. Repeat 3 times.",
            },
        ];
        const message = breathingMessages[Math.floor(Math.random() * breathingMessages.length)];
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
// 6. INDIVIDUAL TEST ENDPOINTS - For testing each severity level
exports.testMildNotification = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS")
        return res.status(204).send("");
    try {
        const message = {
            data: {
                type: "anxiety_alert",
                severity: "mild",
                heartRate: "88",
                timestamp: Date.now().toString(),
                title: "🟢 Mild Alert - 60% Confidence",
                message: "Slight elevation in readings. HR: 88 bpm",
                channelId: "mild_anxiety_alerts_v4",
                sound: "mild_alert.mp3",
                color: "#4CAF50",
                requiresConfirmation: "false",
                alertType: "test",
            },
            android: { priority: "high" },
            apns: { headers: { "apns-priority": "10" } },
            topic: "anxiety_alerts",
        };
        const response = await admin.messaging().send(message);
        res.json({ success: true, severity: "mild", messageId: response });
    }
    catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
exports.testModerateNotification = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS")
        return res.status(204).send("");
    try {
        const message = {
            data: {
                type: "anxiety_alert",
                severity: "moderate",
                heartRate: "108",
                timestamp: Date.now().toString(),
                title: "🟠 Moderate Alert - 70% Confidence",
                message: "Noticeable symptoms detected. HR: 108 bpm",
                channelId: "moderate_anxiety_alerts_v2",
                sound: "moderate_alert.mp3",
                color: "#FF9800",
                requiresConfirmation: "false",
                alertType: "test",
            },
            android: { priority: "high" },
            apns: { headers: { "apns-priority": "10" } },
            topic: "anxiety_alerts",
        };
        const response = await admin.messaging().send(message);
        res.json({ success: true, severity: "moderate", messageId: response });
    }
    catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
exports.testSevereNotification = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS")
        return res.status(204).send("");
    try {
        const message = {
            data: {
                type: "anxiety_alert",
                severity: "severe",
                heartRate: "125",
                timestamp: Date.now().toString(),
                title: "🔴 Severe Alert - 85% Confidence",
                message: "URGENT: High risk detected! HR: 125 bpm",
                channelId: "severe_anxiety_alerts_v2",
                sound: "severe_alert.mp3",
                color: "#F44336",
                requiresConfirmation: "false",
                alertType: "test",
            },
            android: { priority: "high" },
            apns: { headers: { "apns-priority": "10" } },
            topic: "anxiety_alerts",
        };
        const response = await admin.messaging().send(message);
        res.json({ success: true, severity: "severe", messageId: response });
    }
    catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
exports.testCriticalNotification = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS")
        return res.status(204).send("");
    try {
        const message = {
            data: {
                type: "anxiety_alert",
                severity: "critical",
                heartRate: "145",
                timestamp: Date.now().toString(),
                title: "🚨 CRITICAL Alert - 95% Confidence",
                message: "EMERGENCY: Critical anxiety detected! HR: 145 bpm",
                channelId: "critical_anxiety_alerts_v2",
                sound: "critical_alert.mp3",
                color: "#8B0000",
                requiresConfirmation: "false",
                alertType: "test",
            },
            android: { priority: "high" },
            apns: { headers: { "apns-priority": "10" } },
            topic: "anxiety_alerts",
        };
        const response = await admin.messaging().send(message);
        res.json({ success: true, severity: "critical", messageId: response });
    }
    catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
// HELPER FUNCTIONS
function getNotificationContent(severity, heartRate) {
    const hrText = heartRate ? ` HR: ${heartRate} bpm` : "";
    switch (severity) {
        case "mild": return { title: "🟢 Mild Alert - 60% Confidence", body: `Slight elevation in readings.${hrText}` };
        case "moderate": return { title: "🟠 Moderate Alert - 70% Confidence", body: `Noticeable symptoms detected.${hrText}` };
        case "severe": return { title: "🔴 Severe Alert - 85% Confidence", body: `URGENT: High risk detected!${hrText}` };
        case "critical": return { title: "🚨 CRITICAL Alert - 95% Confidence", body: `EMERGENCY: Critical anxiety detected!${hrText}` };
        default: return { title: "📱 AnxieEase Alert", body: `Anxiety level detected.${hrText}` };
    }
}
function getChannelIdForSeverity(severity) {
    switch (severity.toLowerCase()) {
        case "mild": return "mild_anxiety_alerts_v4";
        case "moderate": return "moderate_anxiety_alerts_v2";
        case "severe": return "severe_anxiety_alerts_v2";
        case "critical": return "critical_anxiety_alerts_v2";
        default: return "anxiease_channel";
    }
}
function getSoundForSeverity(severity) {
    switch (severity.toLowerCase()) {
        case "mild": return "mild_alert.mp3";
        case "moderate": return "moderate_alert.mp3";
        case "severe": return "severe_alert.mp3";
        case "critical": return "critical_alert.mp3";
        default: return "default";
    }
}
function getSeverityColor(severity) {
    switch (severity.toLowerCase()) {
        case "mild": return "#4CAF50";
        case "moderate": return "#FF9800";
        case "severe": return "#F44336";
        case "critical": return "#8B0000";
        default: return "#2196F3";
    }
}
// Wellness message system
const WELLNESS_MESSAGES = {
    morning: [
        { title: "🌅 Good Morning!", body: "Start your day with 3 deep breaths.", type: "breathing" },
        { title: "☀️ Morning Motivation", body: "You have the strength to handle whatever today brings.", type: "wellness" },
    ],
    afternoon: [
        { title: "🌤️ Afternoon Check-in", body: "Take a moment to breathe and reset.", type: "breathing" },
        { title: "🌿 Midday Mindfulness", body: "You're doing great. One step at a time.", type: "wellness" },
    ],
    evening: [
        { title: "🌙 Evening Relaxation", body: "Wind down with gentle breathing exercises.", type: "breathing" },
        { title: "⭐ Evening Reflection", body: "Be proud of what you accomplished today.", type: "wellness" },
    ],
};
let sentWellnessMessages = { morning: [], afternoon: [], evening: [] };
function getRandomWellnessMessage(timeCategory) {
    const messages = WELLNESS_MESSAGES[timeCategory];
    const sentIndices = sentWellnessMessages[timeCategory];
    if (sentIndices.length >= messages.length) {
        sentWellnessMessages[timeCategory] = [];
    }
    const availableIndices = messages
        .map((_, index) => index)
        .filter((index) => !sentIndices.includes(index));
    if (availableIndices.length === 0)
        return null;
    const randomIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)];
    sentWellnessMessages[timeCategory].push(randomIndex);
    return messages[randomIndex];
}
//# sourceMappingURL=index_streamlined.js.map