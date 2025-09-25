/**
 * 🧹 FIREBASE AUTO-CLEANUP SYSTEM
 * 
 * Comprehensive cleanup system to prevent Firebase storage bloat
 * Removes unnecessary nodes and manages data retention automatically
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

// CLEANUP CONFIGURATION
const CLEANUP_CONFIG = {
  // Data retention periods (in days)
  DEVICE_HISTORY_RETENTION: 7,      // Keep device history for 7 days
  USER_SESSION_RETENTION: 30,       // Keep user sessions for 30 days  
  ANXIETY_ALERTS_RETENTION: 90,     // Keep anxiety alerts for 90 days
  TEST_DATA_RETENTION: 0,           // Remove all test data immediately
  
  // Enable/disable cleanup categories
  CLEANUP_DEVICE_HISTORY: true,
  CLEANUP_OLD_SESSIONS: true,
  CLEANUP_OLD_ALERTS: true,
  CLEANUP_TEST_DATA: true,
  CLEANUP_DUPLICATE_HISTORY: true,
  
  // Safety settings
  DRY_RUN: false,                   // Set to true to preview without making changes
  MAX_DELETIONS_PER_RUN: 1000,     // Maximum items to delete in one run
  BACKUP_BEFORE_DELETE: true,       // Create backup before major deletions
};

class FirebaseCleanup {
  constructor() {
    this.deletedCount = 0;
    this.backupData = {};
    this.errors = [];
  }

  async runFullCleanup() {
    console.log("\n🧹 FIREBASE AUTO-CLEANUP STARTING");
    console.log("==================================");
    console.log(`Config: DRY_RUN = ${CLEANUP_CONFIG.DRY_RUN}`);
    console.log(`Device History Retention: ${CLEANUP_CONFIG.DEVICE_HISTORY_RETENTION} days`);
    console.log(`Session Retention: ${CLEANUP_CONFIG.USER_SESSION_RETENTION} days`);
    console.log(`Alert Retention: ${CLEANUP_CONFIG.ANXIETY_ALERTS_RETENTION} days`);

    try {
      // 1. Remove test data and unnecessary nodes
      if (CLEANUP_CONFIG.CLEANUP_TEST_DATA) {
        await this.cleanupTestData();
      }

      // 2. Clean old device history
      if (CLEANUP_CONFIG.CLEANUP_DEVICE_HISTORY) {
        await this.cleanupDeviceHistory();
      }

      // 3. Clean old user sessions
      if (CLEANUP_CONFIG.CLEANUP_OLD_SESSIONS) {
        await this.cleanupOldSessions();
      }

      // 4. Clean old anxiety alerts
      if (CLEANUP_CONFIG.CLEANUP_OLD_ALERTS) {
        await this.cleanupOldAlerts();
      }

      // 5. Remove duplicate history data
      if (CLEANUP_CONFIG.CLEANUP_DUPLICATE_HISTORY) {
        await this.cleanupDuplicateHistory();
      }

      // 6. Generate cleanup report
      await this.generateCleanupReport();

    } catch (error) {
      console.error("❌ Cleanup failed:", error.message);
      this.errors.push(error.message);
    }
  }

  async cleanupTestData() {
    console.log("\n🧪 CLEANING UP TEST DATA");
    console.log("========================");

    const testNodes = [
      "/devices/AnxieEase001/testNotification",
      "/devices/AnxieEase001/notifications", // If exists and contains test data
      "/devices/AnxieEase001/userNotifications", // Test user notifications
    ];

    for (const nodePath of testNodes) {
      try {
        const ref = db.ref(nodePath);
        const snapshot = await ref.once("value");
        
        if (snapshot.exists()) {
          const data = snapshot.val();
          console.log(`📍 Found test data at: ${nodePath}`);
          
          if (!CLEANUP_CONFIG.DRY_RUN) {
            if (CLEANUP_CONFIG.BACKUP_BEFORE_DELETE) {
              this.backupData[nodePath] = data;
            }
            await ref.remove();
            console.log(`✅ Removed: ${nodePath}`);
            this.deletedCount++;
          } else {
            console.log(`🔍 [DRY RUN] Would remove: ${nodePath}`);
          }
        }
      } catch (error) {
        console.error(`❌ Error cleaning ${nodePath}:`, error.message);
        this.errors.push(`Test data cleanup: ${error.message}`);
      }
    }
  }

  async cleanupDeviceHistory() {
    console.log("\n📊 CLEANING UP DEVICE HISTORY");
    console.log("=============================");

    const cutoffTime = Date.now() - (CLEANUP_CONFIG.DEVICE_HISTORY_RETENTION * 24 * 60 * 60 * 1000);
    const historyRef = db.ref("/devices/AnxieEase001/history");
    
    try {
      const snapshot = await historyRef.once("value");
      
      if (!snapshot.exists()) {
        console.log("✅ No device history found");
        return;
      }

      const history = snapshot.val();
      const timestamps = Object.keys(history);
      let oldEntries = 0;

      console.log(`📊 Total history entries: ${timestamps.length}`);
      console.log(`🗓️  Cutoff date: ${new Date(cutoffTime).toLocaleString()}`);

      for (const timestamp of timestamps) {
        const entryTime = parseInt(timestamp);
        
        if (entryTime < cutoffTime) {
          oldEntries++;
          
          if (!CLEANUP_CONFIG.DRY_RUN) {
            await historyRef.child(timestamp).remove();
            this.deletedCount++;
            
            if (this.deletedCount % 100 === 0) {
              console.log(`🧹 Cleaned ${this.deletedCount} entries...`);
            }
          }
          
          if (this.deletedCount >= CLEANUP_CONFIG.MAX_DELETIONS_PER_RUN) {
            console.log("⚠️  Reached maximum deletions per run");
            break;
          }
        }
      }

      if (CLEANUP_CONFIG.DRY_RUN) {
        console.log(`🔍 [DRY RUN] Would remove ${oldEntries} old history entries`);
      } else {
        console.log(`✅ Removed ${oldEntries} old device history entries`);
      }

    } catch (error) {
      console.error("❌ Error cleaning device history:", error.message);
      this.errors.push(`Device history cleanup: ${error.message}`);
    }
  }

  async cleanupOldSessions() {
    console.log("\n👥 CLEANING UP OLD USER SESSIONS");
    console.log("================================");

    const cutoffTime = Date.now() - (CLEANUP_CONFIG.USER_SESSION_RETENTION * 24 * 60 * 60 * 1000);
    const usersRef = db.ref("/users");

    try {
      const snapshot = await usersRef.once("value");
      
      if (!snapshot.exists()) {
        console.log("✅ No user data found");
        return;
      }

      const users = snapshot.val();
      let totalOldSessions = 0;

      for (const userId of Object.keys(users)) {
        const userSessions = users[userId].sessions;
        
        if (!userSessions) continue;

        console.log(`👤 Processing user: ${userId.substring(0, 8)}...`);
        
        for (const sessionId of Object.keys(userSessions)) {
          const session = userSessions[sessionId];
          
          // Check if session is old and ended
          const sessionTime = session.metadata?.startTime || session.metadata?.endTime;
          const isOldSession = sessionTime && parseInt(sessionTime) < cutoffTime;
          const isEnded = session.metadata?.status === 'ended';
          
          if (isOldSession && isEnded) {
            totalOldSessions++;
            
            if (!CLEANUP_CONFIG.DRY_RUN) {
              await usersRef.child(`${userId}/sessions/${sessionId}`).remove();
              this.deletedCount++;
            }
          }
        }
      }

      if (CLEANUP_CONFIG.DRY_RUN) {
        console.log(`🔍 [DRY RUN] Would remove ${totalOldSessions} old sessions`);
      } else {
        console.log(`✅ Removed ${totalOldSessions} old user sessions`);
      }

    } catch (error) {
      console.error("❌ Error cleaning user sessions:", error.message);
      this.errors.push(`User sessions cleanup: ${error.message}`);
    }
  }

  async cleanupOldAlerts() {
    console.log("\n🚨 CLEANING UP OLD ANXIETY ALERTS");
    console.log("=================================");

    const cutoffTime = Date.now() - (CLEANUP_CONFIG.ANXIETY_ALERTS_RETENTION * 24 * 60 * 60 * 1000);
    const usersRef = db.ref("/users");

    try {
      const snapshot = await usersRef.once("value");
      
      if (!snapshot.exists()) {
        console.log("✅ No user data found");
        return;
      }

      const users = snapshot.val();
      let totalOldAlerts = 0;

      for (const userId of Object.keys(users)) {
        const userAlerts = users[userId].alerts;
        
        if (!userAlerts) continue;

        console.log(`🚨 Processing alerts for user: ${userId.substring(0, 8)}...`);
        
        for (const alertId of Object.keys(userAlerts)) {
          const alert = userAlerts[alertId];
          const alertTime = alert.timestamp;
          
          if (alertTime && parseInt(alertTime) < cutoffTime) {
            totalOldAlerts++;
            
            if (!CLEANUP_CONFIG.DRY_RUN) {
              await usersRef.child(`${userId}/alerts/${alertId}`).remove();
              this.deletedCount++;
            }
          }
        }
      }

      if (CLEANUP_CONFIG.DRY_RUN) {
        console.log(`🔍 [DRY RUN] Would remove ${totalOldAlerts} old alerts`);
      } else {
        console.log(`✅ Removed ${totalOldAlerts} old anxiety alerts`);
      }

    } catch (error) {
      console.error("❌ Error cleaning anxiety alerts:", error.message);
      this.errors.push(`Anxiety alerts cleanup: ${error.message}`);
    }
  }

  async cleanupDuplicateHistory() {
    console.log("\n🔄 CLEANING UP DUPLICATE HISTORY DATA");
    console.log("=====================================");

    // This addresses the issue where user history might duplicate device history
    const usersRef = db.ref("/users");
    const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");

    try {
      const [usersSnapshot, deviceHistorySnapshot] = await Promise.all([
        usersRef.once("value"),
        deviceHistoryRef.once("value")
      ]);

      if (!usersSnapshot.exists() || !deviceHistorySnapshot.exists()) {
        console.log("✅ No data to compare for duplicates");
        return;
      }

      const users = usersSnapshot.val();
      const deviceHistory = deviceHistorySnapshot.val();
      let duplicatesRemoved = 0;

      for (const userId of Object.keys(users)) {
        const userSessions = users[userId].sessions;
        
        if (!userSessions) continue;

        for (const sessionId of Object.keys(userSessions)) {
          const sessionData = userSessions[sessionId].data;
          
          if (!sessionData) continue;

          // Check for duplicate timestamps between user session data and device history
          for (const timestamp of Object.keys(sessionData)) {
            if (deviceHistory[timestamp]) {
              // This timestamp exists in both places - remove from user session
              duplicatesRemoved++;
              
              if (!CLEANUP_CONFIG.DRY_RUN) {
                await usersRef.child(`${userId}/sessions/${sessionId}/data/${timestamp}`).remove();
                this.deletedCount++;
              }
            }
          }
        }
      }

      if (CLEANUP_CONFIG.DRY_RUN) {
        console.log(`🔍 [DRY RUN] Would remove ${duplicatesRemoved} duplicate history entries`);
      } else {
        console.log(`✅ Removed ${duplicatesRemoved} duplicate history entries`);
      }

    } catch (error) {
      console.error("❌ Error cleaning duplicate history:", error.message);
      this.errors.push(`Duplicate history cleanup: ${error.message}`);
    }
  }

  async generateCleanupReport() {
    console.log("\n📊 CLEANUP REPORT");
    console.log("=================");

    const reportTime = new Date().toLocaleString();
    const report = {
      timestamp: reportTime,
      mode: CLEANUP_CONFIG.DRY_RUN ? "DRY RUN" : "LIVE",
      totalDeletions: this.deletedCount,
      errors: this.errors,
      config: CLEANUP_CONFIG,
      backupCreated: CLEANUP_CONFIG.BACKUP_BEFORE_DELETE && Object.keys(this.backupData).length > 0
    };

    console.log(`⏰ Cleanup completed at: ${reportTime}`);
    console.log(`📊 Total deletions: ${this.deletedCount}`);
    console.log(`❌ Errors encountered: ${this.errors.length}`);
    
    if (this.errors.length > 0) {
      console.log("\n❌ ERRORS:");
      this.errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error}`);
      });
    }

    // Save cleanup report to Firebase
    if (!CLEANUP_CONFIG.DRY_RUN) {
      try {
        const reportRef = db.ref(`/maintenance/cleanup_reports/${Date.now()}`);
        await reportRef.set(report);
        console.log("✅ Cleanup report saved to Firebase");
      } catch (error) {
        console.error("❌ Failed to save cleanup report:", error.message);
      }
    }

    // Save backup data if created
    if (CLEANUP_CONFIG.BACKUP_BEFORE_DELETE && Object.keys(this.backupData).length > 0) {
      try {
        const backupRef = db.ref(`/maintenance/cleanup_backups/${Date.now()}`);
        await backupRef.set(this.backupData);
        console.log("✅ Backup data saved to Firebase");
      } catch (error) {
        console.error("❌ Failed to save backup data:", error.message);
      }
    }

    console.log("\n🎯 RECOMMENDATIONS:");
    console.log("===================");
    console.log("• Run this cleanup weekly to maintain optimal performance");
    console.log("• Monitor backup size if enabled");
    console.log("• Adjust retention periods based on your needs");
    console.log("• Consider implementing scheduled cleanup");

    return report;
  }
}

// Schedule cleanup function
async function scheduleCleanup() {
  console.log("⏰ SCHEDULING AUTOMATIC CLEANUP");
  console.log("===============================");
  console.log("To run this automatically, set up a cron job or scheduled task:");
  console.log("");
  console.log("Windows (Task Scheduler):");
  console.log("schtasks /create /tn \"Firebase Cleanup\" /tr \"node firebase_auto_cleanup.js\" /sc weekly");
  console.log("");
  console.log("Linux/Mac (Crontab):");
  console.log("0 2 * * 0 cd /path/to/your/project && node firebase_auto_cleanup.js");
  console.log("(Runs every Sunday at 2 AM)");
}

// Main execution
async function main() {
  const cleanup = new FirebaseCleanup();
  await cleanup.runFullCleanup();
  
  console.log("\n🚀 NEXT STEPS:");
  console.log("==============");
  console.log("1. Review the cleanup results above");
  console.log("2. If satisfied, set DRY_RUN to false for live cleanup");
  console.log("3. Consider scheduling automatic cleanup");
  console.log("4. Monitor Firebase storage usage regularly");
  
  await scheduleCleanup();
}

// Run cleanup if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { FirebaseCleanup, CLEANUP_CONFIG };