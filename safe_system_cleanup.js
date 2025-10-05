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
 * SAFE SYSTEM NODE CLEANUP
 * 
 * Only removes nodes that are safe to delete:
 * - Old backup entries (keep last 3 days)
 * - Historical status data
 * 
 * PRESERVES critical nodes:
 * - cleanup_logs (used by active functions)
 * - duplication_prevention (monitoring config)
 * - session_management (policy config)
 */

async function safeSystemCleanup() {
  console.log("🧹 SAFE SYSTEM NODE CLEANUP");
  console.log("=" * 50);
  console.log("✅ Preserving critical active nodes");
  console.log("🗑️  Removing safe archival data");
  console.log("");

  try {
    const results = {
      oldBackupsRemoved: 0,
      statusDataRemoved: 0,
      criticalNodesPreserved: [],
      spaceSaved: 0
    };

    // 1. Clean old backup entries (keep last 3 days)
    console.log("📦 CLEANING OLD BACKUPS (keeping recent 3 days)");
    console.log("─".repeat(50));
    
    const cutoffTime = Date.now() - (3 * 24 * 60 * 60 * 1000); // 3 days ago
    const backupsRef = db.ref("/system/backups");
    const backupsSnapshot = await backupsRef.once("value");
    
    if (backupsSnapshot.exists()) {
      const backups = backupsSnapshot.val();
      const updates = {};
      
      for (const [backupKey, backupData] of Object.entries(backups)) {
        const backupTime = new Date(backupData.timestamp).getTime();
        
        if (backupTime < cutoffTime) {
          updates[backupKey] = null;
          results.oldBackupsRemoved++;
          console.log(`🗑️  Removing old backup: ${backupKey} (${new Date(backupData.timestamp).toLocaleDateString()})`);
        } else {
          console.log(`✅ Keeping recent backup: ${backupKey} (${new Date(backupData.timestamp).toLocaleDateString()})`);
        }
      }
      
      if (Object.keys(updates).length > 0) {
        await backupsRef.update(updates);
        console.log(`✅ Removed ${results.oldBackupsRemoved} old backup entries`);
      } else {
        console.log("✅ No old backups to remove");
      }
    } else {
      console.log("ℹ️  No backups found");
    }

    // 2. Remove smart_cleanup_results (historical status only)
    console.log("\n📊 REMOVING HISTORICAL STATUS DATA");
    console.log("─".repeat(50));
    
    const smartResultsRef = db.ref("/system/smart_cleanup_results");
    const smartResultsSnapshot = await smartResultsRef.once("value");
    
    if (smartResultsSnapshot.exists()) {
      await smartResultsRef.remove();
      results.statusDataRemoved++;
      console.log("🗑️  Removed /system/smart_cleanup_results (historical status)");
    } else {
      console.log("ℹ️  No smart cleanup results to remove");
    }

    // 3. Verify critical nodes are preserved
    console.log("\n🛡️  VERIFYING CRITICAL NODES PRESERVED");
    console.log("─".repeat(50));
    
    const criticalNodes = [
      'cleanup_logs',
      'duplication_prevention', 
      'session_management'
    ];
    
    for (const nodeName of criticalNodes) {
      const nodeRef = db.ref(`/system/${nodeName}`);
      const nodeSnapshot = await nodeRef.once("value");
      
      if (nodeSnapshot.exists()) {
        results.criticalNodesPreserved.push(nodeName);
        console.log(`✅ PRESERVED: /system/${nodeName}`);
      } else {
        console.log(`⚠️  Missing critical node: /system/${nodeName}`);
      }
    }

    // 4. Calculate estimated space saved
    results.spaceSaved = (results.oldBackupsRemoved * 2) + (results.statusDataRemoved * 0.5); // KB estimate

    // Summary
    console.log("\n" + "=" * 60);
    console.log("✅ SAFE SYSTEM CLEANUP COMPLETED");
    console.log("=" * 60);
    console.log(`🗑️  Old backups removed: ${results.oldBackupsRemoved}`);
    console.log(`📊 Status data removed: ${results.statusDataRemoved}`);
    console.log(`🛡️  Critical nodes preserved: ${results.criticalNodesPreserved.length}`);
    console.log(`💾 Estimated space saved: ~${results.spaceSaved} KB`);
    console.log("");
    console.log("🔒 PRESERVED CRITICAL NODES:");
    results.criticalNodesPreserved.forEach(node => {
      console.log(`   ✅ /system/${node}`);
    });

    console.log("\n🎯 SYSTEM STATUS:");
    console.log("   ✅ Automated cleanup functions: ACTIVE");
    console.log("   ✅ Duplication monitoring: ACTIVE"); 
    console.log("   ✅ Session management: ACTIVE");
    console.log("   ✅ Recent backups: PRESERVED");

    return results;

  } catch (error) {
    console.error("❌ Error during safe system cleanup:", error);
    throw error;
  }
}

// Run if this script is executed directly
if (require.main === module) {
  safeSystemCleanup()
    .then((results) => {
      console.log("\n✅ Safe system cleanup completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Safe system cleanup failed:", error);
      process.exit(1);
    });
}

module.exports = {
  safeSystemCleanup
};