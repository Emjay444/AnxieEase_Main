"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.autoCreateDeviceHistory = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.database();
/**
 * Auto-create history from current data updates
 * This function runs when /devices/AnxieEase001/current is updated
 * and automatically saves a copy to /devices/AnxieEase001/history
 */
exports.autoCreateDeviceHistory = functions.database
    .ref("/devices/AnxieEase001/current")
    .onWrite(async (change, context) => {
    // Only process if data was created or updated (not deleted)
    if (!change.after.exists()) {
        console.log("📱 Device current data deleted - no history to create");
        return null;
    }
    const currentData = change.after.val();
    const timestamp = Date.now();
    console.log(`📚 Auto-creating history entry for timestamp: ${timestamp}`);
    try {
        // Save current data to history
        const historyRef = db.ref(`/devices/AnxieEase001/history/${timestamp}`);
        await historyRef.set(Object.assign(Object.assign({}, currentData), { timestamp: timestamp, source: "auto_history_creator", created_from_current: true }));
        console.log(`✅ History entry created successfully at ${timestamp}`);
        return { success: true, timestamp };
    }
    catch (error) {
        console.error("❌ Error creating history entry:", error);
        // Log error for debugging
        await db.ref("/system/errors").push({
            type: "auto_history_creation_error",
            timestamp: admin.database.ServerValue.TIMESTAMP,
            error: error instanceof Error ? error.message : String(error),
            currentData: currentData
        });
        throw error;
    }
});
//# sourceMappingURL=autoHistoryCreator.js.map