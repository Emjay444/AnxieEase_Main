const admin = require("firebase-admin");
const fs = require("fs");

// Initialize Firebase Admin SDK
try {
  // Check if service account key exists
  if (!fs.existsSync("./service-account-key.json")) {
    console.error("❌ service-account-key.json not found!");
    console.log(
      "📋 Please download it from Firebase Console > Project Settings > Service Accounts > Generate new private key"
    );
    process.exit(1);
  }

  // Initialize Firebase Admin
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });

  console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error);
  process.exit(1);
}

async function testBackgroundNotifications() {
  try {
    console.log("🧪 Testing Background Notifications When App is Closed...");
    console.log(
      "📱 Make sure your app is COMPLETELY CLOSED (not just in background)"
    );
    console.log("⏳ Waiting 5 seconds for you to close the app...\n");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test scenarios for different severity levels
    const testCases = [
      {
        severity: "mild",
        title: "🟢 Mild Anxiety Alert",
        body: "Slight elevation detected. HR: 85 bpm. Take a deep breath.",
        heartRate: 85,
      },
      {
        severity: "moderate",
        title: "🟠 Moderate Anxiety Alert",
        body: "Noticeable symptoms detected. HR: 105 bpm. Consider relaxation techniques.",
        heartRate: 105,
      },
      {
        severity: "severe",
        title: "🔴 SEVERE Anxiety Alert",
        body: "URGENT: High anxiety detected! HR: 125 bpm. Please use breathing exercises immediately.",
        heartRate: 125,
      },
    ];

    for (let i = 0; i < testCases.length; i++) {
      const testCase = testCases[i];
      console.log(`\n📢 Test ${i + 1}/3: Sending ${testCase.severity} alert`);

      // Create the message with both notification and data payload
      const message = {
        // Topic-based messaging (sends to all subscribed devices)
        topic: "anxiety_alerts",

        // Notification payload - this is what FCM shows when app is closed
        notification: {
          title: testCase.title,
          body: testCase.body,
        },

        // Data payload - this is processed by your background handler
        data: {
          severity: testCase.severity,
          heartRate: testCase.heartRate.toString(),
          timestamp: Date.now().toString(),
          type: "anxiety_alert",
          action: "show_details",
        },

        // Android-specific configuration
        android: {
          priority: "high",
          notification: {
            icon: "ic_notification",
            color:
              testCase.severity === "severe"
                ? "#FF0000"
                : testCase.severity === "moderate"
                ? "#FFA500"
                : "#00FF00",
            channelId: "anxiety_alerts",
            priority: testCase.severity === "severe" ? "max" : "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
            sticky: testCase.severity === "severe",
          },
        },

        // iOS-specific configuration
        apns: {
          payload: {
            aps: {
              alert: {
                title: testCase.title,
                body: testCase.body,
              },
              badge: 1,
              sound: "default",
              "content-available": 1,
            },
          },
        },
      };

      try {
        // Send the message
        const response = await admin.messaging().send(message);
        console.log(`✅ Message sent successfully: ${response}`);
        console.log(`   Title: ${testCase.title}`);
        console.log(`   Body: ${testCase.body}`);
        console.log(`   Severity: ${testCase.severity}`);

        // Wait between messages to see them clearly
        if (i < testCases.length - 1) {
          console.log("⏳ Waiting 10 seconds before next alert...");
          await new Promise((resolve) => setTimeout(resolve, 10000));
        }
      } catch (error) {
        console.error(`❌ Error sending ${testCase.severity} alert:`, error);
      }
    }

    console.log("\n🎯 All background notification tests completed!");
    console.log("\n📱 You should have received 3 notifications:");
    console.log("   1. 🟢 Mild alert (green)");
    console.log("   2. 🟠 Moderate alert (orange)");
    console.log("   3. 🔴 Severe alert (red, high priority)");
    console.log("\n✅ If you didn't receive notifications, check:");
    console.log("   - App permissions (Notifications enabled)");
    console.log("   - Battery optimization (App not optimized)");
    console.log("   - Do Not Disturb settings");
    console.log("   - Your device's manufacturer-specific settings");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

// Allow testing specific severity levels
const severityArg = process.argv[2];
if (severityArg) {
  // Test specific severity
  console.log(`🎯 Testing ${severityArg} alert only...`);
  testBackgroundNotifications();
} else {
  // Test all severities
  testBackgroundNotifications();
}

