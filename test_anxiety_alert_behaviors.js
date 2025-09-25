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

console.log("🔔 TESTING ANXIETY ALERT NOTIFICATION BEHAVIORS");
console.log("═".repeat(60));

// Test different severity levels
async function testSeverityNotifications() {
  console.log("\n📱 CURRENT NOTIFICATION BEHAVIOR ANALYSIS:");
  console.log("─".repeat(50));

  console.log("\n🟢 MILD ALERT BEHAVIOR:");
  console.log('• Title: "🟢 Mild Anxiety Alert"');
  console.log("• Channel: anxiety_alerts");
  console.log("• Category: Reminder");
  console.log("• When Tapped: → Goes to /notifications screen");
  console.log('• Payload: severity="mild", type="anxiety_alert"');
  console.log("• Special Features: None");

  console.log("\n🟡 MODERATE ALERT BEHAVIOR:");
  console.log('• Title: "🟡 Moderate Anxiety Alert"');
  console.log("• Channel: anxiety_alerts");
  console.log("• Category: Reminder");
  console.log("• When Tapped: → Goes to /notifications screen");
  console.log('• Payload: severity="moderate", type="anxiety_alert"');
  console.log("• Special Features: None");

  console.log("\n🟠 SEVERE ALERT BEHAVIOR:");
  console.log('• Title: "🟠 Severe Anxiety Alert"');
  console.log("• Channel: anxiety_alerts");
  console.log("• Category: Alarm (⚡ Enhanced)");
  console.log("• When Tapped: → Goes to /notifications screen");
  console.log('• Payload: severity="severe", type="anxiety_alert"');
  console.log("• Special Features: ");
  console.log("  - Wake up screen: ✅");
  console.log("  - Full screen intent: ✅");
  console.log("  - Critical alert: ✅");
  console.log("  - Action Buttons: DISMISS + VIEW_DETAILS");

  console.log("\n🔴 CRITICAL ALERT BEHAVIOR:");
  console.log('• Title: "🔴 Critical Anxiety Alert"');
  console.log("• Channel: anxiety_alerts");
  console.log("• Category: Alarm (⚡ Enhanced)");
  console.log("• When Tapped: → Goes to /notifications screen");
  console.log('• Payload: severity="critical", type="anxiety_alert"');
  console.log("• Special Features: ");
  console.log("  - Wake up screen: ✅");
  console.log("  - Full screen intent: ✅");
  console.log("  - Critical alert: ✅");
  console.log("  - Action Buttons: DISMISS + VIEW_DETAILS");

  console.log("\n⚠️  CURRENT LIMITATION:");
  console.log("• ALL severity levels go to same screen (/notifications)");
  console.log("• No severity-specific behavior differentiation");
  console.log("• Severe/Critical have same behavior (should be different)");

  console.log("\n🎯 SUGGESTED IMPROVEMENTS:");
  console.log("─".repeat(50));

  console.log("\n🟢 MILD → /notifications (current behavior OK)");
  console.log("   ✅ Simple notification list view");

  console.log("\n🟡 MODERATE → /breathing or /grounding");
  console.log("   💡 Immediate coping mechanism");
  console.log("   💡 Help user manage anxiety before it escalates");

  console.log(
    "\n🟠 SEVERE → /emergency_actions or Enhanced notification screen"
  );
  console.log("   🚨 Show emergency contacts");
  console.log("   🚨 Quick access to breathing exercises");
  console.log("   🚨 Option to call for help");

  console.log("\n🔴 CRITICAL → /emergency_call or Crisis intervention");
  console.log("   🆘 Direct emergency contact options");
  console.log("   🆘 Crisis helpline numbers");
  console.log("   🆘 Location sharing for help");

  // Generate test notifications
  console.log("\n🧪 GENERATING TEST NOTIFICATIONS:");
  console.log("─".repeat(50));

  const severityTests = [
    {
      severity: "mild",
      title: "🟢 Test Mild Alert",
      body: "Slight elevation detected. Tap to view details.",
      emoji: "🟢",
    },
    {
      severity: "moderate",
      title: "🟡 Test Moderate Alert",
      body: "Moderate anxiety detected. Consider breathing exercises.",
      emoji: "🟡",
    },
    {
      severity: "severe",
      title: "🟠 Test Severe Alert",
      body: "High anxiety levels detected. Immediate attention needed.",
      emoji: "🟠",
    },
    {
      severity: "critical",
      title: "🔴 Test Critical Alert",
      body: "Critical anxiety levels! Please seek immediate help.",
      emoji: "🔴",
    },
  ];

  for (let i = 0; i < severityTests.length; i++) {
    const test = severityTests[i];

    try {
      const message = {
        notification: {
          title: test.title,
          body: test.body,
        },
        data: {
          type: "anxiety_alert",
          severity: test.severity,
          timestamp: Date.now().toString(),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        topic: "anxiety_alerts",
      };

      const response = await admin.messaging().send(message);
      console.log(
        `${test.emoji} Sent ${test.severity} test notification:`,
        response
      );

      // Add delay between notifications
      await new Promise((resolve) => setTimeout(resolve, 2000));
    } catch (error) {
      console.error(
        `❌ Error sending ${test.severity} notification:`,
        error.message
      );
    }
  }

  console.log("\n📱 TAP EACH NOTIFICATION TO TEST BEHAVIOR:");
  console.log("─".repeat(50));
  console.log(
    "1. Tap the 🟢 Mild notification → Should go to notifications screen"
  );
  console.log(
    "2. Tap the 🟡 Moderate notification → Should go to notifications screen"
  );
  console.log(
    "3. Tap the 🟠 Severe notification → Should go to notifications screen"
  );
  console.log(
    "4. Tap the 🔴 Critical notification → Should go to notifications screen"
  );
  console.log("");
  console.log("💡 Notice: All currently go to same place (/notifications)");
  console.log("💡 We can enhance this to have severity-specific navigation!");

  console.log("\n🔧 WOULD YOU LIKE TO ENHANCE THE TAP BEHAVIOR?");
  console.log(
    "We can modify main.dart to handle different severities differently:"
  );
  console.log("• Mild → Notifications list");
  console.log("• Moderate → Breathing exercises");
  console.log("• Severe → Emergency actions screen");
  console.log("• Critical → Crisis intervention");
}

testSeverityNotifications().catch(console.error);
