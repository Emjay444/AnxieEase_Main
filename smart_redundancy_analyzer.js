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
 * SMART REDUNDANCY ANALYZER
 * 
 * Analyzes the two history formats to understand duplication:
 * 1. Device native format: 2025_10_05_20_12_00 (KEEP - wearable writes this)
 * 2. Timestamp duplicates: 1759666431694 (REMOVE - Firebase function creates this)
 */

async function analyzeHistoryFormats() {
  console.log("🔍 ANALYZING HISTORY FORMAT DUPLICATION");
  console.log("=" * 50);

  try {
    // Check device history
    const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
    const deviceHistorySnapshot = await deviceHistoryRef.once("value");
    
    let deviceNativeEntries = 0;
    let timestampDuplicates = 0;
    let deviceNativeKeys = [];
    let timestampKeys = [];
    let sampleDeviceNative = null;
    let sampleTimestamp = null;

    if (deviceHistorySnapshot.exists()) {
      const historyData = deviceHistorySnapshot.val();
      
      Object.keys(historyData).forEach(key => {
        // Device native format: YYYY_MM_DD_HH_MM_SS
        if (key.match(/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/)) {
          deviceNativeEntries++;
          deviceNativeKeys.push(key);
          if (!sampleDeviceNative) sampleDeviceNative = { key, data: historyData[key] };
        }
        // Timestamp format: 13-digit number
        else if (key.match(/^\d{13}$/)) {
          timestampDuplicates++;
          timestampKeys.push(key);
          if (!sampleTimestamp) sampleTimestamp = { key, data: historyData[key] };
        }
      });
    }

    console.log(`📊 DEVICE HISTORY ANALYSIS:`);
    console.log(`   🟢 Device native entries (YYYY_MM_DD_HH_MM_SS): ${deviceNativeEntries}`);
    console.log(`   🔴 Timestamp duplicates (13-digit numbers): ${timestampDuplicates}`);
    console.log(`   📈 Total entries: ${deviceNativeEntries + timestampDuplicates}`);
    console.log(`   ⚠️  Redundancy factor: ${timestampDuplicates > 0 ? '2x storage used' : 'No redundancy'}`);

    if (sampleDeviceNative) {
      console.log(`\n📋 SAMPLE DEVICE NATIVE ENTRY:`);
      console.log(`   Key: ${sampleDeviceNative.key}`);
      console.log(`   Fields: ${Object.keys(sampleDeviceNative.data).join(', ')}`);
    }

    if (sampleTimestamp) {
      console.log(`\n📋 SAMPLE TIMESTAMP DUPLICATE:`);
      console.log(`   Key: ${sampleTimestamp.key}`);
      console.log(`   Fields: ${Object.keys(sampleTimestamp.data).join(', ')}`);
      console.log(`   Extra fields: ${sampleTimestamp.data.copiedAt ? 'copiedAt, ' : ''}${sampleTimestamp.data.deviceId ? 'deviceId, ' : ''}${sampleTimestamp.data.sessionId ? 'sessionId' : ''}`);
    }

    // Check user session history too
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    let userSessionHistoryCount = 0;
    let userSessionsWithHistory = 0;

    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();
      
      Object.keys(users).forEach(userId => {
        if (users[userId].sessions) {
          Object.keys(users[userId].sessions).forEach(sessionId => {
            const session = users[userId].sessions[sessionId];
            if (session.history) {
              userSessionsWithHistory++;
              userSessionHistoryCount += Object.keys(session.history).length;
            }
          });
        }
      });
    }

    console.log(`\n📊 USER SESSION HISTORY ANALYSIS:`);
    console.log(`   👥 Sessions with history: ${userSessionsWithHistory}`);
    console.log(`   📈 Total user history entries: ${userSessionHistoryCount}`);
    console.log(`   🎯 Purpose: Individual user tracking (KEEP for anxiety detection)`);

    // Calculate redundancy impact
    const totalDeviceEntries = deviceNativeEntries + timestampDuplicates;
    const totalSystemEntries = totalDeviceEntries + userSessionHistoryCount;
    const redundancyRatio = totalSystemEntries > 0 ? (timestampDuplicates / totalSystemEntries * 100).toFixed(1) : 0;

    console.log(`\n💾 STORAGE REDUNDANCY ANALYSIS:`);
    console.log(`   📊 Total entries across system: ${totalSystemEntries.toLocaleString()}`);
    console.log(`   🔴 Unnecessary duplicates: ${timestampDuplicates.toLocaleString()} (${redundancyRatio}% of total)`);
    console.log(`   🎯 Necessary entries:`);
    console.log(`      - Device native (wearable): ${deviceNativeEntries.toLocaleString()}`);
    console.log(`      - User sessions (tracking): ${userSessionHistoryCount.toLocaleString()}`);
    
    if (timestampDuplicates > 0) {
      const estimatedSavings = Math.round(timestampDuplicates * 0.5); // KB
      console.log(`   💰 Storage savings potential: ~${estimatedSavings} KB`);
      console.log(`   📉 Redundancy elimination: Remove ${timestampDuplicates} timestamp duplicates`);
    } else {
      console.log(`   ✅ No timestamp duplicates found - device history already clean!`);
    }

    return {
      deviceNativeEntries,
      timestampDuplicates,
      userSessionHistoryCount,
      redundancyRatio: parseFloat(redundancyRatio),
      needsCleanup: timestampDuplicates > 0,
      deviceNativeKeys: deviceNativeKeys.slice(0, 5), // Sample keys
      timestampKeys: timestampKeys.slice(0, 5), // Sample keys
    };

  } catch (error) {
    console.error("❌ Error analyzing history formats:", error);
    throw error;
  }
}

