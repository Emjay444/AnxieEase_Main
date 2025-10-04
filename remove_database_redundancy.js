const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('./service-account-key.json'),
    databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
  });
}

const db = admin.database();

/**
 * STEP 1: Backup current database structure before removing redundancy
 */
async function backupDatabase() {
  console.log('🔒 Creating backup of current database structure...');
  
  try {
    // Backup device_assignments node
    const deviceAssignmentsRef = db.ref('/device_assignments');
    const deviceAssignmentsSnapshot = await deviceAssignmentsRef.once('value');
    const deviceAssignmentsData = deviceAssignmentsSnapshot.val();
    
    // Backup sensorData node
    const sensorDataRef = db.ref('/sensorData');
    const sensorDataSnapshot = await sensorDataRef.once('value');
    const sensorDataData = sensorDataSnapshot.val();
    
    // Backup devices metadata (to see what we're removing)
    const devicesRef = db.ref('/devices');
    const devicesSnapshot = await devicesRef.once('value');
    const devicesData = devicesSnapshot.val();
    
    // Create backup object
    const backup = {
      timestamp: new Date().toISOString(),
      device_assignments: deviceAssignmentsData,
      sensorData: sensorDataData,
      devices_metadata: {}
    };
    
    // Extract metadata for backup
    if (devicesData) {
      Object.keys(devicesData).forEach(deviceId => {
        if (devicesData[deviceId].metadata) {
          backup.devices_metadata[deviceId] = devicesData[deviceId].metadata;
        }
      });
    }
    
    // Store backup in Firebase
    const backupRef = db.ref('/system/backups/redundancy_removal_backup');
    await backupRef.set(backup);
    
    console.log('✅ Backup created successfully at /system/backups/redundancy_removal_backup');
    console.log(`📊 Backup contains:`);
    console.log(`   - device_assignments: ${deviceAssignmentsData ? Object.keys(deviceAssignmentsData).length : 0} devices`);
    console.log(`   - sensorData: ${sensorDataData ? Object.keys(sensorDataData).length : 0} devices`);
    console.log(`   - devices_metadata: ${Object.keys(backup.devices_metadata).length} devices`);
    
    return backup;
  } catch (error) {
    console.error('❌ Error creating backup:', error);
    throw error;
  }
}

/**
 * STEP 2: Remove redundant device_assignments node
 */
async function removeDeviceAssignments() {
  console.log('🗑️ Removing redundant device_assignments node...');
  
  try {
    const deviceAssignmentsRef = db.ref('/device_assignments');
    await deviceAssignmentsRef.remove();
    console.log('✅ device_assignments node removed successfully');
  } catch (error) {
    console.error('❌ Error removing device_assignments:', error);
    throw error;
  }
}

/**
 * STEP 3: Remove redundant sensorData node
 */
async function removeSensorData() {
  console.log('🗑️ Removing redundant sensorData node...');
  
  try {
    const sensorDataRef = db.ref('/sensorData');
    await sensorDataRef.remove();
    console.log('✅ sensorData node removed successfully');
  } catch (error) {
    console.error('❌ Error removing sensorData:', error);
    throw error;
  }
}

/**
 * STEP 4: Remove redundant fields from devices metadata
 */
async function cleanupDevicesMetadata() {
  console.log('🧹 Cleaning up redundant fields in devices metadata...');
  
  try {
    const devicesRef = db.ref('/devices');
    const devicesSnapshot = await devicesRef.once('value');
    const devicesData = devicesSnapshot.val();
    
    if (!devicesData) {
      console.log('ℹ️ No devices found to clean up');
      return;
    }
    
    let cleanedDevices = 0;
    
    for (const deviceId of Object.keys(devicesData)) {
      const device = devicesData[deviceId];
      
      if (device.metadata) {
        const metadataRef = db.ref(`/devices/${deviceId}/metadata`);
        const updates = {};
        
        // Remove redundant fields from metadata
        if (device.metadata.assignedUser !== undefined) {
          updates.assignedUser = null;
          console.log(`   Removing assignedUser from ${deviceId} metadata`);
        }
        
        if (device.metadata.userId !== undefined) {
          updates.userId = null;
          console.log(`   Removing userId from ${deviceId} metadata`);
        }
        
        if (Object.keys(updates).length > 0) {
          await metadataRef.update(updates);
          cleanedDevices++;
        }
      }
    }
    
    console.log(`✅ Cleaned up metadata for ${cleanedDevices} devices`);
  } catch (error) {
    console.error('❌ Error cleaning up devices metadata:', error);
    throw error;
  }
}

