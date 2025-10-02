#!/usr/bin/env node

/**
 * 🧪 ANXIETY NOTIFICATION TESTER
 * 
 * Node.js script to test anxiety notifications via Firebase Cloud Functions
 * This script will trigger notifications that will appear in the app and Firebase
 * 
 * Usage:
 *   node test_anxiety_notifications.js
 *   node test_anxiety_notifications.js mild
 *   node test_anxiety_notifications.js severe
 */

const https = require('https');

// Configuration
const FIREBASE_PROJECT_ID = 'anxieease-sensors'; // Update if different
const CLOUD_FUNCTION_REGION = 'us-central1'; // Update if different
const FUNCTION_NAME = 'testNotificationHTTP'; // Use the HTTP endpoint instead

// Test user ID (you can get this from your Supabase auth table)
const TEST_USER_ID = '5afad7d4-3dcd-4353-badb-4f155303419a'; // Update with a real user ID

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Test configurations for different severity levels
const testConfigurations = {
  mild: {
    severity: 'mild',
    heartRate: 85,
    title: '🟢 Gentle Check-in',
    body: 'We noticed some changes in your readings. Are you experiencing any anxiety right now?',
    description: 'Mild anxiety detection with gentle notification'
  },
  moderate: {
    severity: 'moderate', 
    heartRate: 95,
    title: '🟠 Checking In With You',
    body: 'Your heart rate has been elevated. How are you feeling right now?',
    description: 'Moderate anxiety with confirmation request'
  },
  severe: {
    severity: 'severe',
    heartRate: 115,
    title: '🔴 Are You Okay?', 
    body: 'We detected concerning changes in your vital signs. Are you experiencing anxiety or distress?',
    description: 'Severe anxiety requiring immediate attention'
  },
  critical: {
    severity: 'critical',
    heartRate: 135,
    title: '🚨 Urgent Check-in',
    body: 'Critical anxiety levels detected. Please confirm you are safe or seek immediate help.',
    description: 'Critical emergency-level anxiety detection'
  }
};

/**
 * Send test notification via Firebase Cloud Function
 */
async function sendTestNotification(config) {
  const url = `https://${CLOUD_FUNCTION_REGION}-${FIREBASE_PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;
  
  const postData = JSON.stringify({
    severity: config.severity,
    heartRate: config.heartRate,
    title: config.title,
    body: config.body,
    userId: TEST_USER_ID
  });

  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    console.log(`${colors.blue}📡 Sending ${config.severity} notification...${colors.reset}`);
    console.log(`${colors.cyan}   URL: ${url}${colors.reset}`);
    console.log(`${colors.cyan}   Heart Rate: ${config.heartRate} BPM${colors.reset}`);
    console.log(`${colors.cyan}   Title: ${config.title}${colors.reset}`);
    console.log(`${colors.cyan}   Body: ${config.body}${colors.reset}\n`);

    const req = https.request(url, options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          if (res.statusCode === 200 && response.success) {
            console.log(`${colors.green}✅ ${config.severity.toUpperCase()} notification sent successfully!${colors.reset}`);
            console.log(`${colors.green}   Message ID: ${response.messageId}${colors.reset}`);
            resolve(response);
          } else {
            console.log(`${colors.red}❌ Failed to send ${config.severity} notification${colors.reset}`);
            console.log(`${colors.red}   Status: ${res.statusCode}${colors.reset}`);
            console.log(`${colors.red}   Response: ${data}${colors.reset}`);
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        } catch (e) {
          console.log(`${colors.red}❌ Invalid response format${colors.reset}`);
          console.log(`${colors.red}   Raw response: ${data}${colors.reset}`);
          reject(e);
        }
      });
    });

    req.on('error', (error) => {
      console.log(`${colors.red}❌ Request failed: ${error.message}${colors.reset}`);
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Test a specific severity level
 */
async function testSpecificSeverity(severityLevel) {
  const config = testConfigurations[severityLevel];
  if (!config) {
    console.log(`${colors.red}❌ Unknown severity level: ${severityLevel}${colors.reset}`);
    console.log(`${colors.yellow}Available levels: ${Object.keys(testConfigurations).join(', ')}${colors.reset}`);
    return;
  }

  console.log(`${colors.bright}🧪 Testing ${severityLevel.toUpperCase()} anxiety notification${colors.reset}`);
  console.log(`${colors.yellow}📝 ${config.description}${colors.reset}\n`);

  try {
    await sendTestNotification(config);
    console.log(`${colors.green}\n🎉 Test completed! Check your device for the notification.${colors.reset}`);
    console.log(`${colors.cyan}📱 The notification should appear in:${colors.reset}`);
    console.log(`${colors.cyan}   - Your device's notification panel${colors.reset}`);
    console.log(`${colors.cyan}   - The AnxieEase app's notifications screen${colors.reset}`);
    console.log(`${colors.cyan}   - Firebase Realtime Database (anxiety_alerts)${colors.reset}\n`);
  } catch (error) {
    console.log(`${colors.red}💥 Test failed: ${error.message}${colors.reset}\n`);
  }
}

