#!/usr/bin/env node

/**
 * 🧪 ANXIETY ALERT NOTIFICATION TESTER
 * 
 * Quick tool to send test notifications with different severity levels
 */

const { execSync } = require('child_process');

console.log("🧪 ANXIETY ALERT NOTIFICATION TESTER");
console.log("=====================================\n");

// Get command line arguments
const args = process.argv.slice(2);
const severity = args[0] || 'mild';
const heartRate = args[1] || getDefaultHeartRate(severity);

console.log(`📊 Testing: ${severity.toUpperCase()} alert with HR: ${heartRate} BPM`);

// Get notification content preview
const notificationPreview = getNotificationPreview(severity, heartRate);
console.log("\n📱 NOTIFICATION PREVIEW:");
console.log("========================");
console.log(`🔔 Title: [TEST] ${notificationPreview.title}`);
console.log(`📝 Message: ${notificationPreview.body}`);
console.log(`🎨 Style: ${notificationPreview.style}`);
console.log(`⚡ Priority: ${notificationPreview.priority}`);

console.log("\n🚀 SENDING TEST NOTIFICATION...");
console.log("================================");

try {
  const curlCommand = `curl -X POST "https://us-central1-anxieease-sensors.cloudfunctions.net/sendTestNotificationV2" -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" -d "{\\"severity\\": \\"${severity}\\", \\"heartRate\\": ${heartRate}}"`;
  
  console.log("📡 Executing:", curlCommand);
  console.log("");
  
  const result = execSync(curlCommand, { encoding: 'utf8' });
  console.log("✅ SUCCESS! Notification sent:");
  console.log(result);
  
} catch (error) {
  console.error("❌ Error sending notification:", error.message);
  console.log("\n💡 Alternative method - Manual curl command:");
  console.log("===========================================");
  console.log(`curl -X POST "https://us-central1-anxieease-sensors.cloudfunctions.net/sendTestNotificationV2" \\`);
  console.log(`  -H "Content-Type: application/json" \\`);
  console.log(`  -d '{"severity": "${severity}", "heartRate": ${heartRate}}'`);
}

console.log("\n👤 WHAT TO DO NEXT:");
console.log("===================");
console.log("1. 📱 Check your phone for the test notification");
console.log("2. 🔔 Make sure notifications are enabled in your AnxieEase app");
console.log("3. 👆 Tap different response options:");
console.log("   • YES - to see anxiety confirmation flow");
console.log("   • NO - to see false positive handling");
console.log("   • NOT NOW - to see reminder scheduling");
console.log("4. 🧠 Observe how the system responds to each choice");

console.log("\n🔄 TEST OTHER SEVERITY LEVELS:");
console.log("===============================");
console.log(`node ${__filename.split('/').pop()} mild 78     # 🟢 Mild alert`);
console.log(`node ${__filename.split('/').pop()} moderate 88 # 🟡 Moderate alert`);
console.log(`node ${__filename.split('/').pop()} severe 98   # 🟠 Severe alert`);
console.log(`node ${__filename.split('/').pop()} critical 115 # 🔴 Critical alert`);

function getDefaultHeartRate(severity) {
  const defaults = {
    'mild': 78,
    'moderate': 88, 
    'severe': 98,
    'critical': 115
  };
  return defaults[severity] || 75;
}

function getNotificationPreview(severity, heartRate) {
  const baseline = 65;
  const increase = Math.round((heartRate - baseline) / baseline * 100);
  
  const previews = {
    'mild': {
      title: '🟢 Mild Anxiety Alert',
      body: `Slight elevation detected. HR: ${heartRate} BPM (${increase}% above baseline). We noticed some changes. Are you feeling anxious right now?`,
      style: 'Green notification with gentle tone',
      priority: 'Normal'
    },
    'moderate': {
      title: '🟡 Moderate Anxiety Alert', 
      body: `Noticeable changes detected. HR: ${heartRate} BPM (${increase}% above baseline). Your readings suggest possible anxiety. How are you feeling?`,
      style: 'Yellow notification with concern tone',
      priority: 'High'
    },
    'severe': {
      title: '🟠 Severe Anxiety Alert',
      body: `Significant elevation detected. HR: ${heartRate} BPM (${increase}% above baseline). URGENT: High anxiety detected. Please confirm your status.`,
      style: 'Orange notification with urgent tone', 
      priority: 'High'
    },
    'critical': {
      title: '🔴 CRITICAL Anxiety Alert',
      body: `URGENT: Severe symptoms detected. HR: ${heartRate} BPM (${increase}% above baseline). EMERGENCY: Critical anxiety level. Immediate assistance recommended.`,
      style: 'Red notification with emergency tone',
      priority: 'Max'
    }
  };
  
  return previews[severity] || previews['mild'];
}

console.log("\n🎯 Happy testing! See how your anxiety alert system works! 🎯");