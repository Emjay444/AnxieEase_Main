// Script to clean up duplicate FCM token storage
// Run this to remove old device-level tokens that are no longer needed

const admin = require("firebase-admin");

// Initialize Firebase Admin SDK (you'll need to set up credentials)
async function cleanupDuplicateTokens() {
  console.log("🧹 Starting FCM token cleanup...");

  try {
    // For now, we'll just log what would be cleaned up
    // In a real implementation, you'd initialize Firebase Admin and clean up

    console.log("📋 What this script would do:");
    console.log("1. Find all devices with both:");
    console.log("   - /devices/{deviceId}/fcmToken (old)");
    console.log("   - /devices/{deviceId}/assignment/fcmToken (new)");
    console.log("2. Remove the old device-level tokens");
    console.log("3. Keep only assignment-level tokens");

    console.log("\n✅ Manual cleanup steps:");
    console.log("1. Go to Firebase Console → Realtime Database");
    console.log("2. Navigate to /devices/AnxieEase001/");
    console.log('3. Delete the "fcmToken" field (not the assignment folder)');
    console.log('4. Keep the "assignment/fcmToken" field');

    console.log("\n🔍 Verify cleanup:");
    console.log(
      "- Assignment node should have: assignedUser, fcmToken, status"
    );
    console.log("- Device root should NOT have a direct fcmToken field");
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

// Run the cleanup
cleanupDuplicateTokens();
