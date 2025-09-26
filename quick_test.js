const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function quickTest() {
  console.log("📱 QUICK NOTIFICATION TEST");
  console.log("═".repeat(30));

  try {
    const fcmToken =
      "dJlsLVwwQlm7_qwAqlvxej:APA91bHst58wqLrOsqICaHX7rqTzNRSvXhOoV7oV3n1uxaU0LtUa7xwvr1L3NdlIM9IhfPY8aLrUU8WAX_uklVH8eIsnR_prV5gsN24znhYwIJcta-xyKKE";

    console.log("📤 Sending test with wake-up settings...");

    const message = {
      token: fcmToken,
      notification: {
        title: "⚠️ URGENT TEST",
        body: "Check if this notification wakes up your device",
      },
      data: {
        wake_screen: "true",
        importance: "max",
      },
      android: {
        priority: "high",
        notification: {
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
          defaultLightSettings: true,
          visibility: "public",
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Urgent test sent:", response);

    console.log("\n🔍 QUICK CHECKLIST:");
    console.log("1. 📱 Is your phone screen ON and unlocked?");
    console.log("2. 🔊 Is sound/vibration enabled?");
    console.log("3. ⚡ Is the app completely closed (not just minimized)?");
    console.log("4. 🌐 Does your device have internet connectivity?");
    console.log(
      "5. 🔔 Are notifications enabled for the app in system settings?"
    );

    // Also test a simple browser notification
    console.log(
      "\n🌐 If you have Chrome/Firefox open, you might see a web notification too"
    );
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

quickTest();
