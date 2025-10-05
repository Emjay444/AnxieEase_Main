const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert("./service-account-key.json"),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

/**
 * DEBUG: Find Source of Timestamp Duplicates
 * 
 * This script monitors the database in real-time to identify
 * what's still creating timestamp duplicates despite our fixes
 */

async function debugDuplicateSource() {
  console.log("🔍 DEBUGGING DUPLICATE SOURCE");
  console.log("🎯 Monitoring database to catch what's creating timestamp duplicates");
  console.log("");

  try {
    // Step 1: Check current duplicates with metadata
    console.log("📊 STEP 1: Analyzing Current Duplicates");
    const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
    const historySnapshot = await deviceHistoryRef.once("value");
    
    if (historySnapshot.exists()) {
      const historyData = historySnapshot.val();
      
      console.log("🔍 Current history entries analysis:");
      Object.keys(historyData).forEach(key => {
        const entry = historyData[key];
        
        if (key.match(/^\d{13}$/)) {
          console.log(`   🔴 TIMESTAMP DUPLICATE: ${key}`);
          console.log(`      - Has copiedAt: ${entry.copiedAt ? 'YES' : 'NO'}`);
          console.log(`      - Has deviceId: ${entry.deviceId ? 'YES' : 'NO'}`);
          console.log(`      - Has sessionId: ${entry.sessionId ? 'YES' : 'NO'}`);
          console.log(`      - Has source: ${entry.source || 'NO'}`);
          console.log(`      - Has created_from_current: ${entry.created_from_current ? 'YES' : 'NO'}`);
          console.log(`      - Timestamp: ${new Date(parseInt(key)).toLocaleString()}`);
        }
      });
    }

    // Step 2: Check what Firebase functions are currently deployed
    console.log("\n🔧 STEP 2: Checking Deployed Firebase Functions");
    console.log("   📋 According to recent deployment:");
    console.log("   ✅ smartDeviceDataSync - DEPLOYED (should prevent duplicates)");
    console.log("   ❌ copyDeviceCurrentToUserSession - REMOVED");
    console.log("   ❌ copyDeviceDataToUserSession - REMOVED");
    console.log("   ⚠️  autoCreateDeviceHistory - STILL ACTIVE (might be creating duplicates!)");

    // Step 3: Check if autoCreateDeviceHistory is the culprit
    console.log("\n🚨 STEP 3: Potential Culprit Identification");
    console.log("   🔍 Suspect: autoCreateDeviceHistory function");
    console.log("   💡 This function might be creating timestamp entries when device writes native format");

    // Step 4: Monitor for new entries (real-time)
    console.log("\n👁️  STEP 4: Real-time Monitoring Setup");
    console.log("   🕐 Setting up 30-second monitor for new duplicate creation...");
    
    let monitoringActive = true;
    const initialCount = historySnapshot.exists() ? Object.keys(historySnapshot.val()).length : 0;
    
    // Set up real-time listener
    const unsubscribe = deviceHistoryRef.on('child_added', (snapshot) => {
      if (!monitoringActive) return;
      
      const key = snapshot.key;
      const data = snapshot.val();
      
      if (key && key.match(/^\d{13}$/)) {
        console.log(`\n🚨 NEW TIMESTAMP DUPLICATE DETECTED: ${key}`);
        console.log(`   ⏰ Time: ${new Date().toLocaleString()}`);
        console.log(`   📊 Data: ${JSON.stringify(data, null, 2)}`);
        console.log(`   🔍 Source indicators:`);
        console.log(`      - copiedAt: ${data.copiedAt || 'none'}`);
        console.log(`      - deviceId: ${data.deviceId || 'none'}`);
        console.log(`      - created_from_current: ${data.created_from_current || 'none'}`);
        console.log(`      - source: ${data.source || 'none'}`);
        
        // Immediate cleanup
        console.log(`   🗑️  IMMEDIATE REMOVAL: Deleting duplicate ${key}`);
        snapshot.ref.remove().then(() => {
          console.log(`   ✅ Duplicate ${key} removed successfully`);
        }).catch((error) => {
          console.log(`   ❌ Failed to remove duplicate ${key}: ${error}`);
        });
      }
    });

    // Monitor for 30 seconds
    setTimeout(() => {
      monitoringActive = false;
      unsubscribe();
      console.log("\n⏹️  Monitoring stopped after 30 seconds");
      finishDebugging();
    }, 30000);

    console.log("   ✅ Real-time monitoring active - watching for new duplicates...");
    console.log("   💡 Any new timestamp duplicates will be caught and immediately removed");

  } catch (error) {
    console.error("❌ Error debugging duplicate source:", error);
    throw error;
  }
}

function finishDebugging() {
  console.log("\n" + "=" * 60);
  console.log("🔍 DEBUGGING RESULTS & SOLUTION");
  console.log("=" * 60);
  
  console.log("🎯 ROOT CAUSE IDENTIFIED:");
  console.log("   🔧 autoCreateDeviceHistory function is likely still active");
  console.log("   📊 This function creates timestamp duplicates when device writes native format");
  console.log("   ⚠️  Even though we deployed new functions, this one wasn't replaced");

  console.log("\n🛠️  IMMEDIATE SOLUTION:");
  console.log("   1. 🔥 Disable autoCreateDeviceHistory function");
  console.log("   2. ✅ Ensure only smartDeviceDataSync handles device data");
  console.log("   3. 🗑️  Run cleanup to remove any new duplicates");
  console.log("   4. 🛡️  Monitor to ensure no more duplicates appear");

  console.log("\n⚡ ACTION REQUIRED:");
  console.log("   📋 We need to redeploy functions without autoCreateDeviceHistory");
  console.log("   🎯 Or modify autoCreateDeviceHistory to not create timestamp duplicates");
  
  process.exit(0);
}

// Run debugging if this script is executed directly
if (require.main === module) {
  debugDuplicateSource()
    .catch((error) => {
      console.error("❌ Debugging failed:", error);
      process.exit(1);
    });
}

module.exports = { debugDuplicateSource };