// React component for admin device management
// Add this to your existing React admin dashboard

import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient'; // Your existing Supabase client

const DeviceManagement = () => {
  const [users, setUsers] = useState([]);
  const [deviceStatus, setDeviceStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedUser, setSelectedUser] = useState('');
  const [expiresIn, setExpiresIn] = useState('2'); // Default 2 hours
  const [adminNotes, setAdminNotes] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      // Load users (patients)
      const { data: usersData } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .order('full_name');

      // Load current device status
      const { data: deviceData } = await supabase
        .from('wearable_devices')
        .select('*')
        .eq('device_id', 'AnxieEase001')
        .single();

      setUsers(usersData || []);
      setDeviceStatus(deviceData);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const assignDevice = async () => {
    if (!selectedUser) {
      alert('Please select a user');
      return;
    }

    try {
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + parseInt(expiresIn));

      const { error } = await supabase.rpc('assign_device_to_user', {
        p_device_id: 'AnxieEase001',
        p_user_id: selectedUser,
        p_expires_at: expiresAt.toISOString(),
        p_admin_notes: adminNotes || null
      });

      if (error) throw error;

      alert('Device assigned successfully!');
      setSelectedUser('');
      setAdminNotes('');
      loadData();
    } catch (error) {
      console.error('Error assigning device:', error);
      alert('Error assigning device: ' + error.message);
    }
  };

  const releaseDevice = async () => {
    try {
      const { error } = await supabase.rpc('release_device_assignment', {
        p_device_id: 'AnxieEase001'
      });

      if (error) throw error;

      alert('Device released successfully!');
      loadData();
    } catch (error) {
      console.error('Error releasing device:', error);
      alert('Error releasing device: ' + error.message);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'assigned': return 'bg-blue-100 text-blue-800';
      case 'active': return 'bg-green-100 text-green-800';
      case 'completed': return 'bg-gray-100 text-gray-800';
      case 'available': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getCurrentUser = () => {
    if (!deviceStatus?.user_id) return null;
    return users.find(user => user.id === deviceStatus.user_id);
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">AnxieEase Device Management</h1>

      {/* Device Assignment Form */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <h2 className="text-lg font-semibold mb-4">
          Device Status: AnxieEase001
          <span className={`ml-2 px-2 py-1 rounded-full text-xs ${getStatusColor(deviceStatus?.assignment_status)}`}>
            {deviceStatus?.assignment_status || 'available'}
          </span>
        </h2>

        {/* Current Assignment Info */}
        {deviceStatus?.user_id && (
          <div className="bg-blue-50 p-4 rounded-md mb-4">
            <h3 className="font-medium text-blue-900 mb-2">Currently Assigned To:</h3>
            <div className="text-blue-800">
              <p><strong>User:</strong> {getCurrentUser()?.full_name} ({getCurrentUser()?.email})</p>
              <p><strong>Session Status:</strong> {deviceStatus.session_status}</p>
              <p><strong>Assigned At:</strong> {deviceStatus.assigned_at ? new Date(deviceStatus.assigned_at).toLocaleString() : 'N/A'}</p>
              <p><strong>Expires At:</strong> {deviceStatus.expires_at ? new Date(deviceStatus.expires_at).toLocaleString() : 'No expiry'}</p>
              {deviceStatus.admin_notes && <p><strong>Notes:</strong> {deviceStatus.admin_notes}</p>}
            </div>
            <button
              onClick={releaseDevice}
              className="mt-3 bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
            >
              Release Device
            </button>
          </div>
        )}

        {/* Assignment Form - only show if device is available */}
        {(!deviceStatus?.user_id || deviceStatus?.assignment_status === 'available') && (
          <>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium mb-2">Select User</label>
                <select
                  value={selectedUser}
                  onChange={(e) => setSelectedUser(e.target.value)}
                  className="w-full border rounded-md px-3 py-2"
                >
                  <option value="">Choose a user...</option>
                  {users.map(user => (
                    <option key={user.id} value={user.id}>
                      {user.full_name} ({user.email})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">Duration (hours)</label>
                <select
                  value={expiresIn}
                  onChange={(e) => setExpiresIn(e.target.value)}
                  className="w-full border rounded-md px-3 py-2"
                >
                  <option value="1">1 hour</option>
                  <option value="2">2 hours</option>
                  <option value="4">4 hours</option>
                  <option value="8">8 hours</option>
                  <option value="24">24 hours</option>
                </select>
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium mb-2">Admin Notes</label>
                <input
                  type="text"
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  placeholder="Optional notes about this assignment..."
                  className="w-full border rounded-md px-3 py-2"
                />
              </div>
            </div>

            <button
              onClick={assignDevice}
              className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
            >
              Assign Device
            </button>
          </>
        )}
      </div>

      {/* Device History */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-lg font-semibold mb-4">Device Information</h2>
        
        {deviceStatus ? (
          <div className="space-y-2">
            <p><strong>Device ID:</strong> {deviceStatus.device_id}</p>
            <p><strong>Device Name:</strong> {deviceStatus.device_name}</p>
            <p><strong>Assignment Status:</strong> 
              <span className={`ml-2 px-2 py-1 rounded-full text-xs ${getStatusColor(deviceStatus.assignment_status)}`}>
                {deviceStatus.assignment_status}
              </span>
            </p>
            <p><strong>Session Status:</strong> {deviceStatus.session_status}</p>
            <p><strong>Last Seen:</strong> {deviceStatus.last_seen_at ? new Date(deviceStatus.last_seen_at).toLocaleString() : 'Never'}</p>
            <p><strong>Battery Level:</strong> {deviceStatus.battery_level ? `${deviceStatus.battery_level}%` : 'Unknown'}</p>
            <p><strong>Firmware Version:</strong> {deviceStatus.firmware_version || 'Unknown'}</p>
            {deviceStatus.session_notes && (
              <p><strong>Session Notes:</strong> {deviceStatus.session_notes}</p>
            )}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            Device not found. It will be created when first assigned.
          </div>
        )}
      </div>
    </div>
  );
};

export default DeviceManagement;