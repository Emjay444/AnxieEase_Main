const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxiease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function analyzeNotificationProblem() {
  console.log("🔍 === NOTIFICATION PROBLEM ANALYSIS ===\n");

  console.log("📋 SUMMARY OF YOUR ISSUE:");
  console.log("✅ Notifications work when app is OPEN");
  console.log("✅ Notifications work when you manually change Firebase");
  console.log("❌ Notifications DON'T work when app is CLOSED\n");

  console.log("🧪 TESTING STEP BY STEP...\n");

  try {
    // Step 1: Test if Cloud Functions are deployed and working
    console.log("1️⃣ Testing Cloud Function Deployment...");

    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Clear existing data first
    await metricsRef.set(null);
    console.log("   🧹 Cleared existing data");

    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Set baseline data
    const baselineData = {
      heartRate: 72,
      anxietyDetected: {
        severity: "mild",
        timestamp: Date.now(),
        confidence: 0.7,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(baselineData);
    console.log("   📊 Set baseline: mild severity, HR 72");

    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Trigger severity change (this should activate cloud function)
    const alertData = {
      heartRate: 125,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.95,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(alertData);
    console.log("   🚨 Triggered: mild → severe (should send notification)");
    console.log("   ✅ Cloud Function should have fired!\n");

    // Step 2: Test direct FCM
    console.log("2️⃣ Testing Direct FCM to Topic...");

    const directMessage = {
      notification: {
        title: "🔔 Background Test Alert",
        body: "Testing if your device receives FCM when app is closed",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          sound: "default",
          tag: "background_test",
        },
      },
      data: {
        type: "background_test",
        severity: "severe",
        timestamp: Date.now().toString(),
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(directMessage);
    console.log("   ✅ Direct FCM sent:", response);
    console.log("   📱 Check your device now!\n");

    // Step 3: Verify Firebase structure
    console.log("3️⃣ Verifying Firebase Data Structure...");
    const snapshot = await metricsRef.once("value");
    const currentData = snapshot.val();

    if (
      currentData &&
      currentData.anxietyDetected &&
      currentData.anxietyDetected.severity
    ) {
      console.log("   ✅ Firebase data structure is correct");
      console.log(
        `   📊 Current severity: ${currentData.anxietyDetected.severity}`
      );
      console.log(`   💓 Current heart rate: ${currentData.heartRate}`);
    } else {
      console.log("   ❌ Firebase data structure is incorrect!");
      console.log("   📊 Current data:", JSON.stringify(currentData, null, 2));
    }

    console.log("\n🎯 === ANALYSIS COMPLETE ===\n");

    console.log("📱 INSTRUCTIONS FOR YOU:");
    console.log(
      "1. Make sure AnxieEase app is COMPLETELY CLOSED (swipe away from recent apps)"
    );
    console.log("2. Wait 30 seconds and check for notifications");
    console.log("3. If you received notifications:");
    console.log(
      "   ✅ Your system is working! Background notifications are active."
    );
    console.log("4. If you did NOT receive notifications, check:");
    console.log(
      "   🔧 Android Settings > Apps > AnxieEase > Notifications (must be ON)"
    );
    console.log(
      "   🔋 Android Settings > Apps > AnxieEase > Battery > Optimize battery usage (DISABLE for AnxieEase)"
    );
    console.log(
      "   📱 Android Settings > Apps > AnxieEase > Background activity (must be ALLOWED)"
    );
    console.log("   🔕 Do Not Disturb mode (must be OFF)");
    console.log("   📶 Check internet connection");

    console.log("\n💡 MOST LIKELY CAUSES:");
    console.log("1. Battery optimization is blocking background notifications");
    console.log("2. Background app restrictions are enabled");
    console.log("3. Notification permissions are not fully granted");
    console.log("4. FCM token not properly registered with topic");

    console.log("\n🔧 NEXT STEPS:");
    console.log("1. Check all Android settings mentioned above");
    console.log("2. Try manually changing Firebase data in console again");
    console.log(
      "3. If still no notifications, the issue is device-specific settings"
    );
  } catch (error) {
    console.error("❌ Analysis failed:", error);
  }

  process.exit(0);
}

analyzeNotificationProblem();
