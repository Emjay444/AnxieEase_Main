const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Supabase client
const supabase = createClient(
  functions.config().supabase.url,
  functions.config().supabase.service_key
);

/**
 * Sync device sessions from Firebase to Supabase
 * Triggered when device session data changes in Firebase
 */
exports.syncDeviceSession = functions.database.ref('/device_sessions/{deviceId}')
  .onWrite(async (change, context) => {
    const deviceId = context.params.deviceId;
    const sessionData = change.after.val();
    
    console.log(`Syncing device session for ${deviceId}`);
    
    try {
      if (sessionData) {
        // Update or insert session data in Supabase
        const { error } = await supabase
          .from('device_sessions')
          .upsert({
            device_id: deviceId,
            user_id: sessionData.userId,
            session_status: sessionData.status || 'active',
            start_time: new Date(sessionData.startTime || Date.now()).toISOString(),
            last_updated: new Date().toISOString(),
            firebase_path: `/device_sessions/${deviceId}`,
            assigned_via_admin: sessionData.assignedViaAdmin || false
          });
        
        if (error) {
          console.error('Supabase sync error:', error);
          return;
        }
        
        // Update device status in Supabase
        await supabase
          .from('wearable_devices')
          .update({
            status: sessionData.status === 'active' ? 'assigned' : 'available',
            last_seen: new Date().toISOString()
          })
          .eq('device_id', deviceId);
        
        console.log(`Successfully synced session for ${deviceId}`);
      } else {
        // Session was deleted, mark as available
        await supabase
          .from('device_sessions')
          .delete()
          .eq('device_id', deviceId);
        
        await supabase
          .from('wearable_devices')
          .update({
            status: 'available',
            user_id: null
          })
          .eq('device_id', deviceId);
        
        console.log(`Session deleted for ${deviceId}`);
      }
    } catch (error) {
      console.error('Error syncing device session:', error);
    }
  });

/**
 * Sync sensor data from Firebase to Supabase for analytics
 * Triggered when new sensor data is added
 */
exports.syncSensorData = functions.database.ref('/device_sessions/{deviceId}/sensorData/{timestamp}')
  .onCreate(async (snapshot, context) => {
    const deviceId = context.params.deviceId;
    const timestamp = context.params.timestamp;
    const sensorData = snapshot.val();
    
    try {
      // Store aggregated sensor data in Supabase for analytics
      const { error } = await supabase
        .from('sensor_data_analytics')
        .insert({
          device_id: deviceId,
          timestamp: new Date(parseInt(timestamp)).toISOString(),
          heart_rate: sensorData.heartRate,
          skin_conductance: sensorData.skinConductance,
          body_temperature: sensorData.bodyTemperature,
          accelerometer_x: sensorData.accelerometer?.x,
          accelerometer_y: sensorData.accelerometer?.y,
          accelerometer_z: sensorData.accelerometer?.z,
          created_at: new Date().toISOString()
        });
      
      if (error) {
        console.error('Error storing sensor data:', error);
      }
    } catch (error) {
      console.error('Error syncing sensor data:', error);
    }
  });

/**
 * Handle user assignment from web admin
 * Called from web dashboard to assign/unassign devices
 */
exports.syncUserAssignment = functions.https.onCall(async (data, context) => {
  const { deviceId, userId, action } = data;
  
  console.log(`User assignment request: ${action} device ${deviceId} to user ${userId}`);
  
  try {
    if (action === 'assign') {
      // Create Firebase user session
      await admin.database().ref(`/device_sessions/${deviceId}`).set({
        userId: userId,
        startTime: admin.database.ServerValue.TIMESTAMP,
        status: 'active',
        assignedViaAdmin: true,
        assignedAt: admin.database.ServerValue.TIMESTAMP
      });
      
      // Create/update user record in Firebase
      await admin.database().ref(`/users/${userId}`).update({
        deviceId: deviceId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        assignmentSource: 'admin'
      });
      
      // Update Supabase device assignment
      await supabase
        .from('wearable_devices')
        .update({
          user_id: userId,
          status: 'assigned',
          linked_at: new Date().toISOString()
        })
        .eq('device_id', deviceId);
      
      console.log(`Successfully assigned device ${deviceId} to user ${userId}`);
      
    } else if (action === 'unassign') {
      // Update Firebase session status
      await admin.database().ref(`/device_sessions/${deviceId}/status`).set('completed');
      
      // Remove user device assignment
      await admin.database().ref(`/users/${userId}/deviceId`).remove();
      
      // Update Supabase
      await supabase
        .from('wearable_devices')
        .update({
          user_id: null,
          status: 'available',
          linked_at: null
        })
        .eq('device_id', deviceId);
      
      console.log(`Successfully unassigned device ${deviceId} from user ${userId}`);
    }
    
    return { success: true, message: `Device ${action} successful` };
    
  } catch (error) {
    console.error('Error in user assignment:', error);
    throw new functions.https.HttpsError('internal', 'Assignment failed', error.message);
  }
});

