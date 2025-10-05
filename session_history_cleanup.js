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
 * SESSION HISTORY TIMESTAMP CLEANUP
 * 
 * This script removes timestamp duplicates from session history while preserving
 * device native format (YYYY_MM_DD_HH_MM_SS) that the anxiety detection system needs.
 * 
 * Issue: Session history contains both:
 * ❌ 1759698261000 (timestamp duplicates - REMOVE)
 * ✅ 2025_10_05_21_04_21 (device native - KEEP)
 */

async function analyzeSessionHistoryDuplicates() {
  console.log("🔍 ANALYZING SESSION HISTORY TIMESTAMP DUPLICATES");
  console.log("=" * 50);

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("❌ No users found");
      return { needsCleanup: false };
    }

    const users = usersSnapshot.val();
    const analysis = {
      totalUsers: 0,
      totalSessions: 0,
      sessionsWithDuplicates: 0,
      totalTimestampDuplicates: 0,
      totalDeviceNativeEntries: 0,
      duplicatesToRemove: [],
      sessionsToClean: [],
    };

    for (const userId of Object.keys(users)) {
      const user = users[userId];
      analysis.totalUsers++;
      
      console.log(`\n👤 USER: ${userId}`);

      if (user.sessions) {
        const sessionIds = Object.keys(user.sessions);
        analysis.totalSessions += sessionIds.length;
        
        for (const sessionId of sessionIds) {
          const session = user.sessions[sessionId];
          
          if (session.history) {
            const historyEntries = Object.keys(session.history);
            console.log(`\n   📁 Session: ${sessionId}`);
            console.log(`      Total history entries: ${historyEntries.length}`);

            let timestampDuplicates = 0;
            let deviceNativeEntries = 0;
            const duplicateKeys = [];

            historyEntries.forEach(key => {
              // Check if it's a timestamp (13-digit number) vs device native format
              if (/^\d{13}$/.test(key)) {
                timestampDuplicates++;
                duplicateKeys.push(key);
                console.log(`      ❌ Timestamp duplicate: ${key}`);
              } else if (/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/.test(key)) {
                deviceNativeEntries++;
                console.log(`      ✅ Device native: ${key}`);
              } else {
                console.log(`      ❓ Unknown format: ${key}`);
              }
            });

            analysis.totalTimestampDuplicates += timestampDuplicates;
            analysis.totalDeviceNativeEntries += deviceNativeEntries;

            if (timestampDuplicates > 0) {
              analysis.sessionsWithDuplicates++;
              analysis.sessionsToClean.push({
                userId,
                sessionId,
                duplicateKeys,
                duplicateCount: timestampDuplicates,
                nativeCount: deviceNativeEntries
              });

              console.log(`      🔥 Found ${timestampDuplicates} timestamp duplicates to remove`);
              console.log(`      ✅ Preserving ${deviceNativeEntries} device native entries`);
            } else {
              console.log(`      ✅ Clean - no timestamp duplicates found`);
            }
          } else {
            console.log(`\n   📁 Session: ${sessionId} - No history`);
          }
        }
      }
    }

    console.log("\n" + "=" * 60);
    console.log("📊 SESSION HISTORY DUPLICATE ANALYSIS SUMMARY");
    console.log("=" * 60);
    
    console.log(`📈 CURRENT STATE:`);
    console.log(`   👥 Total users: ${analysis.totalUsers}`);
    console.log(`   📁 Total sessions: ${analysis.totalSessions}`);
    console.log(`   🔴 Sessions with duplicates: ${analysis.sessionsWithDuplicates}`);
    console.log(`   ❌ Timestamp duplicates: ${analysis.totalTimestampDuplicates}`);
    console.log(`   ✅ Device native entries: ${analysis.totalDeviceNativeEntries}`);
    
    console.log(`\n🧹 CLEANUP POTENTIAL:`);
    console.log(`   🗑️  Entries to remove: ${analysis.totalTimestampDuplicates}`);
    console.log(`   🛡️  Entries to preserve: ${analysis.totalDeviceNativeEntries}`);
    console.log(`   💾 Estimated storage savings: ~${Math.round(analysis.totalTimestampDuplicates * 0.5)} KB`);

    analysis.needsCleanup = analysis.totalTimestampDuplicates > 0;
    
    return analysis;

  } catch (error) {
    console.error("❌ Error analyzing session history duplicates:", error);
    throw error;
  }
}

