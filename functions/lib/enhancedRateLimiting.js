"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRateLimitStatus = exports.handleUserConfirmationResponse = exports.recordUserConfirmationResponse = exports.updateRateLimitTimestamp = exports.isRateLimitedWithConfirmation = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
const RATE_LIMIT_CONFIG = {
    mild: {
        baseCooldown: 5 * 60 * 1000,
        confirmedCooldown: 60 * 60 * 1000,
        dismissedCooldown: 15 * 60 * 1000,
        maxCooldown: 2 * 60 * 60 * 1000, // Max 2 hours
    },
    moderate: {
        baseCooldown: 3 * 60 * 1000,
        confirmedCooldown: 60 * 60 * 1000,
        dismissedCooldown: 15 * 60 * 1000,
        maxCooldown: 2 * 60 * 60 * 1000, // Max 2 hours
    },
    severe: {
        baseCooldown: 1 * 60 * 1000,
        confirmedCooldown: 30 * 60 * 1000,
        dismissedCooldown: 10 * 60 * 1000,
        maxCooldown: 60 * 60 * 1000, // Max 1 hour
    },
    critical: {
        baseCooldown: 30 * 1000,
        confirmedCooldown: 5 * 60 * 1000,
        dismissedCooldown: 2 * 60 * 1000,
        maxCooldown: 15 * 60 * 1000, // Max 15 minutes
    },
};
/**
 * Check if notifications are rate-limited considering user confirmations
 */
async function isRateLimitedWithConfirmation(userId, severity) {
    const now = Date.now();
    const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
    const snapshot = await rateLimitRef.once("value");
    const config = RATE_LIMIT_CONFIG[severity] || RATE_LIMIT_CONFIG.mild;
    if (!snapshot.exists()) {
        // No previous data, not rate limited
        return false;
    }
    const data = snapshot.val();
    // Calculate appropriate cooldown period based on user's last response
    let cooldownPeriod = config.baseCooldown;
    let cooldownType = "normal";
    if (data.lastUserResponse) {
        const timeSinceResponse = now - data.lastUserResponse.timestamp;
        // Only apply extended cooldowns if the response was recent enough
        if (timeSinceResponse < config.maxCooldown) {
            switch (data.lastUserResponse.response) {
                case "no":
                    cooldownPeriod = config.confirmedCooldown;
                    cooldownType = "extended (user said not anxious)";
                    break;
                case "not_now":
                    cooldownPeriod = config.dismissedCooldown;
                    cooldownType = "medium (user dismissed)";
                    break;
                case "yes":
                    cooldownPeriod = config.baseCooldown;
                    cooldownType = "normal (user confirmed anxious)";
                    break;
            }
            console.log(`📵 User ${userId} previously responded "${data.lastUserResponse.response}" for ${severity} - using ${cooldownType} cooldown: ${cooldownPeriod / 1000}s`);
        }
    }
    // Check if we're still in cooldown period
    const timeSinceLastNotification = now - data.lastNotification;
    const isRateLimited = timeSinceLastNotification < cooldownPeriod;
    if (isRateLimited) {
        const remainingSeconds = Math.ceil((cooldownPeriod - timeSinceLastNotification) / 1000);
        console.log(`🚫 Rate limited for user ${userId}, severity ${severity}. ${remainingSeconds}s remaining.`);
    }
    return isRateLimited;
}
exports.isRateLimitedWithConfirmation = isRateLimitedWithConfirmation;
/**
 * Update rate limit timestamp when sending notification
 */
async function updateRateLimitTimestamp(userId, severity) {
    const now = Date.now();
    const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
    const snapshot = await rateLimitRef.once("value");
    let existingData = { lastNotification: now };
    if (snapshot.exists()) {
        existingData = snapshot.val();
        existingData.lastNotification = now;
    }
    await rateLimitRef.set(existingData);
    console.log(`✅ Updated rate limit timestamp for user ${userId}, severity ${severity}`);
}
exports.updateRateLimitTimestamp = updateRateLimitTimestamp;
/**
 * Record user confirmation response to extend rate limiting
 */
