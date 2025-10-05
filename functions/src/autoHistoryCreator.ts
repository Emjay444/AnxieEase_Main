import * as functions from "firebase-functions/v1";
// admin import removed as this function is now disabled

/**
 * DISABLED: Auto-create history (prevents timestamp duplicates)
 * 
 * This function has been disabled to prevent timestamp duplicate creation.
 * The device now handles its own history in native format (YYYY_MM_DD_HH_MM_SS)
 * and smartDeviceDataSync handles user session copying.
 * 
 * IMPORTANT: Do not create timestamp-based history entries to avoid duplication!
 */
export const autoCreateDeviceHistory = functions.database
  .ref("/devices/AnxieEase001/current")
  .onWrite(async (change, context) => {
    // DISABLED: This function no longer creates device history to prevent duplicates
    console.log("📱 autoCreateDeviceHistory: DISABLED to prevent timestamp duplicates");
    console.log("� Device native history (YYYY_MM_DD format) is handled by the wearable itself");
    console.log("💡 User session history is handled by smartDeviceDataSync");
    
    // Log that this function was triggered but took no action
    if (change.after.exists()) {
      console.log("✅ Device current data updated - letting device handle native history format");
      console.log("🚫 NOT creating timestamp duplicate in device history");
    }

    return { 
      success: true, 
      action: "disabled_to_prevent_duplicates",
      message: "Device handles native format, smartDeviceDataSync handles user sessions" 
    };
  });
