/**
 * 🔄 MANUAL SYNC: Supabase → Firebase
 * 
 * Use this when you change device assignment in Supabase admin panel
 * and need to sync Firebase immediately
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

async function manualSyncFromSupabase() {
  console.log("\n🔄 MANUAL SYNC: Supabase → Firebase");
  console.log("====================================");
  
  try {
    // Based on your Supabase screenshot:
    const CURRENT_SUPABASE_ASSIGNMENT = {
      device_id: "AnxieEase001",
      user_id: "5efad7d4-3dcd-4333-ba4b-4f68c14a4f86", // Current user from Supabase
      baseline_hr: 73.2,
      is_active: true,
      linked_at: "2025-09-24 23:05:08.79+00",
      battery_level: 18
    };
    
    console.log("📊 Current Supabase Assignment:");
    console.log(`   Device: ${CURRENT_SUPABASE_ASSIGNMENT.device_id}`);
    console.log(`   User: ${CURRENT_SUPABASE_ASSIGNMENT.user_id}`);
    console.log(`   Baseline: ${CURRENT_SUPABASE_ASSIGNMENT.baseline_hr} BPM`);
    console.log(`   Active: ${CURRENT_SUPABASE_ASSIGNMENT.is_active}`);
    
    // Check current Firebase assignment
    const currentFirebaseRef = db.ref(`/devices/${CURRENT_SUPABASE_ASSIGNMENT.device_id}/assignment`);
    const currentSnapshot = await currentFirebaseRef.once('value');
    const currentFirebase = currentSnapshot.val();
    
    console.log("\n🔍 Current Firebase Assignment:");
    if (currentFirebase) {
      console.log(`   User: ${currentFirebase.assignedUser}`);
      console.log(`   Session: ${currentFirebase.activeSessionId}`);
      console.log(`   Status: ${currentFirebase.status}`);
      console.log(`   Last Updated: ${new Date(currentFirebase.assignedAt).toLocaleString()}`);
    } else {
      console.log("   No assignment found");
    }
    
    // Check if sync is needed
    const needsSync = !currentFirebase || 
                     currentFirebase.assignedUser !== CURRENT_SUPABASE_ASSIGNMENT.user_id;
    
    if (!needsSync) {
      console.log("\n✅ Already in sync! Firebase matches Supabase.");
      console.log(`   Both have user: ${CURRENT_SUPABASE_ASSIGNMENT.user_id}`);
      return;
    }
    
    console.log("\n🔄 Syncing Firebase with Supabase...");
    console.log("MISMATCH DETECTED:");
    console.log(`   Supabase User: ${CURRENT_SUPABASE_ASSIGNMENT.user_id}`);
    console.log(`   Firebase User: ${currentFirebase ? currentFirebase.assignedUser : 'None'}`);
    
    // Perform the sync
    const newSessionId = `session_${Date.now()}`;
    
    const newAssignment = {
      assignedUser: CURRENT_SUPABASE_ASSIGNMENT.user_id,
      activeSessionId: newSessionId,
      deviceId: CURRENT_SUPABASE_ASSIGNMENT.device_id,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: CURRENT_SUPABASE_ASSIGNMENT.is_active ? "active" : "inactive",
      assignedBy: "manual_admin_sync",
      supabaseSync: {
        syncedAt: admin.database.ServerValue.TIMESTAMP,
        baselineHR: CURRENT_SUPABASE_ASSIGNMENT.baseline_hr,
        linkedAt: CURRENT_SUPABASE_ASSIGNMENT.linked_at,
        batteryLevel: CURRENT_SUPABASE_ASSIGNMENT.battery_level,
        manualSync: true
      },
      previousAssignment: currentFirebase
    };
    
    await currentFirebaseRef.set(newAssignment);
    
    console.log("✅ Firebase assignment updated!");
    
    // Update user baseline
    await db.ref(`/users/${CURRENT_SUPABASE_ASSIGNMENT.user_id}/baseline`).set({
      heartRate: CURRENT_SUPABASE_ASSIGNMENT.baseline_hr,
      timestamp: Date.now(),
      source: "manual_supabase_sync",
      deviceId: CURRENT_SUPABASE_ASSIGNMENT.device_id
    });
    
    console.log(`✅ User baseline synced: ${CURRENT_SUPABASE_ASSIGNMENT.baseline_hr} BPM`);
    
    // Initialize new user session
    await db.ref(`/users/${CURRENT_SUPABASE_ASSIGNMENT.user_id}/sessions/${newSessionId}/metadata`).set({
      deviceId: CURRENT_SUPABASE_ASSIGNMENT.device_id,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      source: "manual_admin_sync",
      baselineHR: CURRENT_SUPABASE_ASSIGNMENT.baseline_hr
    });
    
    console.log("✅ New user session initialized");
    
    // Clean up old user session
    if (currentFirebase && 
        currentFirebase.assignedUser !== CURRENT_SUPABASE_ASSIGNMENT.user_id) {
      
      const oldUserId = currentFirebase.assignedUser;
      const oldSessionId = currentFirebase.activeSessionId;
      
      if (oldSessionId) {
        await db.ref(`/users/${oldUserId}/sessions/${oldSessionId}/metadata`).update({
          status: "ended",
          endTime: admin.database.ServerValue.TIMESTAMP,
          endReason: "manual_device_reassignment"
        });
        
        console.log(`✅ Previous user session ended: ${oldUserId}`);
      }
    }
    
    console.log("\n🎉 MANUAL SYNC COMPLETE!");
    console.log("=========================");
    console.log(`✅ Device: ${CURRENT_SUPABASE_ASSIGNMENT.device_id}`);
    console.log(`✅ New User: ${CURRENT_SUPABASE_ASSIGNMENT.user_id}`);
    console.log(`✅ Baseline: ${CURRENT_SUPABASE_ASSIGNMENT.baseline_hr} BPM`);
    console.log(`✅ Session: ${newSessionId}`);
    console.log("✅ Firebase now matches Supabase!");
    
    console.log("\n📱 READY FOR:");
    console.log("==============");
    console.log("✅ Anxiety detection with new user");
    console.log("✅ Push notifications to correct user");
    console.log("✅ Real-time heart rate monitoring");
    
  } catch (error) {
    console.error("❌ Manual sync failed:", error.message);
  }
}

console.log("🚀 Running manual sync to match current Supabase assignment...");
manualSyncFromSupabase();