/**
 * Get real-time device statistics
 * Called from web dashboard for live stats
 */
exports.getDeviceStats = functions.https.onCall(async (data, context) => {
  try {
    // Get active sessions from Firebase
    const sessionsSnapshot = await admin.database().ref('/device_sessions').once('value');
    const sessions = sessionsSnapshot.val() || {};
    
    const activeSessions = Object.values(sessions).filter(session => session.status === 'active').length;
    
    // Get device info from Supabase
    const { data: devices, error } = await supabase
      .from('wearable_devices')
      .select('*');
    
    if (error) throw error;
    
    const stats = {
      totalDevices: devices.length,
      activeDevices: activeSessions,
      availableDevices: devices.filter(d => d.status === 'available').length,
      assignedDevices: devices.filter(d => d.status === 'assigned').length,
      lastUpdated: new Date().toISOString()
    };
    
    return stats;
    
  } catch (error) {
    console.error('Error getting device stats:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get stats', error.message);
  }
});

/**
 * Monitor device health and send alerts
 * Runs every 5 minutes to check device status
 */
exports.monitorDeviceHealth = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  try {
    const sessionsSnapshot = await admin.database().ref('/device_sessions').once('value');
    const sessions = sessionsSnapshot.val() || {};
    
    const alerts = [];
    
    for (const [deviceId, session] of Object.entries(sessions)) {
      if (session.status === 'active') {
        // Check last sensor data timestamp
        const lastDataSnapshot = await admin.database()
          .ref(`/device_sessions/${deviceId}/sensorData`)
          .orderByKey()
          .limitToLast(1)
          .once('value');
        
        const lastData = lastDataSnapshot.val();
        if (lastData) {
          const lastTimestamp = Math.max(...Object.keys(lastData).map(Number));
          const timeSinceLastData = Date.now() - lastTimestamp;
          
          // Alert if no data for more than 10 minutes
          if (timeSinceLastData > 10 * 60 * 1000) {
            alerts.push({
              device_id: deviceId,
              user_id: session.userId,
              alert_type: 'no_data',
              message: `No sensor data received for ${Math.round(timeSinceLastData / 60000)} minutes`,
              created_at: new Date().toISOString()
            });
          }
        }
      }
    }
    
    // Store alerts in Supabase
    if (alerts.length > 0) {
      await supabase.from('device_alerts').insert(alerts);
      console.log(`Generated ${alerts.length} device alerts`);
    }
    
  } catch (error) {
    console.error('Error monitoring device health:', error);
  }
});

/**
 * Handle emergency alerts from devices
 * Triggered when emergency flag is set in Firebase
 */
exports.handleEmergencyAlert = functions.database.ref('/emergency_alerts/{deviceId}')
  .onCreate(async (snapshot, context) => {
    const deviceId = context.params.deviceId;
    const alertData = snapshot.val();
    
    try {
      // Get user info from device session
      const sessionSnapshot = await admin.database().ref(`/device_sessions/${deviceId}`).once('value');
      const session = sessionSnapshot.val();
      
      if (session && session.userId) {
        // Store emergency alert in Supabase
        await supabase.from('emergency_alerts').insert({
          device_id: deviceId,
          user_id: session.userId,
          alert_type: alertData.type || 'emergency',
          sensor_data: alertData.sensorData,
          location: alertData.location,
          created_at: new Date().toISOString(),
          status: 'active'
        });
        
        // TODO: Send notifications to emergency contacts
        console.log(`Emergency alert created for device ${deviceId}, user ${session.userId}`);
      }
      
    } catch (error) {
      console.error('Error handling emergency alert:', error);
    }
  });