/**
 * Check what's creating the timestamp duplicates
 */
async function identifyDuplicationSource() {
  console.log("\n🔍 IDENTIFYING DUPLICATION SOURCE");
  console.log("=" * 40);

  try {
    // Check if Firebase functions are creating duplicates
    const functionsRef = db.ref("/system/functions");
    const functionsSnapshot = await functionsRef.once("value");

    console.log("🔧 FIREBASE FUNCTIONS ANALYSIS:");
    if (functionsSnapshot.exists()) {
      const functions = functionsSnapshot.val();
      console.log("   📋 Active functions detected in system logs");
      
      // Look for copy operations in recent errors/logs
      const errorsRef = db.ref("/system/errors");
      const errorsSnapshot = await errorsRef.limitToLast(5).once("value");
      
      if (errorsSnapshot.exists()) {
        const errors = errorsSnapshot.val();
        let copyRelatedErrors = 0;
        
        Object.values(errors).forEach(error => {
          if (error.type?.includes('copy') || error.error?.includes('copy')) {
            copyRelatedErrors++;
          }
        });
        
        console.log(`   ⚠️  Copy-related errors in last 5: ${copyRelatedErrors}`);
      }
    } else {
      console.log("   ℹ️  No function logs found in /system/functions");
    }

    // Check current Firebase Cloud Functions deployment
    console.log("\n📋 SUSPECTED DUPLICATION SOURCES:");
    console.log("   1. 🔧 copyDeviceDataToUserSession (creates timestamp entries)");
    console.log("   2. 🔧 autoCreateDeviceHistory (may create duplicates)");
    console.log("   3. 📱 Wearable device writes native format (correct behavior)");
    console.log("   4. 👤 User session copying (necessary for tracking)");

    console.log("\n🎯 SOLUTION APPROACH:");
    console.log("   ✅ PRESERVE: Device native format (2025_MM_DD_HH_MM_SS)");
    console.log("   ✅ PRESERVE: User session history (individual tracking)");  
    console.log("   🗑️  REMOVE: Timestamp duplicates in device history only");
    console.log("   🛠️  UPDATE: Firebase functions to avoid creating duplicates");

  } catch (error) {
    console.error("❌ Error identifying duplication source:", error);
    throw error;
  }
}

/**
 * Main analysis function
 */
async function runSmartAnalysis() {
  console.log("🧠 SMART REDUNDANCY ANALYSIS");
  console.log("🎯 Preserving device native format while eliminating duplicates");
  console.log("");

  try {
    const analysisResults = await analyzeHistoryFormats();
    await identifyDuplicationSource();

    console.log("\n" + "=" * 60);
    console.log("📊 ANALYSIS COMPLETE - SMART CLEANUP STRATEGY");
    console.log("=" * 60);

    if (analysisResults.needsCleanup) {
      console.log("🎯 RECOMMENDED ACTIONS:");
      console.log("   1. 🗑️  Remove timestamp duplicates from device history");
      console.log("   2. 🔧 Update Firebase functions to prevent future duplicates");
      console.log("   3. ✅ Keep device native format (wearable needs this)");
      console.log("   4. ✅ Keep user session history (anxiety detection needs this)");
      console.log(`   5. 💾 Expected storage savings: ~${Math.round(analysisResults.timestampDuplicates * 0.5)} KB`);
    } else {
      console.log("🎉 NO CLEANUP NEEDED!");
      console.log("   ✅ Device history is already optimized");
      console.log("   ✅ No timestamp duplicates found");
      console.log("   ✅ System is using storage efficiently");
    }

    return analysisResults;

  } catch (error) {
    console.error("❌ Smart analysis failed:", error);
    throw error;
  }
}

// Run analysis if this script is executed directly
if (require.main === module) {
  runSmartAnalysis()
    .then((results) => {
      console.log("\n✅ Analysis completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Analysis failed:", error);
      process.exit(1);
    });
}

module.exports = {
  runSmartAnalysis,
  analyzeHistoryFormats,
  identifyDuplicationSource
};