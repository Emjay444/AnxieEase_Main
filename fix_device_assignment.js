// FIX DEVICE ASSIGNMENT AND FCM TOKEN REGISTRATION
// This will assign your device to your user and set up FCM token

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

async function fixDeviceAssignment() {
  console.log("🔧 FIXING DEVICE ASSIGNMENT AND NOTIFICATION SETUP");
  console.log("==================================================\n");

  try {
    // Step 1: Assign device to user (you'll need your actual user ID)
    console.log("1️⃣ ASSIGNING DEVICE TO USER:");
    console.log("============================");

    // This should be your actual user ID from Supabase/Firebase Auth
    // You can find this in your Flutter app when you log in
    const yourUserId = "5afad7d4-3dcd-4353-badb-4f68..."; // Replace with your real user ID

    const deviceRef = db.ref("/devices/AnxieEase001");
    await deviceRef.update({
      userId: yourUserId,
      assigned: true,
      assignedAt: Date.now(),
      assignedBy: "admin_fix",
    });

    console.log(`✅ Device AnxieEase001 assigned to user: ${yourUserId}`);

    // Step 2: Set up user FCM token placeholder
    console.log("\n2️⃣ SETTING UP FCM TOKEN PLACEHOLDER:");
    console.log("====================================");

    const userRef = db.ref(`/users/${yourUserId}`);
    await userRef.update({
      fcmToken: "PENDING_FROM_APP", // App will update this with real token
      deviceId: "AnxieEase001",
      notificationsEnabled: true,
      lastSeen: Date.now(),
    });

    console.log("✅ User FCM token placeholder created");

    // Step 3: Create baseline data
    console.log("\n3️⃣ SETTING UP BASELINE DATA:");
    console.log("============================");

    const baselineRef = db.ref(`/baselines/${yourUserId}/AnxieEase001`);
    await baselineRef.set({
      baselineHR: 73.9, // Your correct baseline
      createdAt: Date.now(),
      isActive: true,
      method: "manual_setup",
    });

    console.log("✅ Baseline heart rate set to 73.9 BPM");

    // Step 4: Test notification system
    console.log("\n4️⃣ TESTING NOTIFICATION TRIGGER:");
    console.log("=================================");

    const currentDataRef = db.ref("/devices/AnxieEase001/current");
    await currentDataRef.set({
      heartRate: 92, // Should trigger mild anxiety (above 88.9)
      spo2: 98,
      bodyTemp: 36.5,
      timestamp: Date.now(),
      sessionId: `test_${Date.now()}`,
      worn: 1,
      // Low movement (sitting)
      accelX: 5.2,
      accelY: 2.1,
      accelZ: 7.8,
      gyroX: 0.01,
      gyroY: -0.01,
      gyroZ: 0.0,
      deviceId: "AnxieEase001",
    });

    console.log("🚨 Test anxiety trigger created (HR: 92 BPM)");
    console.log("   This should now trigger notifications!");

    console.log("\n5️⃣ NEXT STEPS FOR YOU:");
    console.log("======================");
    console.log("1. 📱 Open your AnxieEase Flutter app");
    console.log("2. 🔍 Check console logs for FCM token registration");
    console.log(
      "3. 🔄 The app should automatically update the FCM token in Firebase"
    );
    console.log("4. 📬 You should start receiving notifications");
    console.log(
      "5. ⚠️  If still no notifications, check device notification permissions"
    );

    console.log("\n🔍 HOW TO FIND YOUR REAL USER ID:");
    console.log("=================================");
    console.log(
      "In your Flutter app, add this debug code to see your user ID:"
    );
    console.log("```dart");
    console.log("final user = Supabase.instance.client.auth.currentUser;");
    console.log('debugPrint("Your User ID: ${user?.id}");');
    console.log("```");
    console.log(
      "Then replace the userId in this script with your real ID and run again."
    );

    console.log("\n💡 NOTIFICATION FLOW:");
    console.log("====================");
    console.log("1. Device sends data → Firebase RTDB");
    console.log("2. Firebase Function detects anxiety → Calculates thresholds");
    console.log("3. Function sends FCM notification → Your device");
    console.log("4. Flutter app receives notification → Shows alert");
    console.log("5. User taps notification → Opens confirmation dialog");

    console.log("\n🎯 VERIFICATION STEPS:");
    console.log("======================");
    console.log("After running your app:");
    console.log(
      "✓ Check Firebase console for FCM token under /users/yourId/fcmToken"
    );
    console.log(
      "✓ Verify device assignment under /devices/AnxieEase001/userId"
    );
    console.log("✓ Test with HR > 88.9 BPM to trigger mild anxiety alerts");
    console.log("✓ Check notification permissions in phone settings");
  } catch (error) {
    console.error("❌ Error fixing device assignment:", error.message);
  }
}

fixDeviceAssignment();
