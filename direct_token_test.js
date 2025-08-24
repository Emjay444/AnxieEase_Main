const admin = require("firebase-admin");

// Your FCM token from the logs
const FCM_TOKEN = "cVkrxye5SmOUCy52tLe0fz:APA91bEErAmLuDi91mluTyG6PKjRjEvUhNV59p56kGb3AB1sll-eUjZuntXIqiM7YohpsOmrp0WKQMU0FIC6-R2BoI7ZV5wFpFltQcGOZcIHATKzsuQ5-w";

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function directTokenTest() {
  console.log("🎯 DIRECT TOKEN TEST - ULTIMATE BACKGROUND CHECK");
  console.log("📱 CLOSE ANXIEEASE APP COMPLETELY!");
  console.log("⏳ Sending direct notification to your device in 5 seconds...\n");
  
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  try {
    // Direct message to your specific device
    const message = {
      notification: {
        title: "🔥 DIRECT TOKEN TEST",
        body: "SUCCESS! Background notifications are working!"
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK"
        }
      },
      data: {
        type: "test",
        severity: "severe",
        timestamp: Date.now().toString()
      },
      token: FCM_TOKEN
    };
    
    const response = await admin.messaging().send(message);
    console.log("✅ DIRECT notification sent to your device:", response);
    console.log("📱 If you see this notification, BATTERY SETTINGS ARE FIXED!");
    console.log("❌ If no notification, check battery optimization settings again.");
    
  } catch (error) {
    console.error("❌ Direct test failed:", error);
  }
  
  process.exit(0);
}

directTokenTest();
