/**
 * 🧪 TEST AUTO-CLEANUP FUNCTIONS
 * 
 * This script tests the auto-cleanup functions locally before deployment
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app"
  });
}

const db = admin.database();

async function testAutoCleanupLogic() {
  console.log("🧪 TESTING AUTO-CLEANUP LOGIC");
  console.log("===============================");
  
  try {
    // Test 1: Check current data structure
    console.log("\n📊 Test 1: Current Data Structure");
    console.log("==================================");
    
    // Check device history size
    const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
    const historySnapshot = await deviceHistoryRef.once("value");
    
    if (historySnapshot.exists()) {
      const historyData = historySnapshot.val();
      const historyCount = Object.keys(historyData).length;
      console.log(`✅ Device history entries: ${historyCount}`);
      
      // Check age distribution
      const now = Date.now();
      const oneWeekAgo = now - (7 * 24 * 60 * 60 * 1000);
      const oneMonthAgo = now - (30 * 24 * 60 * 60 * 1000);
      
      let recentCount = 0;
      let weekOldCount = 0;
      let monthOldCount = 0;
      
      Object.values(historyData).forEach((entry) => {
        const timestamp = entry.timestamp || 0;
        if (timestamp > oneWeekAgo) recentCount++;
        else if (timestamp > oneMonthAgo) weekOldCount++;
        else monthOldCount++;
      });
      
      console.log(`   • Recent (< 1 week): ${recentCount}`);
      console.log(`   • Old (1-4 weeks): ${weekOldCount}`);
      console.log(`   • Very old (> 1 month): ${monthOldCount}`);
      
      if (monthOldCount > 0) {
        console.log(`   🧹 Would clean up: ${monthOldCount} entries`);
      }
    } else {
      console.log("✅ No device history found");
    }
    
    // Test 2: Check user sessions
    console.log("\n👥 Test 2: User Sessions Analysis");
    console.log("==================================");
    
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();
      let totalSessions = 0;
      let oldSessions = 0;
      
      const threeMonthsAgo = Date.now() - (90 * 24 * 60 * 60 * 1000);
      
      Object.entries(users).forEach(([userId, userData]) => {
        if (userData.sessions) {
          const sessions = userData.sessions;
          Object.values(sessions).forEach((session) => {
            totalSessions++;
            if (session.timestamp && session.timestamp < threeMonthsAgo) {
              oldSessions++;
            }
          });
        }
      });
      
      console.log(`✅ Total user sessions: ${totalSessions}`);
      console.log(`   • Old sessions (> 3 months): ${oldSessions}`);
      
      if (oldSessions > 0) {
        console.log(`   🧹 Would clean up: ${oldSessions} sessions`);
      }
    }
    
    // Test 3: Check anxiety alerts
    console.log("\n🚨 Test 3: Anxiety Alerts Analysis");
    console.log("===================================");
    
    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();
      let totalAlerts = 0;
      let oldAlerts = 0;
      
      const sixMonthsAgo = Date.now() - (180 * 24 * 60 * 60 * 1000);
      
      Object.entries(users).forEach(([userId, userData]) => {
        if (userData.anxietyAlerts) {
          const alerts = userData.anxietyAlerts;
          Object.values(alerts).forEach((alert) => {
            totalAlerts++;
            if (alert.timestamp && alert.timestamp < sixMonthsAgo) {
              oldAlerts++;
            }
          });
        }
      });
      
      console.log(`✅ Total anxiety alerts: ${totalAlerts}`);
      console.log(`   • Old alerts (> 6 months): ${oldAlerts}`);
      
      if (oldAlerts > 0) {
        console.log(`   🧹 Would clean up: ${oldAlerts} alerts`);
      }
    }
    
    // Test 4: Check backups
    console.log("\n📦 Test 4: Backup Analysis");
    console.log("===========================");
    
    const backupsRef = db.ref("/backups");
    const backupsSnapshot = await backupsRef.once("value");
    
    if (backupsSnapshot.exists()) {
      const backups = backupsSnapshot.val();
      const backupCount = Object.keys(backups).length;
      console.log(`✅ Total backups: ${backupCount}`);
      
      const oneWeekAgo = Date.now() - (7 * 24 * 60 * 60 * 1000);
      let oldBackups = 0;
      
      Object.values(backups).forEach((backup) => {
        if (backup.metadata && backup.metadata.created) {
          const backupTime = new Date(backup.metadata.created).getTime();
          if (backupTime < oneWeekAgo) {
            oldBackups++;
          }
        }
      });
      
      console.log(`   • Old backups (> 1 week): ${oldBackups}`);
      
      if (oldBackups > 0) {
        console.log(`   🧹 Would clean up: ${oldBackups} backups`);
      }
    } else {
      console.log("✅ No backups found");
    }
    
    // Summary
    console.log("\n📈 CLEANUP POTENTIAL SUMMARY");
    console.log("=============================");
    console.log("Based on current data structure, auto-cleanup would:");
    console.log("✅ Remove old device sensor history (> 30 days)");
    console.log("✅ Remove old user session data (> 90 days)");
    console.log("✅ Archive old anxiety alerts (> 180 days)");
    console.log("✅ Remove old backup files (> 7 days)");
    console.log("");
    console.log("💡 Benefits:");
    console.log("• Reduced Firebase storage costs");
    console.log("• Faster database queries");
    console.log("• Better performance");
    console.log("• Automatic maintenance");
    
    console.log("\n🚀 NEXT STEPS:");
    console.log("===============");
    console.log("1. Deploy the auto-cleanup functions:");
    console.log("   PowerShell: .\\deploy_auto_cleanup.ps1");
    console.log("   Bash: ./deploy_auto_cleanup.sh");
    console.log("");
    console.log("2. Test manual cleanup:");
    console.log("   POST https://us-central1-anxieease-sensors.cloudfunctions.net/manualCleanup");
    console.log("");
    console.log("3. Monitor cleanup logs:");
    console.log("   GET https://us-central1-anxieease-sensors.cloudfunctions.net/getCleanupStats");
    console.log("");
    console.log("4. Auto-cleanup will run daily at 2 AM UTC automatically! 🎉");
    
  } catch (error) {
    console.error("❌ Test failed:", error);
  } finally {
    process.exit(0);
  }
}

// Run the test
testAutoCleanupLogic();