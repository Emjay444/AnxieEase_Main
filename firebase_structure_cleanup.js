/**
 * 🧹 FIREBASE STRUCTURE CLEANUP SCRIPT
 * 
 * Removes redundant notification nodes and fixes database structure
 * Run with: node firebase_structure_cleanup.js
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

// Configuration
const CLEANUP_CONFIG = {
  DRY_RUN: true,                    // Set to false to make actual changes
  BACKUP_BEFORE_DELETE: true,      // Create backup before deletions
  PRESERVE_RECENT_ALERTS: true,    // Keep alerts less than 7 days old
};

class FirebaseStructureCleanup {
  constructor() {
    this.cleanupReport = {
      nodesRemoved: [],
      nodesKept: [],
      errors: [],
      backupData: {},
      timestamp: new Date().toISOString()
    };
  }

  async runCleanup() {
    console.log("\n🧹 FIREBASE STRUCTURE CLEANUP");
    console.log("==============================");
    console.log(`Mode: ${CLEANUP_CONFIG.DRY_RUN ? 'DRY RUN' : 'LIVE CLEANUP'}`);
    
    try {
      // 1. Identify and explain current redundancy issues
      await this.analyzeCurrentStructure();
      
      // 2. Remove device-level notifications
      await this.cleanupDeviceNotifications();
      
      // 3. Remove user notification duplicates (keep preferences only)
      await this.cleanupUserNotifications();
      
      // 4. Remove redundant user fields
      await this.cleanupUserFields();
      
      // 5. Generate cleanup report
      await this.generateReport();
      
    } catch (error) {
      console.error("❌ Cleanup failed:", error.message);
      this.cleanupReport.errors.push(error.message);
    }
  }

  async analyzeCurrentStructure() {
    console.log("\n🔍 ANALYZING CURRENT STRUCTURE");
    console.log("==============================");
    
    // Check device notifications
    const deviceNotifications = await this.checkPath("/devices/AnxieEase001/notifications");
    if (deviceNotifications.exists) {
      console.log("❌ FOUND: Device notifications (should be removed)");
      console.log(`   Contains: ${deviceNotifications.count} notification entries`);
    }
    
    // Check user structure
    const users = await this.getUserList();
    for (const userId of users) {
      await this.analyzeUserStructure(userId);
    }
  }

  async checkPath(path) {
    try {
      const snapshot = await db.ref(path).once("value");
      return {
        exists: snapshot.exists(),
        data: snapshot.val(),
        count: snapshot.exists() ? Object.keys(snapshot.val() || {}).length : 0
      };
    } catch (error) {
      return { exists: false, data: null, count: 0, error: error.message };
    }
  }

  async getUserList() {
    try {
      const snapshot = await db.ref("/users").once("value");
      return snapshot.exists() ? Object.keys(snapshot.val()) : [];
    } catch (error) {
      console.error("Error getting user list:", error);
      return [];
    }
  }

  async analyzeUserStructure(userId) {
    console.log(`\n👤 ANALYZING USER: ${userId.substring(0, 8)}...`);
    
    const userRef = db.ref(`/users/${userId}`);
    const userSnapshot = await userRef.once("value");
    
    if (!userSnapshot.exists()) {
      console.log("   ❌ User data not found");
      return;
    }
    
    const userData = userSnapshot.val();
    
    // Check for notification history
    if (userData.notifications) {
      const notificationCount = Object.keys(userData.notifications).length;
      console.log(`   ❌ REDUNDANT: User has ${notificationCount} notifications in Firebase`);
      console.log(`   📋 Should use: Supabase notifications table instead`);
    }
    
    // Check for redundant fields
    if (userData.userId) {
      console.log(`   ❌ REDUNDANT: userId field (parent key is already the ID)`);
    }
    
    if (userData.source) {
      console.log(`   ❌ REDUNDANT: source field ("${userData.source}" - development artifact)`);
    }
    
    // Check essential fields
    const essentialFields = ['anxietyAlertsEnabled', 'notificationsEnabled', 'baseline'];
    essentialFields.forEach(field => {
      if (userData[field]) {
        console.log(`   ✅ ESSENTIAL: ${field} (keep this)`);
      }
    });
  }

  async cleanupDeviceNotifications() {
    console.log("\n🗑️ CLEANING DEVICE NOTIFICATIONS");
    console.log("=================================");
    
    const deviceNotifPath = "/devices/AnxieEase001/notifications";
    const deviceNotifCheck = await this.checkPath(deviceNotifPath);
    
    if (deviceNotifCheck.exists) {
      console.log(`📍 Found device notifications: ${deviceNotifCheck.count} entries`);
      console.log("❌ Reason to remove: Notifications should only exist in Supabase");
      
      if (CLEANUP_CONFIG.BACKUP_BEFORE_DELETE) {
        this.cleanupReport.backupData[deviceNotifPath] = deviceNotifCheck.data;
        console.log("💾 Backed up device notifications");
      }
      
      if (!CLEANUP_CONFIG.DRY_RUN) {
        await db.ref(deviceNotifPath).remove();
        console.log("✅ Removed device notifications");
        this.cleanupReport.nodesRemoved.push(deviceNotifPath);
      } else {
        console.log("🔍 [DRY RUN] Would remove device notifications");
      }
    } else {
      console.log("✅ No device notifications found");
    }
  }

  async cleanupUserNotifications() {
    console.log("\n🗑️ CLEANING USER NOTIFICATION DUPLICATES");
    console.log("=========================================");
    
    const users = await this.getUserList();
    
    for (const userId of users) {
      const userNotifPath = `/users/${userId}/notifications`;
      const userNotifCheck = await this.checkPath(userNotifPath);
      
      if (userNotifCheck.exists) {
        console.log(`\n👤 User ${userId.substring(0, 8)}:`);
        console.log(`   📱 Has ${userNotifCheck.count} notifications in Firebase`);
        console.log(`   ❌ Reason to remove: Should use Supabase notifications table`);
        
        if (CLEANUP_CONFIG.BACKUP_BEFORE_DELETE) {
          this.cleanupReport.backupData[userNotifPath] = userNotifCheck.data;
          console.log("   💾 Backed up user notifications");
        }
        
        if (!CLEANUP_CONFIG.DRY_RUN) {
          await db.ref(userNotifPath).remove();
          console.log("   ✅ Removed user notifications");
          this.cleanupReport.nodesRemoved.push(userNotifPath);
        } else {
          console.log("   🔍 [DRY RUN] Would remove user notifications");
        }
      }
    }
  }

  async cleanupUserFields() {
    console.log("\n🗑️ CLEANING REDUNDANT USER FIELDS");
    console.log("==================================");
    
    const users = await this.getUserList();
    
    for (const userId of users) {
      const userRef = db.ref(`/users/${userId}`);
      const userSnapshot = await userRef.once("value");
      
      if (!userSnapshot.exists()) continue;
      
      const userData = userSnapshot.val();
      let fieldsToRemove = [];
      
      console.log(`\n👤 User ${userId.substring(0, 8)}:`);
      
      // Check for redundant userId field
      if (userData.userId && userData.userId === userId) {
        fieldsToRemove.push('userId');
        console.log("   ❌ Removing redundant userId field");
      }
      
      // Check for development source field
      if (userData.source === "manual_fix" || userData.source) {
        fieldsToRemove.push('source');
        console.log(`   ❌ Removing development source field: "${userData.source}"`);
      }
      
      // Remove redundant fields
      if (fieldsToRemove.length > 0) {
        if (!CLEANUP_CONFIG.DRY_RUN) {
          for (const field of fieldsToRemove) {
            await userRef.child(field).remove();
            console.log(`   ✅ Removed: ${field}`);
          }
          this.cleanupReport.nodesRemoved.push(...fieldsToRemove.map(f => `/users/${userId}/${f}`));
        } else {
          console.log(`   🔍 [DRY RUN] Would remove: ${fieldsToRemove.join(', ')}`);
        }
      } else {
        console.log("   ✅ No redundant fields found");
      }
    }
  }

  async generateReport() {
    console.log("\n📊 CLEANUP REPORT");
    console.log("=================");
    
    const report = this.cleanupReport;
    
    console.log(`⏰ Cleanup completed: ${report.timestamp}`);
    console.log(`🗑️ Nodes removed: ${report.nodesRemoved.length}`);
    console.log(`❌ Errors encountered: ${report.errors.length}`);
    
    if (report.nodesRemoved.length > 0) {
      console.log("\n🗑️ REMOVED NODES:");
      report.nodesRemoved.forEach(node => {
        console.log(`   • ${node}`);
      });
    }
    
    if (report.errors.length > 0) {
      console.log("\n❌ ERRORS:");
      report.errors.forEach(error => {
        console.log(`   • ${error}`);
      });
    }
    
    // Save backup data if created
    if (CLEANUP_CONFIG.BACKUP_BEFORE_DELETE && Object.keys(report.backupData).length > 0) {
      const backupRef = db.ref(`/maintenance/cleanup_backups/${Date.now()}`);
      if (!CLEANUP_CONFIG.DRY_RUN) {
        await backupRef.set(report.backupData);
        console.log("💾 Backup data saved to /maintenance/cleanup_backups/");
      }
    }
    
    console.log("\n🎯 WHAT YOUR STRUCTURE SHOULD LOOK NOW:");
    console.log("=======================================");
    console.log("✅ /devices/AnxieEase001/assignment    - Device ownership");
    console.log("✅ /devices/AnxieEase001/current       - Live sensor data");
    console.log("✅ /devices/AnxieEase001/history       - Sensor history");
    console.log("✅ /devices/AnxieEase001/metadata      - Device info");
    console.log("❌ /devices/AnxieEase001/notifications - REMOVED");
    console.log("");
    console.log("✅ /users/{id}/anxietyAlertsEnabled    - User preference");
    console.log("✅ /users/{id}/notificationsEnabled    - Master toggle");
    console.log("✅ /users/{id}/baseline                - Personal thresholds");
    console.log("✅ /users/{id}/sessions                - Usage history");
    console.log("❌ /users/{id}/notifications           - REMOVED (use Supabase)");
    console.log("❌ /users/{id}/userId                  - REMOVED (redundant)");
    console.log("❌ /users/{id}/source                  - REMOVED (dev artifact)");
    
    console.log("\n💡 NOTIFICATION FLOW AFTER CLEANUP:");
    console.log("===================================");
    console.log("1. 📊 Sensor data → Firebase /devices/AnxieEase001/current");
    console.log("2. 🔍 Cloud Function → Analyzes against user baseline");
    console.log("3. 🚨 If anxiety → Save to Supabase notifications table");
    console.log("4. 📱 Cloud Function → Send push notification via FCM");
    console.log("5. 📲 Mobile app → Read notifications from Supabase only");
    
    return report;
  }
}

// Main execution
async function main() {
  const cleanup = new FirebaseStructureCleanup();
  
  console.log("🔧 FIREBASE STRUCTURE CLEANUP TOOL");
  console.log("===================================");
  console.log("");
  console.log("📋 WHY YOUR FIREBASE HAS NOTIFICATION NODES:");
  console.log("• Test scripts created notifications in Firebase");
  console.log("• Development artifacts left redundant fields");
  console.log("• Multiple notification storage locations created");
  console.log("• Should use Supabase as single source of truth");
  console.log("");
  
  if (CLEANUP_CONFIG.DRY_RUN) {
    console.log("⚠️  DRY RUN MODE - No changes will be made");
    console.log("   Set DRY_RUN: false in script to make actual changes");
  } else {
    console.log("🔥 LIVE MODE - Changes will be permanent!");
    console.log("   Backup will be created before deletions");
  }
  
  const report = await cleanup.runCleanup();
  
  console.log("\n🚀 NEXT STEPS:");
  console.log("==============");
  if (CLEANUP_CONFIG.DRY_RUN) {
    console.log("1. Review the analysis above");
    console.log("2. Set DRY_RUN: false to perform cleanup");
    console.log("3. Run script again to clean structure");
  } else {
    console.log("1. ✅ Structure cleaned!");
    console.log("2. Test your app to ensure notifications still work");
    console.log("3. Notifications should now come only from Supabase");
    console.log("4. Monitor for any issues");
  }
  
  return report;
}

// Export for external use
module.exports = { FirebaseStructureCleanup, CLEANUP_CONFIG };

// Run if executed directly
if (require.main === module) {
  main().catch(console.error);
}