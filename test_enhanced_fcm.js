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

console.log("🚀 TESTING ENHANCED FCM HANDLER WITH DATABASE STORAGE");
console.log("═".repeat(65));

async function testEnhancedNotifications() {
  console.log("🔧 ENHANCEMENTS MADE:");
  console.log("─".repeat(40));
  console.log("✅ Enhanced FCM detection conditions");
  console.log("✅ Added comprehensive debugging logs");
  console.log("✅ Improved error handling for storage");
  console.log('✅ Changed notification type to "alert" (matches your filters)');
  console.log("✅ Added severity-specific navigation:");
  console.log("   🟢 Mild → Notifications screen");
  console.log("   🟡 Moderate → Breathing exercises");
  console.log("   🟠 Severe → Grounding techniques");
  console.log("   🔴 Critical → Notifications screen");

  console.log("\n📤 Sending test notification with enhanced debugging...");

  try {
    const testMessage = {
      notification: {
        title: "🟡 Enhanced Test - Moderate Anxiety Alert",
        body: "Testing enhanced FCM handler with database storage. HR: 95 BPM",
      },
      data: {
        type: "anxiety_alert",
        messageType: "anxiety_alert",
        severity: "moderate",
        heartRate: "95",
        baseline: "72",
        percentageAbove: "32",
        timestamp: Date.now().toString(),
        notificationId: `enhanced_test_${Date.now()}`,
        source: "enhanced_test",
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(testMessage);
    console.log("✅ Enhanced test notification sent:", response);

    console.log("\n📱 WHAT TO CHECK IN YOUR APP:");
    console.log("─".repeat(40));
    console.log("1. 📱 Pop-up notification should appear");
    console.log("2. 🔍 Check Flutter debug console for these NEW messages:");
    console.log('   - "🚨 ANXIETY ALERT DETECTED:"');
    console.log('   - "💾 Storing anxiety alert with details:"');
    console.log('   - "🔄 Triggering notification refresh..."');
    console.log('   - "✅ Successfully stored anxiety alert notification"');

    console.log("\n3. 🏠 Check homepage notification section");
    console.log('4. 🔔 Check notification screen "All" and "Alert" tabs');
    console.log(
      "5. 👆 Tap notification → Should go to BREATHING screen (moderate)"
    );

    console.log("\n⭐ IF THIS WORKS:");
    console.log("• Notification appears in app screens ✅");
    console.log("• Tapping moderate alerts goes to breathing exercises ✅");
    console.log("• Database storage is working ✅");

    console.log("\n🔍 IF STILL NOT WORKING:");
    console.log("• Check debug console for error messages");
    console.log("• May need to investigate user authentication in Flutter");
  } catch (error) {
    console.error(
      "❌ Error sending enhanced test notification:",
      error.message
    );
  }
}

testEnhancedNotifications().catch(console.error);
