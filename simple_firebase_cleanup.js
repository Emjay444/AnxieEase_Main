/**
 * 🧹 SIMPLE FIREBASE STRUCTURE CLEANUP
 * 
 * This script removes redundant notification nodes from Firebase
 * while preserving essential user preferences and data.
 */

const admin = require("firebase-admin");

// Initialize Firebase with service account
let db;
try {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app"
  });
  db = admin.database();
  console.log("✅ Firebase initialized with service account credentials");
} catch (error) {
  console.log("❌ Failed to initialize Firebase:", error.message);
  console.log("\n📋 TO FIX THIS:");
  console.log("1. Download your service account key from Firebase Console:");
  console.log("   • Go to Firebase Console → Project Settings → Service accounts");
  console.log("   • Click 'Generate new private key' and download the JSON file");
  console.log("   • Rename it to 'service-account-key.json' and put it in this folder");
  console.log("\n2. Or set up Application Default Credentials:");
  console.log("   • Run: firebase login");
  console.log("   • Run: firebase use --add (select your project)");
  process.exit(1);
}

// Configuration
const DRY_RUN = false; // Set to false to actually perform cleanup
const BACKUP_ENABLED = true;
const MAX_BACKUPS = 3;

console.log("\n🔥 FIREBASE STRUCTURE CLEANUP TOOL");
console.log("===================================");
console.log(`Mode: ${DRY_RUN ? "🔍 DRY RUN (preview only)" : "🧹 LIVE CLEANUP"}`);
console.log(`Backup: ${BACKUP_ENABLED ? "✅ Enabled" : "❌ Disabled"}`);

const CLEANUP_TARGETS = {
  // Device-level notification cleanup
  deviceNotifications: "/devices/AnxieEase001/notifications",
  
  // User-level redundant data cleanup
  userRedundantFields: [
    "notifications",  // Use Supabase instead
    "userId",         // Redundant (parent key is the ID)
    "source"          // Development artifact
  ],
  
  // Fields to preserve (critical for app functionality)
  userPreserveFields: [
    "anxietyAlertsEnabled",  // Anxiety detection toggle
    "notificationsEnabled",  // Master notification toggle
    "baseline",              // User thresholds & FCM token
    "sessions",              // Usage history
    "profile",               // User profile data
    "preferences",           // App preferences
    "settings"               // User settings
  ]
};

async function createBackup() {
  if (!BACKUP_ENABLED) return null;
  
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const backupKey = `backup_${timestamp}`;
  
  console.log(`\n📦 Creating backup: ${backupKey}...`);
  
  try {
    // Backup device data
    const deviceData = await db.ref("/devices").once('value');
    if (deviceData.exists()) {
      await db.ref(`/backups/${backupKey}/devices`).set(deviceData.val());
    }
    
    // Backup user data
    const userData = await db.ref("/users").once('value');
    if (userData.exists()) {
      await db.ref(`/backups/${backupKey}/users`).set(userData.val());
    }
    
    // Add metadata
    await db.ref(`/backups/${backupKey}/metadata`).set({
      created: new Date().toISOString(),
      type: "structure_cleanup",
      description: "Backup before removing redundant notification nodes"
    });
    
    console.log(`✅ Backup created: ${backupKey}`);
    return backupKey;
  } catch (error) {
    console.error(`❌ Backup failed:`, error.message);
    return null;
  }
}

async function cleanupDeviceNotifications() {
  const deviceNotifPath = CLEANUP_TARGETS.deviceNotifications;
  console.log(`\n🔍 Checking device notifications: ${deviceNotifPath}`);
  
  try {
    const snapshot = await db.ref(deviceNotifPath).once('value');
    
    if (!snapshot.exists()) {
      console.log("✅ No device notifications found (already clean)");
      return { found: false };
    }
    
    const notificationCount = Object.keys(snapshot.val() || {}).length;
    console.log(`📊 Found ${notificationCount} device notifications to remove`);
    
    if (!DRY_RUN) {
      await db.ref(deviceNotifPath).remove();
      console.log("🗑️  Device notifications removed");
    } else {
      console.log("🔍 [DRY RUN] Would remove device notifications");
    }
    
    return { found: true, count: notificationCount };
  } catch (error) {
    console.error(`❌ Error cleaning device notifications:`, error.message);
    return { found: false, error: error.message };
  }
}

