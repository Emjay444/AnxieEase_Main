import { createClient } from '@supabase/supabase-js';
import { initializeApp } from 'firebase/app';
import { getDatabase, ref, onValue, off, get } from 'firebase/database';
import { getFunctions, httpsCallable } from 'firebase/functions';

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDXYK-zH5k9KrYWmemzrDVNkg_sUlm6wgM",
  authDomain: "anxieease-sensors.firebaseapp.com",
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "anxieease-sensors",
  storageBucket: "anxieease-sensors.appspot.com",
  messagingSenderId: "915581332814",
  appId: "1:915581332814:web:b4cffd7766616464c6c21f"
};

// Supabase configuration
const supabaseUrl = process.env.REACT_APP_SUPABASE_URL;
const supabaseAnonKey = process.env.REACT_APP_SUPABASE_ANON_KEY;

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const database = getDatabase(app);
const functions = getFunctions(app);

// Initialize Supabase
const supabase = createClient(supabaseUrl, supabaseAnonKey);

class UnifiedDeviceService {
  constructor() {
    this.syncUserAssignment = httpsCallable(functions, 'syncUserAssignment');
    this.getDeviceStats = httpsCallable(functions, 'getDeviceStats');
    this.subscriptions = new Map();
  }

  /**
   * Get comprehensive device information from Supabase with real-time Firebase status
   */
  async getDeviceInfo(deviceId) {
    try {
      // Get device info from Supabase
      const { data: device, error } = await supabase
        .from('wearable_devices')
        .select(`
          *,
          user_profiles (
            id,
            first_name,
            last_name,
            email,
            role
          )
        `)
        .eq('device_id', deviceId)
        .single();
      
      if (error) throw error;

      // Get real-time status from Firebase
      const sessionRef = ref(database, `device_sessions/${deviceId}`);
      const sessionSnapshot = await get(sessionRef);
      const sessionData = sessionSnapshot.val();

      return {
        ...device,
        firebase_status: sessionData?.status || 'offline',
        firebase_start_time: sessionData?.startTime,
        firebase_user_id: sessionData?.userId,
        last_sensor_data: sessionData?.lastSensorUpdate,
        is_real_time_active: !!sessionData
      };
    } catch (error) {
      console.error('Error getting device info:', error);
      throw error;
    }
  }

  /**
   * Get all devices with combined Supabase and Firebase data
   */
  async getAllDevices() {
    try {
      const { data: devices, error } = await supabase
        .from('wearable_devices')
        .select(`
          *,
          user_profiles (
            id,
            first_name,
            last_name,
            email,
            role
          )
        `)
        .order('device_id');
      
      if (error) throw error;

      // Enhance with Firebase data
      const enhancedDevices = await Promise.all(
        devices.map(async (device) => {
          const sessionRef = ref(database, `device_sessions/${device.device_id}`);
          const sessionSnapshot = await get(sessionRef);
          const sessionData = sessionSnapshot.val();

          return {
            ...device,
            firebase_status: sessionData?.status || 'offline',
            firebase_start_time: sessionData?.startTime,
            firebase_user_id: sessionData?.userId,
            is_real_time_active: !!sessionData,
            assigned_user_name: device.user_profiles 
              ? `${device.user_profiles.first_name} ${device.user_profiles.last_name}`
              : null
          };
        })
      );

      return enhancedDevices;
    } catch (error) {
      console.error('Error getting all devices:', error);
      throw error;
    }
  }

  /**
   * Get available patients for device assignment
   */
  async getAvailablePatients() {
    try {
      const { data: patients, error } = await supabase
        .from('user_profiles')
        .select('id, first_name, last_name, email')
        .eq('role', 'patient')
        .is('deleted_at', null)
        .order('first_name');
      
      if (error) throw error;

      return patients.map(patient => ({
        id: patient.id,
        name: `${patient.first_name} ${patient.last_name}`,
        email: patient.email
      }));
    } catch (error) {
      console.error('Error getting available patients:', error);
      throw error;
    }
  }

  /**
   * Assign device to user with Firebase sync
   */
  async assignDeviceToUser(deviceId, userId, expiresAt = null, adminNotes = '') {
    try {
      // Update Supabase first
      const { error: supabaseError } = await supabase
        .from('wearable_devices')
        .update({
          user_id: userId,
          linked_at: new Date().toISOString(),
          status: 'assigned',
          expires_at: expiresAt,
          admin_notes: adminNotes
        })
        .eq('device_id', deviceId);
      
      if (supabaseError) throw supabaseError;

      // Log assignment activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: null, // TODO: Get current admin ID
        action_type: 'device_assignment',
        details: `Assigned device ${deviceId} to user ${userId}`,
        created_at: new Date().toISOString()
      });

      // Sync with Firebase via Cloud Function
      const result = await this.syncUserAssignment({
        deviceId,
        userId,
        action: 'assign'
      });

