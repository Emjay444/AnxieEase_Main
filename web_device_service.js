import { supabase } from "./supabaseClient";

export const deviceService = {
  // Get all wearable devices
  async getAllDevices() {
    try {
      const { data, error } = await supabase
        .from("wearable_devices")
        .select(`
          *,
          assigned_user:user_id(
            id,
            first_name,
            last_name,
            email
          ),
          admin_assigned:assigned_by(
            id,
            first_name,
            last_name,
            email
          )
        `)
        .order('device_id');

      if (error) {
        throw error;
      }

      return data.map(device => ({
        ...device,
        assigned_user_name: device.assigned_user 
          ? `${device.assigned_user.first_name || ''} ${device.assigned_user.last_name || ''}`.trim()
          : null,
        admin_assigned_name: device.admin_assigned
          ? `${device.admin_assigned.first_name || ''} ${device.admin_assigned.last_name || ''}`.trim()
          : null,
      }));
    } catch (error) {
      console.error("Error fetching devices:", error);
      throw error;
    }
  },

  // Get specific device by ID
  async getDevice(deviceId) {
    try {
      const { data, error } = await supabase
        .from("wearable_devices")
        .select(`
          *,
          assigned_user:user_id(
            id,
            first_name,
            last_name,
            email
          ),
          admin_assigned:assigned_by(
            id,
            first_name,
            last_name,
            email
          )
        `)
        .eq('device_id', deviceId)
        .single();

      if (error) {
        throw error;
      }

      return {
        ...data,
        assigned_user_name: data.assigned_user 
          ? `${data.assigned_user.first_name || ''} ${data.assigned_user.last_name || ''}`.trim()
          : null,
        admin_assigned_name: data.admin_assigned
          ? `${data.admin_assigned.first_name || ''} ${data.admin_assigned.last_name || ''}`.trim()
          : null,
      };
    } catch (error) {
      console.error("Error fetching device:", error);
      throw error;
    }
  },

  // Assign device to user using the database function
  async assignDeviceToUser(deviceId, userId, expiresAt, adminNotes = null) {
    try {
      // Get current user as admin
      const { data: currentUser } = await supabase.auth.getUser();
      if (!currentUser?.user?.id) {
        throw new Error("No authenticated admin user");
      }

      // Call the database function
      const { data, error } = await supabase
        .rpc('assign_device_to_user', {
          device_id: deviceId,
          user_id: userId,
          expires_at: expiresAt,
          admin_notes: adminNotes
        });

      if (error) {
        throw error;
      }

      return data;
    } catch (error) {
      console.error("Error assigning device:", error);
      throw error;
    }
  },

  // Release device assignment using the database function
  async releaseDeviceAssignment(deviceId) {
    try {
      const { data, error } = await supabase
        .rpc('release_device_assignment', {
          device_id: deviceId
        });

      if (error) {
        throw error;
      }

      return data;
    } catch (error) {
      console.error("Error releasing device:", error);
      throw error;
    }
  },

  // Update session status using the database function
  async updateSessionStatus(deviceId, sessionStatus, sessionNotes = null) {
    try {
      const { data, error } = await supabase
        .rpc('update_session_status', {
          device_id: deviceId,
          session_status: sessionStatus,
          session_notes: sessionNotes
        });

      if (error) {
        throw error;
      }

      return data;
    } catch (error) {
      console.error("Error updating session status:", error);
      throw error;
    }
  },

  // Get all available patients for assignment (unassigned to any device)
  async getAvailablePatients() {
    try {
      // Get all patients who don't currently have a device assigned
      const { data: patients, error } = await supabase
        .from("user_profiles")
        .select("id, first_name, last_name, email")
        .or("role.eq.patient,role.is.null,role.eq.")
        .not('id', 'in', 
          supabase
            .from('wearable_devices')
            .select('user_id')
            .not('user_id', 'is', null)
        );

      if (error) {
        throw error;
      }

      return patients.map(patient => ({
        ...patient,
        name: `${patient.first_name || ''} ${patient.last_name || ''}`.trim() || 'Unknown',
      }));
    } catch (error) {
      console.error("Error fetching available patients:", error);
      throw error;
    }
  },

  // Update device metadata (battery, last seen, etc.)
  async updateDeviceMetadata(deviceId, updates) {
    try {
      const { data, error } = await supabase
        .from("wearable_devices")
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq('device_id', deviceId)
        .select();

      if (error) {
        throw error;
      }

      return data[0];
    } catch (error) {
      console.error("Error updating device metadata:", error);
      throw error;
    }
  },

  // Get device assignment history
  async getDeviceHistory(deviceId) {
    try {
      // Note: This would require a separate assignment_history table
      // For now, we'll just return the current assignment data
      const device = await this.getDevice(deviceId);
      return device ? [device] : [];
    } catch (error) {
      console.error("Error fetching device history:", error);
      throw error;
    }
  },

  // Get device usage statistics
  async getDeviceStats() {
    try {
      const { data, error } = await supabase
        .from("wearable_devices")
        .select("device_id, assignment_status, session_status");

      if (error) {
        throw error;
      }

      const stats = {
        total: data.length,
        available: data.filter(d => d.assignment_status === 'available').length,
        assigned: data.filter(d => d.assignment_status === 'assigned').length,
        active: data.filter(d => d.assignment_status === 'active').length,
        completed: data.filter(d => d.assignment_status === 'completed').length,
        sessions: {
          idle: data.filter(d => d.session_status === 'idle').length,
          pending: data.filter(d => d.session_status === 'pending').length,
          in_progress: data.filter(d => d.session_status === 'in_progress').length,
          completed: data.filter(d => d.session_status === 'completed').length,
        }
      };

      return stats;
    } catch (error) {
      console.error("Error fetching device stats:", error);
      return {
        total: 0,
        available: 0,
        assigned: 0,
        active: 0,
        completed: 0,
        sessions: { idle: 0, pending: 0, in_progress: 0, completed: 0 }
      };
    }
  }
};