/**
 * Test all severity levels with delays
 */
async function testAllSeverityLevels() {
  console.log(`${colors.bright}🚀 Testing ALL anxiety notification levels${colors.reset}\n`);
  
  const severities = Object.keys(testConfigurations);
  
  for (let i = 0; i < severities.length; i++) {
    const severity = severities[i];
    const config = testConfigurations[severity];
    
    console.log(`${colors.magenta}━━━ Test ${i + 1}/${severities.length}: ${severity.toUpperCase()} ━━━${colors.reset}`);
    console.log(`${colors.yellow}📝 ${config.description}${colors.reset}\n`);
    
    try {
      await sendTestNotification(config);
      
      // Wait 3 seconds between notifications (except for the last one)
      if (i < severities.length - 1) {
        console.log(`${colors.yellow}⏳ Waiting 3 seconds before next test...\n${colors.reset}`);
        await new Promise(resolve => setTimeout(resolve, 3000));
      }
    } catch (error) {
      console.log(`${colors.red}❌ Failed: ${error.message}${colors.reset}\n`);
    }
  }
  
  console.log(`${colors.green}🎉 All tests completed!${colors.reset}`);
  console.log(`${colors.cyan}📱 Check your device and the AnxieEase app for all notifications.${colors.reset}\n`);
}

/**
 * Show usage instructions
 */
function showUsage() {
  console.log(`${colors.bright}🧪 ANXIETY NOTIFICATION TESTER${colors.reset}\n`);
  console.log(`${colors.cyan}Usage:${colors.reset}`);
  console.log(`  node test_anxiety_notifications.js              # Test all severity levels`);
  console.log(`  node test_anxiety_notifications.js <severity>   # Test specific severity\n`);
  console.log(`${colors.cyan}Available severity levels:${colors.reset}`);
  
  Object.entries(testConfigurations).forEach(([key, config]) => {
    const emoji = key === 'mild' ? '🟢' : key === 'moderate' ? '🟠' : key === 'severe' ? '🔴' : '🚨';
    console.log(`  ${emoji} ${key.padEnd(10)} - ${config.description}`);
  });
  
  console.log(`\n${colors.cyan}Examples:${colors.reset}`);
  console.log(`  node test_anxiety_notifications.js mild`);
  console.log(`  node test_anxiety_notifications.js severe\n`);
  
  console.log(`${colors.yellow}📋 Prerequisites:${colors.reset}`);
  console.log(`  1. AnxieEase app installed and logged in on your device`);
  console.log(`  2. Firebase Cloud Functions deployed`);
  console.log(`  3. Device connected to internet`);
  console.log(`  4. Notification permissions granted\n`);
  
  console.log(`${colors.yellow}🔧 Configuration:${colors.reset}`);
  console.log(`  Update TEST_USER_ID with your actual user ID from Supabase`);
  console.log(`  Update FIREBASE_PROJECT_ID if different from 'anxieease-sensors'\n`);
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    // No arguments - test all severity levels
    await testAllSeverityLevels();
  } else if (args.length === 1) {
    const severity = args[0].toLowerCase();
    
    if (severity === 'help' || severity === '--help' || severity === '-h') {
      showUsage();
      return;
    }
    
    // Test specific severity
    await testSpecificSeverity(severity);
  } else {
    console.log(`${colors.red}❌ Too many arguments${colors.reset}\n`);
    showUsage();
  }
}

// Handle unhandled errors
process.on('unhandledRejection', (error) => {
  console.log(`${colors.red}💥 Unhandled error: ${error.message}${colors.reset}`);
  process.exit(1);
});

// Run the script
if (require.main === module) {
  main().catch(error => {
    console.log(`${colors.red}💥 Script failed: ${error.message}${colors.reset}`);
    process.exit(1);
  });
}