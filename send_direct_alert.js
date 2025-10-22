/**
 * Direct Anxiety Alert Sender
 * Sends anxiety alerts directly via FCM (bypasses Cloud Function)
 * This works because test_simple_notification.js proved direct FCM works
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();
const messaging = admin.messaging();

const BASELINE_BPM = 76.4;
const TEST_DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

const HEART_RATES = {
  mild: Math.round(BASELINE_BPM * 1.25), // 96 BPM
  moderate: Math.round(BASELINE_BPM * 1.4), // 107 BPM
  severe: Math.round(BASELINE_BPM * 1.6), // 122 BPM
  critical: Math.round(BASELINE_BPM * 1.8), // 138 BPM
};

function getNotificationContent(severity, heartRate, baseline) {
  const percentageText =
    baseline > 0
      ? ` (${Math.round(
          ((heartRate - baseline) / baseline) * 100
        )}% above baseline)`
      : "";

  const hrText = ` ${heartRate} BPM`;

  switch (severity) {
    case "mild":
      return {
        title: "🟢 Mild Alert - 60% Confidence",
        body: `I noticed a slight increase in your heart rate to${hrText}${percentageText}. Are you experiencing any anxiety or is this just normal activity?`,
      };
    case "moderate":
      return {
        title: "🟡 Moderate Alert - 70% Confidence",
        body: `Your heart rate increased to${hrText}${percentageText}. How are you feeling? Is everything alright?`,
      };
    case "severe":
      return {
        title: "🔴 Severe Alert - 85% Confidence",
        body: `Hi there! I noticed your heart rate was elevated to${hrText}${percentageText}. Are you experiencing any anxiety or stress right now?`,
      };
    case "critical":
      return {
        title: "🚨 Critical Alert - 95% Confidence",
        body: `URGENT: Your heart rate has been critically elevated at${hrText}${percentageText}. This indicates a severe anxiety episode. Please seek immediate support if needed.`,
      };
    default:
      return {
        title: "📱 AnxieEase Alert",
        body: `Heart rate check:${hrText}${percentageText}`,
      };
  }
}

function getChannelIdForSeverity(severity) {
  switch (severity) {
    case "mild":
      return "mild_anxiety_alerts_v4";
    case "moderate":
      return "moderate_anxiety_alerts_v2";
    case "severe":
      return "severe_anxiety_alerts_v2";
    case "critical":
      return "critical_anxiety_alerts_v2";
    default:
      return "anxiease_channel";
  }
}

function getSoundForSeverity(severity) {
  switch (severity) {
    case "mild":
      return "mild_alerts.mp3";
    case "moderate":
      return "moderate_alerts.mp3";
    case "severe":
      return "severe_alerts.mp3";
    case "critical":
      return "critical_alerts.mp3";
    default:
      return "default";
  }
}

function getSeverityColor(severity) {
  switch (severity) {
    case "mild":
      return "#4CAF50";
    case "moderate":
      return "#FFFF00";
    case "severe":
      return "#FFA500";
    case "critical":
      return "#FF0000";
    default:
      return "#2196F3";
  }
}

async function sendDirectAnxietyAlert(severity) {
  try {
    console.log("✅ Firebase Admin initialized\n");
    console.log("🔍 Heart Rate Test Values Based on 76.4 BPM Baseline:");
    console.log(`📊 Mild: ${HEART_RATES.mild} BPM`);
    console.log(`📊 Moderate: ${HEART_RATES.moderate} BPM`);
    console.log(`📊 Severe: ${HEART_RATES.severe} BPM`);
    console.log(`📊 Critical: ${HEART_RATES.critical} BPM\n`);

    if (!["mild", "moderate", "severe", "critical"].includes(severity)) {
      console.error(
        "❌ Invalid severity. Use: mild, moderate, severe, or critical"
      );
      process.exit(1);
    }

    console.log(`🎯 Sending DIRECT ${severity.toUpperCase()} alert...\n`);

    // Get FCM token
    const assignmentSnapshot = await db
      .ref(`/devices/${TEST_DEVICE_ID}/assignment`)
      .once("value");

    if (!assignmentSnapshot.exists()) {
      console.error("❌ No assignment found!");
      process.exit(1);
    }

    const fcmToken = assignmentSnapshot.val().fcmToken;
    if (!fcmToken) {
      console.error("❌ No FCM token found!");
      process.exit(1);
    }

    console.log(`✅ FCM Token found: ${fcmToken.substring(0, 30)}...`);

    const heartRate = HEART_RATES[severity];
    const { title, body } = getNotificationContent(
      severity,
      heartRate,
      BASELINE_BPM
    );
    const percentageAbove = Math.round(
      ((heartRate - BASELINE_BPM) / BASELINE_BPM) * 100
    );
    const ts = Date.now();

    // Send FCM directly (bypassing Cloud Function)
    const message = {
      token: fcmToken,
      data: {
        type: "anxiety_alert",
        severity: severity,
        heartRate: heartRate.toString(),
        baseline: BASELINE_BPM.toString(),
        percentageAbove: percentageAbove.toString(),
        timestamp: ts.toString(),
        notificationId: `${severity}_${ts}`,
        deviceId: TEST_DEVICE_ID,
        userId: TEST_USER_ID,
        title: title,
        message: body,
        channelId: getChannelIdForSeverity(severity),
        sound: getSoundForSeverity(severity),
        color: getSeverityColor(severity),
        requiresConfirmation: "false",
        alertType: "direct",
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    };

    console.log(`\n📤 Sending ${severity} anxiety alert via FCM...`);
    const response = await messaging.send(message);
    console.log(`✅ FCM message sent successfully!`);
    console.log(`   Message ID: ${response}`);

    // Also write to RTDB for record-keeping
    const alertData = {
      severity: severity,
      heartRate: heartRate,
      timestamp: ts,
      confidence: 85,
      baseline: BASELINE_BPM,
      alertType: "direct_fcm",
      deviceId: TEST_DEVICE_ID,
      userId: TEST_USER_ID,
      source: "direct_test",
    };

    await db.ref(`/devices/${TEST_DEVICE_ID}/alerts`).push(alertData);
    console.log(`📝 Alert also saved to RTDB for records`);

    console.log(`\n╔════════════════════════════════════════════════╗`);
    console.log(`║         CHECK YOUR DEVICE NOW!                 ║`);
    console.log(`╚════════════════════════════════════════════════╝`);
    console.log(`\n📱 You should see a ${severity} anxiety alert notification`);
    console.log(`🔊 With custom ${severity} alert sound`);
    console.log(`💚 Title: ${title}`);
    console.log(
      `\n✅ This method bypasses the Cloud Function and sends FCM directly\n`
    );

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Error:", error);
    if (error.code === "messaging/invalid-registration-token") {
      console.error("\n⚠️  FCM TOKEN IS INVALID!");
      console.error("   Solution: Restart your app to get a fresh token");
    }
    process.exit(1);
  }
}

// Get severity from command line
const severity = process.argv[2];

if (!severity) {
  console.log("🎯 Direct Anxiety Alert Sender\n");
  console.log("Usage:");
  console.log("   node send_direct_alert.js mild");
  console.log("   node send_direct_alert.js moderate");
  console.log("   node send_direct_alert.js severe");
  console.log("   node send_direct_alert.js critical\n");
  process.exit(0);
}

sendDirectAnxietyAlert(severity);
