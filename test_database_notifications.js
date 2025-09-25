const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxiease-main-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

console.log("🔔 SENDING DATABASE-COMPATIBLE ANXIETY NOTIFICATIONS");
console.log("═".repeat(60));

async function sendDatabaseCompatibleNotifications() {
  console.log(
    "📋 These notifications will be stored in Supabase AND show in your app screens!"
  );
  console.log("─".repeat(60));

  const severityTests = [
    {
      severity: "mild",
      title: "🟢 Mild Anxiety Alert",
      body: "Slight elevation in heart rate detected. Stay calm.",
      heartRate: 82,
      baseline: 72,
    },
    {
      severity: "moderate",
      title: "🟡 Moderate Anxiety Alert",
      body: "Moderate anxiety level detected. Consider breathing exercises.",
      heartRate: 95,
      baseline: 72,
    },
    {
      severity: "severe",
      title: "🟠 Severe Anxiety Alert",
      body: "High anxiety levels detected. Immediate attention needed.",
      heartRate: 110,
      baseline: 72,
    },
    {
      severity: "critical",
      title: "🔴 Critical Anxiety Alert",
      body: "Critical anxiety levels detected! Please seek help immediately.",
      heartRate: 125,
      baseline: 72,
    },
  ];

  for (let i = 0; i < severityTests.length; i++) {
    const test = severityTests[i];
    const percentageAbove = Math.round(
      ((test.heartRate - test.baseline) / test.baseline) * 100
    );

    try {
      const message = {
        notification: {
          title: test.title,
          body: test.body,
        },
        data: {
          type: "anxiety_alert",
          severity: test.severity,
          heartRate: test.heartRate.toString(),
          baseline: test.baseline.toString(),
          percentageAbove: percentageAbove.toString(),
          timestamp: Date.now().toString(),
          notificationId: `test_${test.severity}_${Date.now()}`,
          // Make sure the FCM handler recognizes this as anxiety alert
          messageType: "anxiety_alert",
        },
        topic: "anxiety_alerts",
      };

      const response = await admin.messaging().send(message);
      console.log(
        `✅ Sent ${test.severity} alert (HR: ${test.heartRate}, +${percentageAbove}%):`,
        response
      );

      // Add delay between notifications
      await new Promise((resolve) => setTimeout(resolve, 3000));
    } catch (error) {
      console.error(
        `❌ Error sending ${test.severity} notification:`,
        error.message
      );
    }
  }

  console.log("\n🎯 WHAT TO EXPECT:");
  console.log("─".repeat(40));
  console.log("1. 📱 Pop-up notifications with in-app banners");
  console.log("2. 💾 Notifications stored in Supabase database");
  console.log("3. 🏠 Notifications appear in homepage notification section");
  console.log("4. 🔔 Notifications appear in notification screen");
  console.log("5. 🎨 Different severity colors and behaviors");

  console.log("\n📱 TAP BEHAVIOR TEST:");
  console.log("─".repeat(40));
  console.log("After receiving notifications:");
  console.log("• Check homepage → Should see notification cards");
  console.log(
    '• Check notification screen → Should see in "All" and "Alerts" filters'
  );
  console.log(
    "• Tap any notification → Should navigate to notifications screen"
  );

  console.log("\n🔍 TROUBLESHOOTING:");
  console.log("─".repeat(40));
  console.log("If notifications still don't appear in app screens:");
  console.log('1. Check FCM handler is recognizing "anxiety" in title');
  console.log("2. Check _storeAnxietyAlertNotification is being called");
  console.log("3. Check Supabase connection and notification storage");
  console.log("4. Check notification refresh is triggered");
}

sendDatabaseCompatibleNotifications().catch(console.error);
