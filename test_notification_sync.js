const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function clearRateLimitsAndTest() {
  console.log("🧪 TESTING NOTIFICATION SYNC WITH DEBUG");
  console.log("═".repeat(50));

  try {
    // 1. Clear rate limits first
    console.log("1️⃣ Clearing rate limits...");
    const response = await fetch(
      "https://us-central1-anxieease-sensors.cloudfunctions.net/clearAnxietyRateLimits"
    );
    const result = await response.json();
    console.log("✅ Rate limits cleared:", result.message);

    // 2. Send test data
    console.log("\n2️⃣ Sending test data for severe anxiety...");
    const db = admin.database();
    const deviceRef = db.ref("/devices/AnxieEase001/current");

    const testData = {
      heartRate: 125, // Should trigger severe (64-91% above baseline of 73.2)
      spo2: 97,
      temperature: 37.8,
      gsr: 22.0,
      batteryLevel: 80,
      signalStrength: "good",
      timestamp: new Date().toISOString().replace("T", " ").substring(0, 19),
      worn: 1,
      sessionId: "sync_test_" + Date.now(),
      userId: "5afad7d4-3dcd-4353-badb-4f155303419a",
      deviceId: "AnxieEase001",
    };

    await deviceRef.set(testData);
    console.log("✅ Test data sent to Firebase");
    console.log(
      `📊 Heart rate: ${testData.heartRate} BPM (should trigger severe = orange)`
    );

    console.log("\n3️⃣ Waiting 8 seconds for processing...");
    await new Promise((resolve) => setTimeout(resolve, 8000));

    console.log("\n🔍 DEBUG CHECKLIST FOR SYNC ISSUE:");
    console.log("═".repeat(50));
    console.log("1. Check Firebase Function Logs:");
    console.log("   - Go to Firebase Console → Functions");
    console.log("   - Look for realTimeSustainedAnxietyDetection logs");
    console.log("   - Should show: ✅ Rate limit passed, sending notification");

    console.log("\n2. Check Your Phone Notification:");
    console.log("   - Should receive 🟠 Severe Anxiety Alert");
    console.log("   - Should play severe_alert.mp3 sound");
    console.log("   - DON'T tap the notification yet");

    console.log("\n3. Background Handler Check:");
    console.log("   - Background handler should store in SharedPreferences");
    console.log("   - Look for: [BACKGROUND] Stored notification locally");

    console.log("\n4. App Sync Test:");
    console.log("   - CLOSE your app completely");
    console.log("   - OPEN app directly from launcher (not notification)");
    console.log("   - Check Flutter logs for:");
    console.log("     • '_syncPendingNotifications called'");
    console.log(
      "     • 'Total pending notifications found: X' (should be > 0)"
    );
    console.log("     • 'Successfully synced: 🟠 Severe Anxiety Alert'");

    console.log("\n5. Notifications Screen Check:");
    console.log("   - Navigate to Notifications tab");
    console.log("   - Should see the severe anxiety notification");
    console.log("   - If not there, sync failed!");

    console.log("\n🚨 If notification doesn't appear in app:");
    console.log("   → Background handler didn't store it (check logs)");
    console.log("   → Sync function failed (check Flutter logs)");
    console.log("   → Supabase createNotification failed");
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

clearRateLimitsAndTest();