async function recordUserConfirmationResponse(userId, severity, response, notificationId) {
    const now = Date.now();
    const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
    const snapshot = await rateLimitRef.once("value");
    let data = {
        lastNotification: now,
        lastUserResponse: {
            timestamp: now,
            response,
            severity,
        },
    };
    if (snapshot.exists()) {
        const existingData = snapshot.val();
        data.lastNotification = existingData.lastNotification || now;
        data.lastUserResponse = {
            timestamp: now,
            response,
            severity,
        };
    }
    await rateLimitRef.set(data);
    // Log the response for analytics
    await db.ref(`userResponses/${userId}`).push({
        timestamp: now,
        severity,
        response,
        notificationId,
        source: "anxiety_confirmation_dialog",
    });
    const config = RATE_LIMIT_CONFIG[severity] || RATE_LIMIT_CONFIG.mild;
    let nextCooldown;
    let responseText;
    switch (response) {
        case "yes":
            nextCooldown = config.baseCooldown;
            responseText = "confirmed anxiety";
            break;
        case "no":
            nextCooldown = config.confirmedCooldown;
            responseText = "denied anxiety";
            break;
        case "not_now":
            nextCooldown = config.dismissedCooldown;
            responseText = "dismissed notification";
            break;
        default:
            nextCooldown = config.baseCooldown;
            responseText = "unknown response";
    }
    console.log(`📝 User ${userId} ${responseText} for ${severity} alert. Next cooldown: ${nextCooldown / 1000}s`);
}
exports.recordUserConfirmationResponse = recordUserConfirmationResponse;
/**
 * Cloud Function to handle user confirmation responses from the app
 */
exports.handleUserConfirmationResponse = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const { severity, response, notificationId } = data;
    const userId = context.auth.uid;
    if (!severity ||
        !response ||
        !["yes", "no", "not_now"].includes(response)) {
        throw new functions.https.HttpsError("invalid-argument", "Missing required fields: severity, response (must be 'yes', 'no', or 'not_now')");
    }
    try {
        await recordUserConfirmationResponse(userId, severity, response, notificationId);
        const config = RATE_LIMIT_CONFIG[severity] || RATE_LIMIT_CONFIG.mild;
        let nextCooldown;
        let message;
        switch (response) {
            case "yes":
                nextCooldown = config.baseCooldown;
                message = "User confirmation recorded: anxious";
                break;
            case "no":
                nextCooldown = config.confirmedCooldown;
                message = "User confirmation recorded: not anxious";
                break;
            case "not_now":
                nextCooldown = config.dismissedCooldown;
                message = "User confirmation recorded: dismissed";
                break;
            default:
                nextCooldown = config.baseCooldown;
                message = "User confirmation recorded: unknown";
        }
        return {
            success: true,
            message,
            nextCooldown,
            response,
        };
    }
    catch (error) {
        console.error("Error recording user confirmation:", error);
        throw new functions.https.HttpsError("internal", "Failed to record user confirmation");
    }
});
/**
 * Get rate limit status for debugging
 */
exports.getRateLimitStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const userId = context.auth.uid;
    const now = Date.now();
    const statusPromises = Object.keys(RATE_LIMIT_CONFIG).map(async (severity) => {
        var _a;
        const rateLimitRef = db.ref(`rateLimits/${userId}/${severity}`);
        const snapshot = await rateLimitRef.once("value");
        if (!snapshot.exists()) {
            return {
                severity,
                rateLimited: false,
                remainingSeconds: 0,
            };
        }
        const data = snapshot.val();
        const config = RATE_LIMIT_CONFIG[severity];
        let cooldownPeriod = config.baseCooldown;
        if (data.lastUserResponse && data.lastUserResponse.response === "no") {
            const timeSinceResponse = now - data.lastUserResponse.timestamp;
            if (timeSinceResponse < config.maxCooldown) {
                cooldownPeriod = config.confirmedCooldown;
            }
        }
        const timeSinceLastNotification = now - data.lastNotification;
        const rateLimited = timeSinceLastNotification < cooldownPeriod;
        const remainingSeconds = rateLimited
            ? Math.ceil((cooldownPeriod - timeSinceLastNotification) / 1000)
            : 0;
        return {
            severity,
            rateLimited,
            remainingSeconds,
            lastResponse: data.lastUserResponse,
            cooldownType: ((_a = data.lastUserResponse) === null || _a === void 0 ? void 0 : _a.response) === "no" ? "extended" : "normal",
        };
    });
    const statuses = await Promise.all(statusPromises);
    return {
        userId,
        timestamp: now,
        rateLimitStatuses: statuses,
    };
});
//# sourceMappingURL=enhancedRateLimiting.js.map