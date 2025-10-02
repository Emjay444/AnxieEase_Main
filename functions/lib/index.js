"use strict";
var _a, _b;
Object.defineProperty(exports, "__esModule", { value: true });
exports.monitorDeviceBattery = exports.detectAnxietyMultiParameter = exports.sendDailyBreathingReminder = exports.sendManualWellnessReminder = exports.sendWellnessReminders = exports.testNotificationHTTP = exports.sendTestNotificationV2 = exports.subscribeToAnxietyAlertsV2 = exports.onNativeAlertCreate = exports.onAnxietySeverityChangeV2 = exports.testDeviceSync = exports.periodicDeviceSync = exports.syncDeviceAssignment = exports.getCleanupStats = exports.manualCleanup = exports.autoCleanup = exports.clearAnxietyRateLimits = exports.realTimeSustainedAnxietyDetection = exports.autoCreateDeviceHistory = exports.getRateLimitStatus = exports.handleUserConfirmationResponse = exports.cleanupOldSessions = exports.getDeviceAssignment = exports.assignDeviceToUser = exports.copyDeviceCurrentToUserSession = exports.copyDeviceDataToUserSession = exports.monitorFirebaseUsage = exports.aggregateHealthDataHourly = exports.cleanupHealthData = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
// Initialize Firebase Admin SDK
admin.initializeApp();
// Optional: Supabase server-side persistence for test notifications
// Configure via environment variables (Firebase Functions config or runtime env)
const SUPABASE_URL = process.env.SUPABASE_URL || ((_a = functions.config().supabase) === null || _a === void 0 ? void 0 : _a.url);
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ||
    ((_b = functions.config().supabase) === null || _b === void 0 ? void 0 : _b.service_role_key);
// Lazy import to avoid hard dependency when not configured
let fetchImpl = null;
try {
    // Node 18+ has global fetch; fallback not needed normally
    fetchImpl = global.fetch || require("node-fetch");
}
catch (_c) { }
// Import and export data cleanup functions
var dataCleanup_1 = require("./dataCleanup");
Object.defineProperty(exports, "cleanupHealthData", { enumerable: true, get: function () { return dataCleanup_1.cleanupHealthData; } });
Object.defineProperty(exports, "aggregateHealthDataHourly", { enumerable: true, get: function () { return dataCleanup_1.aggregateHealthDataHourly; } });
Object.defineProperty(exports, "monitorFirebaseUsage", { enumerable: true, get: function () { return dataCleanup_1.monitorFirebaseUsage; } });
// Import and export device data copy functions for multi-user support
var deviceDataCopyService_1 = require("./deviceDataCopyService");
Object.defineProperty(exports, "copyDeviceDataToUserSession", { enumerable: true, get: function () { return deviceDataCopyService_1.copyDeviceDataToUserSession; } });
Object.defineProperty(exports, "copyDeviceCurrentToUserSession", { enumerable: true, get: function () { return deviceDataCopyService_1.copyDeviceCurrentToUserSession; } });
Object.defineProperty(exports, "assignDeviceToUser", { enumerable: true, get: function () { return deviceDataCopyService_1.assignDeviceToUser; } });
Object.defineProperty(exports, "getDeviceAssignment", { enumerable: true, get: function () { return deviceDataCopyService_1.getDeviceAssignment; } });
Object.defineProperty(exports, "cleanupOldSessions", { enumerable: true, get: function () { return deviceDataCopyService_1.cleanupOldSessions; } });
// Import and export enhanced rate limiting functions
var enhancedRateLimiting_1 = require("./enhancedRateLimiting");
Object.defineProperty(exports, "handleUserConfirmationResponse", { enumerable: true, get: function () { return enhancedRateLimiting_1.handleUserConfirmationResponse; } });
Object.defineProperty(exports, "getRateLimitStatus", { enumerable: true, get: function () { return enhancedRateLimiting_1.getRateLimitStatus; } });
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
Object.defineProperty(exports, "manualCleanup", { enumerable: true, get: function () { return autoCleanup_1.manualCleanup; } });
Object.defineProperty(exports, "getCleanupStats", { enumerable: true, get: function () { return autoCleanup_1.getCleanupStats; } });
// Import device assignment sync functions
var deviceAssignmentSync_1 = require("./deviceAssignmentSync");
Object.defineProperty(exports, "syncDeviceAssignment", { enumerable: true, get: function () { return deviceAssignmentSync_1.syncDeviceAssignment; } });
Object.defineProperty(exports, "periodicDeviceSync", { enumerable: true, get: function () { return deviceAssignmentSync_1.periodicDeviceSync; } });
Object.defineProperty(exports, "testDeviceSync", { enumerable: true, get: function () { return deviceAssignmentSync_1.testDeviceSync; } });
// Cloud Function to send FCM notifications when anxiety severity changes
exports.onAnxietySeverityChangeV2 = functions.database
    .ref("/devices/AnxieEase001/current")
    .onWrite(async (change, context) => {
    try {
        // Legacy function disabled - anxiety detection now requires personalized baseline
        // Use personalizedAnxietyDetection function instead
        console.log("Legacy threshold-based detection disabled - requires baseline from personalizedAnxietyDetection function");
        return null;
    }
    catch (error) {
        console.error("❌ Error in onAnxietySeverityChangeV2:", error);
        throw error;
    }
});
// NEW: Send FCM when a native alert is created under devices/<deviceId>/alerts
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
                heartRate: (heartRate === null || heartRate === void 0 ? void 0 : heartRate.toString()) || "N/A",
                timestamp: ts.toString(),
                notificationId: `${severity}_${ts}`,
                title,
                message: body,
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
        console.log("✅ Test FCM notification sent successfully:", response);
        return { success: true, messageId: response };
    }
    catch (error) {
        console.error("❌ Error sending test notification:", error);
        throw new functions.https.HttpsError("internal", "Failed to send test notification");
    }
});
// HTTP-based test notification function for easy testing
exports.testNotificationHTTP = functions.https.onRequest(async (req, res) => {
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
        const { severity = "mild", heartRate = 75 } = req.method === "POST" ? req.body : req.query;
        console.log(`📧 Testing notification: ${severity} alert with HR: ${heartRate}`);
        const notificationData = getNotificationContent(severity, heartRate);
        // DATA-ONLY HTTP test message
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
        console.log("✅ Test FCM notification sent successfully:", response);
        // Additionally, persist test alert to Supabase if configured
        try {
            if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && fetchImpl) {
                await persistTestAlertToSupabase(severity, heartRate, notificationData);
                console.log("✅ Test alert also saved to Supabase");
            }
            else {
                console.log("ℹ️ Supabase env not configured; skipping test alert storage");
            }
        }
        catch (e) {
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
    }
    catch (error) {
        console.error("❌ Error sending test notification:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error",
            message: "Failed to send test notification",
        });
    }
});
/**
 * Persist test alert to Supabase (similar to realTimeSustainedAnxietyDetection)
 */
