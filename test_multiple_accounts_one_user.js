/**
 * 🔐 SINGLE USER, MULTIPLE ACCOUNTS TEST
 * 
 * This demonstrates how the system handles one user with multiple accounts:
 * - Account 1: Personal (assigned to AnxieEase001)
 * - Account 2: Work (not assigned)
 * 
 * Only the assigned account should receive anxiety notifications
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

// Same user, different accounts
const PERSONAL_ACCOUNT = "5efad7d4-3dcd-4333-ba4b-41f86";  // Personal account (assigned)
const WORK_ACCOUNT = "5efad7d4-work-account-separate";     // Work account (not assigned)
const FCM_TOKEN = "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0"; // Same FCM token (same device)

const DEVICE_ID = "AnxieEase001";

async function testMultipleAccountsOneUser() {
  console.log("\n🔐 SINGLE USER, MULTIPLE ACCOUNTS TEST");
  console.log("=====================================");
  console.log("Testing: One user with Personal + Work accounts");
  console.log("Device assigned to Personal account only");
  
  try {
    // Step 1: Set up device assignment to Personal Account ONLY
    console.log("\n📟 Step 1: Device assignment setup...");
    const sessionId = `session_${Date.now()}`;
    
    await db.ref(`/devices/${DEVICE_ID}/assignment`).set({
      assignedUser: PERSONAL_ACCOUNT,  // Only Personal account assigned
      activeSessionId: sessionId,
      deviceId: DEVICE_ID,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
      assignedBy: "admin_decision"
    });
    
    console.log("✅ Device AnxieEase001 assigned to PERSONAL account only");
    console.log(`   Personal: ${PERSONAL_ACCOUNT} (ASSIGNED)`);
    console.log(`   Work: ${WORK_ACCOUNT} (NOT ASSIGNED)`);
    
    // Step 2: Set up both accounts with same FCM token (same device)
    console.log("\n👤 Step 2: Setting up both accounts...");
    
    // Personal Account (assigned - should get notifications)
    await db.ref(`/users/${PERSONAL_ACCOUNT}/sessions/${sessionId}/metadata`).set({
      deviceId: DEVICE_ID,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      accountType: "personal"
    });
    
    await db.ref(`/users/${PERSONAL_ACCOUNT}/baseline`).set({
      heartRate: 70,
      timestamp: Date.now(),
      accountType: "personal"
    });
    
    await db.ref(`/users/${PERSONAL_ACCOUNT}/fcmToken`).set(FCM_TOKEN);
    
    // Work Account (not assigned - should NOT get notifications)
    await db.ref(`/users/${WORK_ACCOUNT}/baseline`).set({
      heartRate: 75,  // Different baseline (work stress)
      timestamp: Date.now(),
      accountType: "work"
    });
    
    // Same FCM token (same device/phone)
    await db.ref(`/users/${WORK_ACCOUNT}/fcmToken`).set(FCM_TOKEN);
    
    console.log("✅ Personal Account: Baseline 70 BPM, FCM token, DEVICE ASSIGNED");
    console.log("✅ Work Account: Baseline 75 BPM, FCM token, NO DEVICE ASSIGNMENT");
    
    // Step 3: Clear previous alerts
    await db.ref(`/users/${PERSONAL_ACCOUNT}/alerts`).remove();
    await db.ref(`/users/${WORK_ACCOUNT}/alerts`).remove();
    
    // Step 4: Simulate anxiety from the wearable device
    console.log("\n🚨 Step 4: Simulating anxiety event...");
    console.log("Wearable device AnxieEase001 detects sustained anxiety");
    console.log("Should ONLY notify Personal account (device owner)");
    
    for (let i = 0; i < 15; i++) {
      const heartRate = 86 + Math.random() * 8; // 86-94 BPM
      const timestamp = Date.now();
      
      const deviceData = {
        heartRate: Math.round(heartRate * 10) / 10,
        spo2: 98,
        bodyTemp: 36.5,
        battPerc: 90 - i,
        worn: 1,
        timestamp: timestamp,
        deviceId: DEVICE_ID,
        sessionId: sessionId
      };
      
      // Write to device (triggers anxiety detection for assigned user only)
      await db.ref(`/devices/${DEVICE_ID}/current`).set(deviceData);
      
      // Also add to Personal account session data
      const userDataRef = db.ref(`/users/${PERSONAL_ACCOUNT}/sessions/${sessionId}/data`).push();
      await userDataRef.set({
        heartRate: deviceData.heartRate,
        timestamp: timestamp,
        deviceId: DEVICE_ID,
        source: "multiple_accounts_test"
      });
      
      const elapsed = (i + 1) * 2.5;
      console.log(`   📈 ${elapsed}s: ${deviceData.heartRate} BPM → Personal account anxiety check`);
      
      if (i < 14) {
        await sleep(2500);
      }
    }
    
    console.log("\n✅ Anxiety simulation complete (37.5 seconds)");
    
    // Step 5: Wait and check results
    console.log("\n⏳ Step 5: Waiting for processing...");
    await sleep(10000);
    
    console.log("\n🔔 Step 6: Checking results for both accounts...");
    
    // Check Personal Account
    const personalAlertsSnapshot = await db.ref(`/users/${PERSONAL_ACCOUNT}/alerts`).once('value');
    const personalAlerts = personalAlertsSnapshot.val();
    
    // Check Work Account
    const workAlertsSnapshot = await db.ref(`/users/${WORK_ACCOUNT}/alerts`).once('value');
    const workAlerts = workAlertsSnapshot.val();
    
    console.log("\n📊 MULTIPLE ACCOUNTS TEST RESULTS:");
    console.log("==================================");
    
    if (personalAlerts) {
      const count = Object.keys(personalAlerts).length;
      console.log(`✅ Personal Account: ${count} anxiety alerts (CORRECT - device assigned)`);
    } else {
      console.log("❌ Personal Account: No alerts (should have received some)");
    }
    
    if (workAlerts) {
      const count = Object.keys(workAlerts).length;
      console.log(`❌ Work Account: ${count} alerts (WRONG - not assigned to device)`);
    } else {
      console.log("✅ Work Account: No alerts (CORRECT - not assigned to device)");
    }
    
    console.log("\n🎯 ADMIN CONTROL BENEFITS:");
    console.log("=========================");
    console.log("✅ Admin decides which account gets device access");
    console.log("✅ Only assigned account receives anxiety notifications");
    console.log("✅ Other accounts on same device remain unaffected");
    console.log("✅ User can switch accounts but only assigned one gets alerts");
    console.log("✅ Perfect for Personal vs Work account separation");
    
    console.log("\n📱 REAL-WORLD SCENARIOS:");
    console.log("========================");
    console.log("Scenario 1: Personal + Work accounts");
    console.log("  → Admin assigns device to Personal account");
    console.log("  → Work account doesn't get health notifications");
    
    console.log("\nScenario 2: Family sharing device");
    console.log("  → Admin assigns device to primary user");
    console.log("  → Other family accounts don't get notifications");
    
    console.log("\nScenario 3: Doctor + Patient accounts");
    console.log("  → Admin assigns device to Patient account");
    console.log("  → Doctor account gets data access but no notifications");
    
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

testMultipleAccountsOneUser();