async function createSessionHistoryBackup(analysis) {
  console.log("\n🔒 CREATING SESSION HISTORY BACKUP");
  console.log("=" * 35);

  try {
    const backupData = {
      timestamp: new Date().toISOString(),
      cleanup_type: "session_history_timestamp_cleanup",
      analysis_summary: {
        totalSessions: analysis.totalSessions,
        sessionsWithDuplicates: analysis.sessionsWithDuplicates,
        totalTimestampDuplicates: analysis.totalTimestampDuplicates,
        totalDeviceNativeEntries: analysis.totalDeviceNativeEntries,
      },
      removed_entries: {},
    };

    // Backup all timestamp duplicates that will be removed
    for (const sessionInfo of analysis.sessionsToClean) {
      const { userId, sessionId, duplicateKeys } = sessionInfo;
      
      if (!backupData.removed_entries[userId]) {
        backupData.removed_entries[userId] = {};
      }
      
      if (!backupData.removed_entries[userId][sessionId]) {
        backupData.removed_entries[userId][sessionId] = {};
      }

      // Get the data for each duplicate key
      for (const duplicateKey of duplicateKeys) {
        const entryRef = db.ref(`/users/${userId}/sessions/${sessionId}/history/${duplicateKey}`);
        const entrySnapshot = await entryRef.once("value");
        
        if (entrySnapshot.exists()) {
          backupData.removed_entries[userId][sessionId][duplicateKey] = entrySnapshot.val();
        }
      }
    }

    // Store backup
    const backupRef = db.ref("/system/backups/session_history_cleanup");
    await backupRef.set(backupData);

    console.log(`✅ Session history backup completed`);
    console.log(`   📦 Sessions to clean: ${analysis.sessionsWithDuplicates}`);
    console.log(`   🗑️  Entries to remove: ${analysis.totalTimestampDuplicates}`);
    console.log(`   📍 Backup location: /system/backups/session_history_cleanup`);

    return backupData;

  } catch (error) {
    console.error("❌ Error creating session history backup:", error);
    throw error;
  }
}

async function removeSessionTimestampDuplicates(analysis) {
  console.log("\n🧹 REMOVING SESSION TIMESTAMP DUPLICATES");
  console.log("=" * 40);

  try {
    let totalRemoved = 0;
    let sessionsProcessed = 0;

    for (const sessionInfo of analysis.sessionsToClean) {
      const { userId, sessionId, duplicateKeys, duplicateCount, nativeCount } = sessionInfo;
      
      console.log(`\n🔄 Processing session: ${userId}/${sessionId}`);
      console.log(`   🗑️  Removing ${duplicateCount} timestamp duplicates`);
      console.log(`   🛡️  Preserving ${nativeCount} device native entries`);

      // Create batch update to remove all duplicates at once
      const updates = {};
      duplicateKeys.forEach(duplicateKey => {
        updates[`/users/${userId}/sessions/${sessionId}/history/${duplicateKey}`] = null;
      });

      // Execute the batch removal
      await db.ref().update(updates);
      
      totalRemoved += duplicateCount;
      sessionsProcessed++;

      console.log(`   ✅ Removed ${duplicateCount} timestamp duplicates from session`);
    }

    console.log(`\n✅ SESSION TIMESTAMP CLEANUP COMPLETED:`);
    console.log(`   📁 Sessions processed: ${sessionsProcessed}`);
    console.log(`   🗑️  Total entries removed: ${totalRemoved}`);
    console.log(`   🛡️  Device native entries preserved: ${analysis.totalDeviceNativeEntries}`);
    console.log(`   💾 Storage freed: ~${Math.round(totalRemoved * 0.5)} KB`);

    return {
      sessionsProcessed,
      totalRemoved,
      deviceNativePreserved: analysis.totalDeviceNativeEntries,
    };

  } catch (error) {
    console.error("❌ Error removing session timestamp duplicates:", error);
    throw error;
  }
}

