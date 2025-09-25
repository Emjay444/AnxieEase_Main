// Test custom notification sounds from server side
// This simulates the Firebase Cloud Function sending notifications with custom sounds

const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure service-account-key.json exists)
if (!admin.apps.length) {
  try {
    const serviceAccount = require('./service-account-key.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
    });
    console.log("✅ Firebase Admin initialized");
  } catch (error) {
    console.log("❌ Error initializing Firebase Admin:", error.message);
    console.log("   Make sure service-account-key.json exists in the project root");
    process.exit(1);
  }
}

// Test data for different severity levels
const testNotifications = {
  mild: {
    title: "🟢 Mild Anxiety Detected (Server Test)",
    body: "Heart rate slightly elevated. Testing mild alert sound.",
    sound: "mild_alert",
    color: "#66BB6A",
    channelId: "mild_anxiety_alerts"
  },
  moderate: {
    title: "🟠 Moderate Anxiety Alert (Server Test)", 
    body: "Moderate anxiety symptoms detected. Testing moderate alert sound.",
    sound: "moderate_alert",
    color: "#FF9800",
    channelId: "moderate_anxiety_alerts"
  },
  severe: {
    title: "🔴 Severe Anxiety Alert (Server Test)",
    body: "High anxiety levels detected! Testing severe alert sound.",
    sound: "severe_alert", 
    color: "#F44336",
    channelId: "severe_anxiety_alerts"
  },
  critical: {
    title: "🚨 CRITICAL Emergency Alert (Server Test)",
    body: "Critical situation detected. Testing emergency alert sound.",
    sound: "critical_alert",
    color: "#D32F2F", 
    channelId: "critical_anxiety_alerts"
  }
};

async function sendTestNotification(severity, userId = null) {
  const notificationData = testNotifications[severity];
  
  if (!notificationData) {
    console.log(`❌ Unknown severity: ${severity}`);
    return;
  }

  const message = {
    data: {
      type: "anxiety_alert_test",
      severity: severity,
      timestamp: Date.now().toString(),
      source: "server_test"
    },
    notification: {
      title: notificationData.title,
      body: notificationData.body,
    },
    android: {
      priority: severity === 'severe' || severity === 'critical' ? 'high' : 'normal',
      notification: {
        channelId: notificationData.channelId, // Use severity-specific channel
        defaultSound: false, // Use custom sound instead
        sound: notificationData.sound, // Custom sound file name
        defaultVibrateTimings: true,
        color: notificationData.color,
      },
    },
    apns: {
      payload: {
        aps: {
          badge: 1,
          sound: `${notificationData.sound}.mp3`, // iOS sound file
        },
      },
    },
    topic: userId ? `user_${userId}` : 'test_notifications',
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`✅ ${severity} notification sent successfully:`, response);
    return response;
  } catch (error) {
    console.log(`❌ Error sending ${severity} notification:`, error.message);
    return null;
  }
}

async function testAllSeverityNotifications(userId = null) {
  console.log("🔔 TESTING ALL SEVERITY NOTIFICATION SOUNDS");
  console.log("=" * 50);
  
  const severities = ['mild', 'moderate', 'severe', 'critical'];
  
  for (let i = 0; i < severities.length; i++) {
    const severity = severities[i];
    console.log(`\n📱 Sending ${severity} notification...`);
    
    await sendTestNotification(severity, userId);
    
    // Wait 3 seconds between notifications
    if (i < severities.length - 1) {
      console.log(`   ⏳ Waiting 3 seconds before next notification...`);
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  }
  
  console.log("\n🎉 All test notifications sent!");
  console.log("\n📱 Check your device for notifications with different sounds:");
  console.log("   🟢 Mild: Gentle chime");
  console.log("   🟠 Moderate: Clear notification");  
  console.log("   🔴 Severe: Urgent sound + action buttons");
  console.log("   🚨 Critical: Emergency tone + full screen");
}

// Command line interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    // Test all severities
    await testAllSeverityNotifications();
  } else {
    const severity = args[0].toLowerCase();
    const userId = args[1] || null;
    
    if (testNotifications[severity]) {
      console.log(`🔔 Testing ${severity} notification...`);
      await sendTestNotification(severity, userId);
    } else {
      console.log("❌ Invalid severity. Use: mild, moderate, severe, or critical");
      console.log("\nUsage:");
      console.log("  node test_server_notifications.js                    // Test all");
      console.log("  node test_server_notifications.js mild               // Test mild only");
      console.log("  node test_server_notifications.js severe user123     // Test severe for specific user");
    }
  }
}

// Export functions for use in other scripts
module.exports = {
  sendTestNotification,
  testAllSeverityNotifications
};

// Run main function if script is called directly
if (require.main === module) {
  main().catch(console.error);
}