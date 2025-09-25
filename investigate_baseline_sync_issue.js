/**
 * 🔍 SUPABASE BASELINE SYNC ISSUE INVESTIGATION
 *
 * Problem: When device assignment changes, baseline_heart_rates doesn't sync
 * with the actual user's baseline from their profile data
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function investigateBaselineSyncIssue() {
  console.log("\n🔍 SUPABASE BASELINE SYNC ISSUE ANALYSIS");
  console.log("=========================================");

  try {
    console.log("📊 PROBLEM IDENTIFIED:");
    console.log("======================");
    console.log("From your Supabase screenshots:");
    console.log("");
    console.log("DEVICE ASSIGNMENT (wearable_devices):");
    console.log(
      "• User 1: 5afad7d4-3dcd-4353-badb-4f68... → baseline_hr: 73.2 BPM"
    );
    console.log(
      "• User 2: e0997cb7-684f-41e5-929f-4480... → baseline_hr: 88.2 BPM"
    );
    console.log("");
    console.log("BASELINE TABLE (baseline_heart_rates):");
    console.log(
      "• User 1: 5afad7d4-3dcd-4353-badb-4f68... → baseline_hr: 73.9 BPM ❌ MISMATCH!"
    );
    console.log(
      "• User 2: e0997cb7-684f-41e5-929f-4480... → baseline_hr: 88.2 BPM ✅ Match"
    );

    console.log("\n🚨 ROOT CAUSE:");
    console.log("==============");
    console.log("1. Admin changes device assignment in wearable_devices table");
    console.log("2. The baseline_hr field gets updated in wearable_devices");
    console.log("3. BUT baseline_heart_rates table doesn't sync automatically");
    console.log("4. This creates inconsistent baseline data across tables");

    console.log("\n💡 WHY THIS HAPPENS:");
    console.log("====================");
    console.log("• wearable_devices.baseline_hr = Device assignment baseline");
    console.log(
      "• baseline_heart_rates.baseline_hr = User's actual profile baseline"
    );
    console.log(
      "• When device reassigned, user profile baseline doesn't change"
    );
    console.log("• Two different baselines exist for same user!");

    // Check current Firebase state
    console.log("\n🔍 FIREBASE CURRENT STATE:");
    console.log("==========================");

    const currentUser = "5afad7d4-3dcd-4353-badb-4f155303419a";

    const userRef = db.ref(`/users/${currentUser}`);
    const userSnapshot = await userRef.once("value");

    if (userSnapshot.exists()) {
      const userData = userSnapshot.val();

      if (userData.baseline) {
        console.log(
          `Firebase User Baseline: ${userData.baseline.heartRate} BPM`
        );
        console.log(`Source: ${userData.baseline.source}`);
        console.log(
          `Timestamp: ${new Date(userData.baseline.timestamp).toLocaleString()}`
        );
      } else {
        console.log("No Firebase baseline found");
      }
    }

    console.log("\n🎯 THE SYNC PROBLEMS:");
    console.log("=====================");
    console.log("1. 📱 Device assignment table shows one baseline");
    console.log("2. 👤 User profile table shows different baseline");
    console.log("3. 🔥 Firebase gets synced with device assignment baseline");
    console.log("4. ❌ Inconsistent data across all systems");

    console.log("\n🔧 WHAT SHOULD HAPPEN:");
    console.log("======================");
    console.log("When admin assigns device to user:");
    console.log("1. ✅ Update wearable_devices assignment");
    console.log("2. ✅ Fetch user's ACTUAL baseline from their profile");
    console.log(
      "3. ✅ Update wearable_devices.baseline_hr with user's real baseline"
    );
    console.log("4. ✅ Sync baseline_heart_rates table if needed");
    console.log("5. ✅ Firebase gets user's correct baseline via webhook");

    console.log("\n🚀 SOLUTIONS:");
    console.log("=============");

    console.log("\nOption 1: SUPABASE TRIGGER/FUNCTION");
    console.log(
      "• Create Supabase function triggered on wearable_devices update"
    );
    console.log("• Function fetches user's actual baseline from user profile");
    console.log("• Updates baseline_heart_rates table automatically");

    console.log("\nOption 2: ADMIN INTERFACE IMPROVEMENT");
    console.log(
      "• When admin assigns device, auto-populate user's real baseline"
    );
    console.log("• Show user's current baseline before assignment");
    console.log("• Allow admin to confirm/adjust baseline");

    console.log("\nOption 3: FIREBASE FUNCTION ENHANCEMENT");
    console.log("• Webhook sync function validates baseline consistency");
    console.log("• If mismatch detected, use most recent/accurate baseline");
    console.log("• Log warnings for baseline inconsistencies");

    console.log("\n⚡ IMMEDIATE FIX NEEDED:");
    console.log("=======================");
    console.log("1. Identify which baseline is correct (73.2 or 73.9 BPM)");
    console.log("2. Update both tables to use same baseline");
    console.log("3. Implement automatic sync for future assignments");
    console.log("4. Test anxiety detection with correct baseline");

    console.log("\n🎯 CRITICAL IMPACT:");
    console.log("===================");
    console.log("❌ Wrong baseline = Wrong anxiety detection thresholds");
    console.log("❌ User gets alerts at wrong heart rate levels");
    console.log("❌ False positives or missed anxiety episodes");
    console.log("❌ Inaccurate health monitoring");

    console.log("\n💡 QUESTIONS TO RESOLVE:");
    console.log("========================");
    console.log("1. Which baseline is the user's actual resting heart rate?");
    console.log("2. Should baseline_heart_rates be the master source?");
    console.log("3. How often should baselines be recalculated?");
    console.log("4. Should admin be able to override user baselines?");
  } catch (error) {
    console.error("❌ Investigation failed:", error.message);
  }
}

investigateBaselineSyncIssue();