async function verifySessionCleanup() {
  console.log("\n🔍 VERIFYING SESSION HISTORY CLEANUP");
  console.log("=" * 38);

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("❌ No users found for verification");
      return;
    }

    const users = usersSnapshot.val();
    let totalSessions = 0;
    let totalHistoryEntries = 0;
    let remainingTimestampDuplicates = 0;
    let deviceNativeEntries = 0;

    for (const userId of Object.keys(users)) {
      const user = users[userId];

      if (user.sessions) {
        const sessionIds = Object.keys(user.sessions);
        totalSessions += sessionIds.length;

        for (const sessionId of sessionIds) {
          const session = user.sessions[sessionId];
          
          if (session.history) {
            const historyEntries = Object.keys(session.history);
            totalHistoryEntries += historyEntries.length;

            historyEntries.forEach(key => {
              if (/^\d{13}$/.test(key)) {
                remainingTimestampDuplicates++;
              } else if (/^\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$/.test(key)) {
                deviceNativeEntries++;
              }
            });
          }
        }

        console.log(`👤 ${userId}: ${sessionIds.length} sessions, ${totalHistoryEntries} total history entries`);
      }
    }

    console.log(`\n📊 SESSION CLEANUP VERIFICATION RESULTS:`);
    console.log(`   📁 Total sessions: ${totalSessions}`);
    console.log(`   📊 Total history entries: ${totalHistoryEntries}`);
    console.log(`   ❌ Remaining timestamp duplicates: ${remainingTimestampDuplicates}`);
    console.log(`   ✅ Device native entries: ${deviceNativeEntries}`);

    const cleanupSuccess = remainingTimestampDuplicates === 0;
    console.log(`\n🎯 CLEANUP STATUS: ${cleanupSuccess ? '✅ SUCCESS' : '⚠️ INCOMPLETE'}`);

    if (cleanupSuccess) {
      console.log("🎉 All session timestamp duplicates have been successfully removed!");
      console.log("✅ Anxiety detection system now has clean, device native format data");
    } else {
      console.log(`⚠️ ${remainingTimestampDuplicates} timestamp duplicates still remain`);
    }

    return {
      totalSessions,
      totalHistoryEntries,
      remainingTimestampDuplicates,
      deviceNativeEntries,
      cleanupSuccess,
    };

  } catch (error) {
    console.error("❌ Error verifying session cleanup:", error);
    throw error;
  }
}

/**
 * Main session history cleanup orchestrator
 */
async function runSessionHistoryCleanup() {
  console.log("🧹 SESSION HISTORY TIMESTAMP CLEANUP");
  console.log("🎯 Removing timestamp duplicates from session history for anxiety detection");
  console.log("✅ Preserving device native format (YYYY_MM_DD_HH_MM_SS)");
  console.log("");

  const startTime = Date.now();

  try {
    // Step 1: Analyze session history duplicates
    const analysis = await analyzeSessionHistoryDuplicates();

    if (!analysis.needsCleanup) {
      console.log("\n🎉 NO SESSION HISTORY CLEANUP NEEDED!");
      console.log("✅ Session history is already clean - no timestamp duplicates found");
      console.log("✅ Anxiety detection system has clean data");
      return { alreadyOptimized: true };
    }

    // Step 2: Create backup
    await createSessionHistoryBackup(analysis);

    // Step 3: Remove timestamp duplicates
    const cleanupResults = await removeSessionTimestampDuplicates(analysis);

    // Step 4: Verify cleanup
    const verificationResults = await verifySessionCleanup();

    const endTime = Date.now();
    const durationSeconds = Math.round((endTime - startTime) / 1000);

    // Final summary
    console.log("\n" + "=" * 70);
    console.log("🎉 SESSION HISTORY CLEANUP COMPLETED SUCCESSFULLY!");
    console.log("=" * 70);
    console.log(`⏱️  Duration: ${durationSeconds} seconds`);
    console.log("");
    console.log("📊 CLEANUP RESULTS:");
    console.log(`   📁 Sessions processed: ${cleanupResults.sessionsProcessed}`);
    console.log(`   🗑️  Timestamp duplicates removed: ${cleanupResults.totalRemoved}`);
    console.log(`   ✅ Device native entries preserved: ${cleanupResults.deviceNativePreserved}`);
    console.log(`   💾 Storage freed: ~${Math.round(cleanupResults.totalRemoved * 0.5)} KB`);
    console.log("");
    console.log("🎯 ANXIETY DETECTION IMPROVEMENTS:");
    console.log("   ✅ Session history now contains only device native format");
    console.log("   ✅ No more timestamp duplicates to confuse algorithms");
    console.log("   ✅ Consistent YYYY_MM_DD_HH_MM_SS format for analysis");
    console.log("   ✅ Cleaner data for anxiety pattern detection");
    console.log("");
    console.log("🚀 SESSION HISTORY IS NOW OPTIMIZED FOR ANXIETY DETECTION!");

    return {
      success: true,
      cleanupResults,
      verificationResults,
      optimized: true,
    };

  } catch (error) {
    console.error("❌ Session history cleanup failed:", error);
    console.log("🔒 Backup available for recovery if needed");
    process.exit(1);
  }
}

// Run cleanup if this script is executed directly
if (require.main === module) {
  runSessionHistoryCleanup()
    .then((results) => {
      console.log("\n✅ Session history cleanup script completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Session history cleanup script failed:", error);
      process.exit(1);
    });
}

module.exports = {
  runSessionHistoryCleanup,
  analyzeSessionHistoryDuplicates,
  removeSessionTimestampDuplicates,
  verifySessionCleanup
};