async function persistTestAlertToSupabase(severity, heartRate, notificationContent) {
    const url = `${SUPABASE_URL}/rest/v1/notifications`;
    const payload = {
        // Keep payload aligned with app-side SupabaseService.createNotification schema
        user_id: "5afad7d4-3dcd-4353-badb-4f155303419a",
        title: `[TEST] ${notificationContent.title}`,
        message: notificationContent.body,
        type: "alert",
        related_screen: "notifications",
        created_at: new Date().toISOString(),
    };
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
// Multi-parameter anxiety detection Cloud Function
exports.detectAnxietyMultiParameter = functions.database
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
        }
        else if (currentHR > hrThreshold) {
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
        }
        else if (currentSpO2 < 94) {
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
        }
        else if (abnormalCount >= 2) {
            // Multiple abnormal metrics - auto-trigger
            triggered = true;
            requiresUserConfirmation = false;
            overallConfidence = 0.85;
            reason = "multipleAbnormal";
        }
        else if (abnormalCount === 1) {
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
            console.log(`Anxiety detected: ${reason} (confidence: ${overallConfidence})`);
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
    }
    catch (error) {
        console.error("Error in anxiety detection:", error);
        return null;
    }
});
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
        // Get user FCM token for this device
        const fcmToken = await getDeviceFCMToken(deviceId);
        if (!fcmToken) {
            console.log(`❌ No FCM token found for device ${deviceId}`);
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
// Helper function to get FCM token for a device
async function getDeviceFCMToken(deviceId) {
    const db = admin.database();
    try {
        // Try to get FCM token from device assignment
        const assignmentTokenRef = db.ref(`/devices/${deviceId}/assignment/fcmToken`);
        const assignmentSnapshot = await assignmentTokenRef.once("value");
        if (assignmentSnapshot.exists()) {
            console.log(`✅ Found FCM token via assignment for device ${deviceId}`);
            return assignmentSnapshot.val();
        }
        // Fallback: try to get from device level
        const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
        const deviceSnapshot = await deviceTokenRef.once("value");
        if (deviceSnapshot.exists()) {
            console.log(`✅ Found FCM token at device level for device ${deviceId}`);
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
//# sourceMappingURL=index.js.map