/**
 * STEP 5: Verify cleanup and show final structure
 */
async function verifyCleanup() {
  console.log('🔍 Verifying cleanup results...');
  
  try {
    // Check if redundant nodes are gone
    const deviceAssignmentsSnapshot = await db.ref('/device_assignments').once('value');
    const sensorDataSnapshot = await db.ref('/sensorData').once('value');
    
    console.log(`📊 Cleanup verification:`);
    console.log(`   - device_assignments exists: ${deviceAssignmentsSnapshot.exists()}`);
    console.log(`   - sensorData exists: ${sensorDataSnapshot.exists()}`);
    
    // Show remaining structure
    const rootSnapshot = await db.ref('/').once('value');
    const rootData = rootSnapshot.val();
    
    console.log(`📋 Remaining top-level nodes:`);
    if (rootData) {
      Object.keys(rootData).forEach(node => {
        console.log(`   - ${node}`);
      });
    }
    
    // Check devices structure
    const devicesSnapshot = await db.ref('/devices').once('value');
    const devicesData = devicesSnapshot.val();
    
    if (devicesData) {
      console.log(`📱 Devices structure:`);
      Object.keys(devicesData).forEach(deviceId => {
        const device = devicesData[deviceId];
        console.log(`   ${deviceId}:`);
        if (device.assignment) console.log(`     ✅ assignment/`);
        if (device.history) console.log(`     ✅ history/`);
        if (device.metadata) console.log(`     ✅ metadata/`);
        if (device.supabaseSync) console.log(`     ✅ supabaseSync/`);
      });
    }
    
    console.log('✅ Cleanup verification complete');
  } catch (error) {
    console.error('❌ Error during verification:', error);
    throw error;
  }
}

/**
 * Main cleanup function
 */
async function removeRedundancy() {
  console.log('🚀 Starting Firebase database redundancy removal...');
  console.log('⚠️  This will remove redundant nodes: device_assignments, sensorData');
  console.log('⚠️  And clean up redundant metadata fields');
  console.log('');
  
  try {
    // Step 1: Create backup
    await backupDatabase();
    console.log('');
    
    // Step 2: Remove device_assignments node
    await removeDeviceAssignments();
    console.log('');
    
    // Step 3: Remove sensorData node
    await removeSensorData();
    console.log('');
    
    // Step 4: Clean up metadata
    await cleanupDevicesMetadata();
    console.log('');
    
    // Step 5: Verify cleanup
    await verifyCleanup();
    console.log('');
    
    console.log('🎉 Database redundancy removal completed successfully!');
    console.log('📊 Expected storage reduction: 50-70%');
    console.log('🔒 Backup available at: /system/backups/redundancy_removal_backup');
    
  } catch (error) {
    console.error('❌ Redundancy removal failed:', error);
    console.log('🔒 Database backup is available for recovery if needed');
    process.exit(1);
  }
}

// Run the cleanup if this script is executed directly
if (require.main === module) {
  removeRedundancy().then(() => {
    console.log('✅ Script completed');
    process.exit(0);
  }).catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
}

module.exports = {
  removeRedundancy,
  backupDatabase,
  removeDeviceAssignments,
  removeSensorData,
  cleanupDevicesMetadata,
  verifyCleanup
};