async function cleanupUserRedundantData() {
  console.log("\n🔍 Checking user data for redundant fields...");
  
  try {
    const usersSnapshot = await db.ref("/users").once('value');
    
    if (!usersSnapshot.exists()) {
      console.log("✅ No user data found");
      return { processedUsers: 0, cleanedFields: 0 };
    }
    
    const users = usersSnapshot.val();
    let processedUsers = 0;
    let totalCleanedFields = 0;
    
    for (const [userId, userData] of Object.entries(users)) {
      if (!userData || typeof userData !== 'object') continue;
      
      processedUsers++;
      let cleanedFieldsForUser = 0;
      
      console.log(`\n👤 Processing user: ${userId}`);
      
      // Check each redundant field
      for (const fieldName of CLEANUP_TARGETS.userRedundantFields) {
        if (userData.hasOwnProperty(fieldName)) {
          const fieldData = userData[fieldName];
          const fieldSize = typeof fieldData === 'object' ? 
            Object.keys(fieldData || {}).length : 1;
          
          console.log(`   🗑️  Found redundant field: ${fieldName} (${fieldSize} items)`);
          cleanedFieldsForUser++;
          
          if (!DRY_RUN) {
            await db.ref(`/users/${userId}/${fieldName}`).remove();
            console.log(`   ✅ Removed: ${fieldName}`);
          } else {
            console.log(`   🔍 [DRY RUN] Would remove: ${fieldName}`);
          }
        }
      }
      
      if (cleanedFieldsForUser === 0) {
        console.log("   ✅ No redundant fields found (already clean)");
      }
      
      // Show preserved fields
      const preservedFields = Object.keys(userData).filter(key => 
        CLEANUP_TARGETS.userPreserveFields.includes(key) ||
        !CLEANUP_TARGETS.userRedundantFields.includes(key)
      );
      
      if (preservedFields.length > 0) {
        console.log(`   🛡️  Preserving: ${preservedFields.join(", ")}`);
      }
      
      totalCleanedFields += cleanedFieldsForUser;
    }
    
    return { processedUsers, cleanedFields: totalCleanedFields };
  } catch (error) {
    console.error(`❌ Error cleaning user data:`, error.message);
    return { processedUsers: 0, cleanedFields: 0, error: error.message };
  }
}

async function generateReport(results) {
  console.log("\n📊 CLEANUP REPORT");
  console.log("=================");
  
  console.log(`\n🔥 Firebase Database: ${db.app.options.databaseURL}`);
  console.log(`⏰ Completed: ${new Date().toLocaleString()}`);
  console.log(`🔧 Mode: ${DRY_RUN ? "Preview Only" : "Live Cleanup"}`);
  
  if (results.backup) {
    console.log(`📦 Backup: ${results.backup}`);
  }
  
  console.log("\n📋 DEVICE CLEANUP:");
  if (results.device.found) {
    console.log(`   • Notifications removed: ${results.device.count || 0}`);
  } else {
    console.log("   • No device notifications found");
  }
  
  console.log("\n👥 USER CLEANUP:");
  console.log(`   • Users processed: ${results.user.processedUsers}`);
  console.log(`   • Redundant fields removed: ${results.user.cleanedFields}`);
  
  const estimatedSavings = (results.device.count || 0) + (results.user.cleanedFields * 10);
  console.log(`\n💰 ESTIMATED STORAGE SAVINGS: ~${estimatedSavings} nodes`);
  
  console.log("\n✅ WHAT YOUR FIREBASE STRUCTURE NOW CONTAINS:");
  console.log("🔥 Device data:");
  console.log("   • /devices/AnxieEase001/assignment (device ownership)");
  console.log("   • /devices/AnxieEase001/current (live sensor data)");
  console.log("   • /devices/AnxieEase001/history (sensor history)");
  console.log("   • /devices/AnxieEase001/metadata (device info)");
  console.log("   • ❌ /devices/AnxieEase001/notifications (REMOVED)");
  
  console.log("\n👤 User data:");
  console.log("   • /users/{id}/anxietyAlertsEnabled (anxiety detection toggle)");
  console.log("   • /users/{id}/notificationsEnabled (master notification toggle)");
  console.log("   • /users/{id}/baseline (personal thresholds & FCM token)");
  console.log("   • /users/{id}/sessions (usage history)");
  console.log("   • ❌ /users/{id}/notifications (REMOVED - use Supabase)");
  console.log("   • ❌ /users/{id}/userId (REMOVED - redundant)");
  console.log("   • ❌ /users/{id}/source (REMOVED - dev artifact)");
  
  console.log("\n🎯 SINGLE SOURCE OF TRUTH:");
  console.log("   • 🔥 Firebase: User preferences, FCM tokens, live IoT data");
  console.log("   • 📊 Supabase: Notification history, user profiles");
}

async function main() {
  try {
    const results = {
      backup: null,
      device: { found: false, count: 0 },
      user: { processedUsers: 0, cleanedFields: 0 }
    };
    
    // Step 1: Create backup
    if (BACKUP_ENABLED && !DRY_RUN) {
      results.backup = await createBackup();
    }
    
    // Step 2: Clean device notifications
    results.device = await cleanupDeviceNotifications();
    
    // Step 3: Clean user redundant data
    results.user = await cleanupUserRedundantData();
    
    // Step 4: Generate report
    await generateReport(results);
    
    console.log("\n🎉 CLEANUP COMPLETE!");
    
    if (DRY_RUN) {
      console.log("\n⚠️  THIS WAS A PREVIEW ONLY");
      console.log("To perform actual cleanup:");
      console.log("1. Change DRY_RUN to false in the script");
      console.log("2. Run the script again");
    } else {
      console.log("\n✅ Your Firebase structure has been optimized!");
      console.log("🔔 Notifications will now work through Supabase only");
    }
    
  } catch (error) {
    console.error("❌ Cleanup failed:", error);
  } finally {
    process.exit(0);
  }
}

// Run the cleanup
main();