      return result.data;
    } catch (error) {
      console.error('Assignment failed:', error);
      throw error;
    }
  }

  /**
   * Release device assignment
   */
  async releaseDeviceAssignment(deviceId) {
    try {
      // Get current assignment info
      const device = await this.getDeviceInfo(deviceId);
      const userId = device.user_id;

      // Update Supabase
      const { error: supabaseError } = await supabase
        .from('wearable_devices')
        .update({
          user_id: null,
          linked_at: null,
          status: 'available',
          expires_at: null,
          admin_notes: null
        })
        .eq('device_id', deviceId);
      
      if (supabaseError) throw supabaseError;

      // Log release activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: null, // TODO: Get current admin ID
        action_type: 'device_release',
        details: `Released device ${deviceId} from user ${userId}`,
        created_at: new Date().toISOString()
      });

      // Sync with Firebase
      if (userId) {
        const result = await this.syncUserAssignment({
          deviceId,
          userId,
          action: 'unassign'
        });
        return result.data;
      }
    } catch (error) {
      console.error('Release failed:', error);
      throw error;
    }
  }

  /**
   * Get device statistics from Firebase Cloud Function
   */
  async getDeviceStatistics() {
    try {
      const result = await this.getDeviceStats();
      return result.data;
    } catch (error) {
      console.error('Error getting device statistics:', error);
      // Fallback to Supabase-only stats
      return this.getSupabaseStats();
    }
  }

  /**
   * Fallback statistics from Supabase only
   */
  async getSupabaseStats() {
    try {
      const { data: devices, error } = await supabase
        .from('wearable_devices')
        .select('status');
      
      if (error) throw error;

      return {
        totalDevices: devices.length,
        availableDevices: devices.filter(d => d.status === 'available').length,
        assignedDevices: devices.filter(d => d.status === 'assigned').length,
        activeDevices: 0, // Can't determine from Supabase alone
        lastUpdated: new Date().toISOString()
      };
    } catch (error) {
      console.error('Error getting Supabase stats:', error);
      throw error;
    }
  }

  /**
   * Subscribe to real-time sensor data for a device
   */
  subscribeToDeviceData(deviceId, callback) {
    const sensorDataRef = ref(database, `device_sessions/${deviceId}/sensorData`);
    
    const unsubscribe = onValue(sensorDataRef, (snapshot) => {
      const data = snapshot.val();
      if (data) {
        // Get the latest sensor reading
        const timestamps = Object.keys(data).sort((a, b) => b - a);
        const latestData = timestamps.length > 0 ? data[timestamps[0]] : null;
        callback(latestData);
      } else {
        callback(null);
      }
    });

    // Store subscription for cleanup
    this.subscriptions.set(`sensor_${deviceId}`, unsubscribe);
    
    return () => {
      off(sensorDataRef);
      this.subscriptions.delete(`sensor_${deviceId}`);
    };
  }

  /**
   * Subscribe to real-time device status
   */
  subscribeToDeviceStatus(deviceId, callback) {
    const statusRef = ref(database, `device_sessions/${deviceId}/status`);
    
    const unsubscribe = onValue(statusRef, (snapshot) => {
      const status = snapshot.val();
      callback(status || 'offline');
    });

    this.subscriptions.set(`status_${deviceId}`, unsubscribe);
    
    return () => {
      off(statusRef);
      this.subscriptions.delete(`status_${deviceId}`);
    };
  }

  /**
   * Subscribe to all active device sessions
   */
  subscribeToAllDeviceSessions(callback) {
    const sessionsRef = ref(database, 'device_sessions');
    
    const unsubscribe = onValue(sessionsRef, (snapshot) => {
      const sessions = snapshot.val() || {};
      callback(sessions);
    });

    this.subscriptions.set('all_sessions', unsubscribe);
    
    return () => {
      off(sessionsRef);
      this.subscriptions.delete('all_sessions');
    };
  }

  /**
   * Get sensor data history for analytics
   */
  async getSensorDataHistory(deviceId, startDate, endDate) {
    try {
      const { data, error } = await supabase
        .from('sensor_data_analytics')
        .select('*')
        .eq('device_id', deviceId)
        .gte('timestamp', startDate)
        .lte('timestamp', endDate)
        .order('timestamp', { ascending: true });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error getting sensor data history:', error);
      throw error;
    }
  }

  /**
   * Get device alerts
   */
  async getDeviceAlerts(deviceId = null) {
    try {
      let query = supabase
        .from('device_alerts')
        .select(`
          *,
          wearable_devices (device_id),
          user_profiles (first_name, last_name, email)
        `)
        .order('created_at', { ascending: false })
        .limit(50);
      
      if (deviceId) {
        query = query.eq('device_id', deviceId);
      }
      
      const { data, error } = await query;
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error getting device alerts:', error);
      throw error;
    }
  }

  /**
   * Cleanup all subscriptions
   */
  cleanup() {
    this.subscriptions.forEach((unsubscribe) => {
      if (typeof unsubscribe === 'function') {
        unsubscribe();
      }
    });
    this.subscriptions.clear();
  }
}

// Export singleton instance
export const unifiedDeviceService = new UnifiedDeviceService();
export default unifiedDeviceService;