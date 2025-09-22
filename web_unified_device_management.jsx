import React, { useState, useEffect, useCallback } from 'react';
import { unifiedDeviceService } from '../services/unifiedDeviceService';
import {
  Smartphone,
  Battery,
  BatteryLow,
  Wifi,
  WifiOff,
  User,
  Activity,
  AlertCircle,
  CheckCircle,
  XCircle,
  Heart,
  Thermometer,
  Zap,
  Clock,
  RefreshCw,
  Search,
  Filter,
  Bell,
  TrendingUp,
  Users,
  Monitor,
  Settings
} from 'lucide-react';

// Real-time stats dashboard
const FirebaseStatsDashboard = () => {
  const [stats, setStats] = useState({
    totalDevices: 0,
    activeDevices: 0,
    availableDevices: 0,
    assignedDevices: 0,
    lastUpdated: null
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadStats = async () => {
      try {
        const deviceStats = await unifiedDeviceService.getDeviceStatistics();
        setStats(deviceStats);
      } catch (error) {
        console.error('Error loading stats:', error);
      } finally {
        setLoading(false);
      }
    };

    loadStats();
    const interval = setInterval(loadStats, 30000); // Update every 30 seconds

    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return <div className="animate-pulse bg-gray-200 h-24 rounded-lg"></div>;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Total Devices</p>
            <p className="text-2xl font-bold text-gray-900">{stats.totalDevices}</p>
          </div>
          <Smartphone className="h-8 w-8 text-emerald-600" />
        </div>
      </div>

      <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Active Sessions</p>
            <p className="text-2xl font-bold text-green-600">{stats.activeDevices}</p>
          </div>
          <Activity className="h-8 w-8 text-green-600" />
        </div>
      </div>

      <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Assigned</p>
            <p className="text-2xl font-bold text-blue-600">{stats.assignedDevices}</p>
          </div>
          <User className="h-8 w-8 text-blue-600" />
        </div>
      </div>

      <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Available</p>
            <p className="text-2xl font-bold text-orange-600">{stats.availableDevices}</p>
          </div>
          <CheckCircle className="h-8 w-8 text-orange-600" />
        </div>
      </div>
    </div>
  );
};

// Real-time sensor data display
const SensorDataCard = ({ deviceId, sensorData }) => {
  if (!sensorData) {
    return (
      <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
        <p className="text-gray-500 text-center">No sensor data available</p>
      </div>
    );
  }

  return (
    <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
      <h4 className="font-semibold text-gray-900 mb-3">Live Sensor Data</h4>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="flex items-center space-x-2">
          <Heart className="h-5 w-5 text-red-500" />
          <div>
            <p className="text-sm text-gray-600">Heart Rate</p>
            <p className="text-lg font-semibold text-red-600">
              {sensorData.heartRate || '--'} BPM
            </p>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <Thermometer className="h-5 w-5 text-orange-500" />
          <div>
            <p className="text-sm text-gray-600">Temperature</p>
            <p className="text-lg font-semibold text-orange-600">
              {sensorData.bodyTemperature || '--'}°C
            </p>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <Zap className="h-5 w-5 text-yellow-500" />
          <div>
            <p className="text-sm text-gray-600">Skin Conductance</p>
            <p className="text-lg font-semibold text-yellow-600">
              {sensorData.skinConductance || '--'} μS
            </p>
          </div>
        </div>
      </div>
      
      {sensorData.timestamp && (
        <p className="text-xs text-gray-500 mt-2">
          Last updated: {new Date(sensorData.timestamp).toLocaleString()}
        </p>
      )}
    </div>
  );
};

// Enhanced device card with real-time data
const EnhancedDeviceCard = ({ device, onAssign, onRelease, onViewDetails }) => {
  const [sensorData, setSensorData] = useState(null);
  const [firebaseStatus, setFirebaseStatus] = useState('offline');

  useEffect(() => {
    if (!device?.device_id) return;

    // Subscribe to real-time sensor data
    const unsubscribeSensor = unifiedDeviceService.subscribeToDeviceData(
      device.device_id,
      setSensorData
    );

    // Subscribe to device status
    const unsubscribeStatus = unifiedDeviceService.subscribeToDeviceStatus(
      device.device_id,
      setFirebaseStatus
    );

    return () => {
      unsubscribeSensor();
      unsubscribeStatus();
    };
  }, [device?.device_id]);

  const getStatusColor = (status) => {
    switch (status) {
      case 'available': return 'bg-green-100 text-green-800';
      case 'assigned': return 'bg-blue-100 text-blue-800';
      case 'active': return 'bg-emerald-100 text-emerald-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getFirebaseStatusColor = (status) => {
    switch (status) {
      case 'active': return 'text-green-600';
      case 'completed': return 'text-blue-600';
      case 'paused': return 'text-yellow-600';
      default: return 'text-gray-600';
    }
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
      {/* Device Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <Smartphone className="h-8 w-8 text-emerald-600" />
          <div>
            <h3 className="font-semibold text-gray-900">{device.device_id}</h3>
            <div className="flex items-center space-x-2">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(device.status)}`}>
                {device.status}
              </span>
              <span className={`text-xs font-medium ${getFirebaseStatusColor(firebaseStatus)}`}>
                Firebase: {firebaseStatus}
              </span>
            </div>
          </div>
        </div>
        
        <div className="flex items-center space-x-1">
          {device.is_real_time_active ? (
            <Wifi className="h-5 w-5 text-green-600" />
          ) : (
            <WifiOff className="h-5 w-5 text-red-600" />
          )}
          <Battery className="h-5 w-5 text-gray-600" />
        </div>
      </div>

      {/* Assignment Info */}
      {device.assigned_user_name ? (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-blue-900">
                Assigned to: {device.assigned_user_name}
              </p>
              {device.linked_at && (
                <p className="text-xs text-blue-600">
                  Since: {new Date(device.linked_at).toLocaleDateString()}
                </p>
              )}
            </div>
            <User className="h-5 w-5 text-blue-600" />
          </div>
        </div>
      ) : (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 mb-4">
          <p className="text-sm text-gray-600 text-center">
            <User className="h-4 w-4 inline mr-1" />
            No user assigned
          </p>
        </div>
      )}

      {/* Real-time Sensor Data */}
      {device.is_real_time_active && sensorData && (
        <SensorDataCard deviceId={device.device_id} sensorData={sensorData} />
      )}

      {/* Action Buttons */}
      <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-200">
        <div className="flex space-x-2">
          {device.status === 'available' ? (
            <button
              onClick={() => onAssign(device)}
              className="px-3 py-1.5 bg-emerald-600 text-white text-sm rounded-lg hover:bg-emerald-700 transition-colors"
            >
              Assign
            </button>
          ) : (
            <button
              onClick={() => onRelease(device)}
              className="px-3 py-1.5 bg-red-600 text-white text-sm rounded-lg hover:bg-red-700 transition-colors"
            >
              Release
            </button>
          )}
          <button
            onClick={() => onViewDetails(device)}
            className="px-3 py-1.5 bg-gray-600 text-white text-sm rounded-lg hover:bg-gray-700 transition-colors"
          >
            Details
          </button>
        </div>
        
        <div className="flex items-center space-x-1 text-xs text-gray-500">
          <Clock className="h-3 w-3" />
          <span>
            {device.last_seen ? new Date(device.last_seen).toLocaleTimeString() : 'Never'}
          </span>
        </div>
      </div>
    </div>
  );
};

// Device assignment modal
const DeviceAssignmentModal = ({ isOpen, onClose, device, availablePatients, onAssign }) => {
  const [selectedPatient, setSelectedPatient] = useState('');
  const [expirationDate, setExpirationDate] = useState('');
  const [adminNotes, setAdminNotes] = useState('');
  const [isAssigning, setIsAssigning] = useState(false);

  useEffect(() => {
    if (isOpen) {
      const defaultExpiry = new Date();
      defaultExpiry.setDate(defaultExpiry.getDate() + 7);
      setExpirationDate(defaultExpiry.toISOString().split('T')[0]);
    }
  }, [isOpen]);

  const handleAssign = async () => {
    if (!selectedPatient || !expirationDate) {
      alert('Please select a patient and expiration date');
      return;
    }

    setIsAssigning(true);
    try {
      const expiresAt = new Date(expirationDate + 'T23:59:59').toISOString();
      await onAssign(device.device_id, selectedPatient, expiresAt, adminNotes);
      onClose();
      setSelectedPatient('');
      setAdminNotes('');
    } catch (error) {
      alert('Failed to assign device: ' + error.message);
    } finally {
      setIsAssigning(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 shadow-2xl max-w-md w-full mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-gray-900">
            Assign Device: {device?.device_id}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg"
          >
            <XCircle className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select Patient
            </label>
            <select
              value={selectedPatient}
              onChange={(e) => setSelectedPatient(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >
              <option value="">Choose a patient...</option>
              {availablePatients.map((patient) => (
                <option key={patient.id} value={patient.id}>
                  {patient.name} ({patient.email})
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Assignment Expires On
            </label>
            <input
              type="date"
              value={expirationDate}
              onChange={(e) => setExpirationDate(e.target.value)}
              min={new Date().toISOString().split('T')[0]}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Admin Notes (Optional)
            </label>
            <textarea
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              placeholder="Add any notes about this assignment..."
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
        </div>

        <div className="flex justify-end space-x-3 pt-6 border-t mt-6">
          <button
            onClick={onClose}
            disabled={isAssigning}
            className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleAssign}
            disabled={isAssigning || !selectedPatient || !expirationDate}
            className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            {isAssigning && <RefreshCw className="h-4 w-4 mr-2 animate-spin" />}
            Assign Device
          </button>
        </div>
      </div>
    </div>
  );
};

// Main unified device management component
const UnifiedDeviceManagement = () => {
  const [devices, setDevices] = useState([]);
  const [availablePatients, setAvailablePatients] = useState([]);
  const [allSessions, setAllSessions] = useState({});
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  
  // Modal states
  const [showAssignmentModal, setShowAssignmentModal] = useState(false);
  const [selectedDevice, setSelectedDevice] = useState(null);

  const loadData = useCallback(async () => {
    try {
      setError(null);
      const [devicesData, patientsData] = await Promise.all([
        unifiedDeviceService.getAllDevices(),
        unifiedDeviceService.getAvailablePatients()
      ]);
      
      setDevices(devicesData);
      setAvailablePatients(patientsData);
    } catch (error) {
      console.error('Error loading data:', error);
      setError('Failed to load device data');
    } finally {
      setLoading(false);
    }
  }, []);

  const refreshData = async () => {
    setRefreshing(true);
    try {
      await loadData();
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();

    // Subscribe to all Firebase sessions for real-time updates
    const unsubscribe = unifiedDeviceService.subscribeToAllDeviceSessions(setAllSessions);

    return () => {
      unsubscribe();
      unifiedDeviceService.cleanup();
    };
  }, [loadData]);

  const handleDeviceAssignment = async (deviceId, userId, expiresAt, adminNotes) => {
    try {
      await unifiedDeviceService.assignDeviceToUser(deviceId, userId, expiresAt, adminNotes);
      await loadData(); // Refresh device list
    } catch (error) {
      throw error;
    }
  };

  const handleDeviceRelease = async (device) => {
    if (!confirm(`Are you sure you want to release ${device.device_id} from ${device.assigned_user_name}?`)) {
      return;
    }

    try {
      await unifiedDeviceService.releaseDeviceAssignment(device.device_id);
      await loadData(); // Refresh device list
    } catch (error) {
      alert('Failed to release device: ' + error.message);
    }
  };

  // Filter devices based on search and status
  const filteredDevices = devices.filter(device => {
    const matchesSearch = device.device_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         (device.assigned_user_name && device.assigned_user_name.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesFilter = filterStatus === 'all' || device.status === filterStatus;
    
    return matchesSearch && matchesFilter;
  });

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Unified Device Management</h2>
          <p className="text-sm text-gray-600 mt-1">
            Real-time monitoring and management of AnxieEase devices
          </p>
        </div>
        <button
          onClick={refreshData}
          disabled={refreshing}
          className="flex items-center px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors disabled:opacity-50"
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {/* Error Display */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-center">
            <AlertCircle className="h-5 w-5 text-red-600 mr-2" />
            <span className="text-red-800">{error}</span>
          </div>
        </div>
      )}

      {/* Firebase Statistics Dashboard */}
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Real-time Statistics</h3>
        <FirebaseStatsDashboard />
      </div>

      {/* Search and Filter */}
      <div className="flex items-center space-x-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search devices or users..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
          />
        </div>
        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value)}
          className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
        >
          <option value="all">All Status</option>
          <option value="available">Available</option>
          <option value="assigned">Assigned</option>
          <option value="active">Active</option>
        </select>
      </div>

      {/* Device Cards Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {filteredDevices.length === 0 ? (
          <div className="col-span-full bg-white rounded-xl shadow-sm border border-gray-100 text-center py-12">
            <Smartphone className="h-12 w-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">No devices found</p>
            {searchTerm && (
              <button
                onClick={() => setSearchTerm('')}
                className="text-emerald-600 hover:text-emerald-700 font-medium mt-2"
              >
                Clear search
              </button>
            )}
          </div>
        ) : (
          filteredDevices.map((device) => (
            <EnhancedDeviceCard
              key={device.device_id}
              device={device}
              onAssign={(device) => {
                setSelectedDevice(device);
                setShowAssignmentModal(true);
              }}
              onRelease={handleDeviceRelease}
              onViewDetails={(device) => {
                // TODO: Implement device details modal
                console.log('View details for:', device);
              }}
            />
          ))
        )}
      </div>

      {/* Assignment Modal */}
      <DeviceAssignmentModal
        isOpen={showAssignmentModal}
        onClose={() => {
          setShowAssignmentModal(false);
          setSelectedDevice(null);
        }}
        device={selectedDevice}
        availablePatients={availablePatients}
        onAssign={handleDeviceAssignment}
      />
    </div>
  );
};

export default UnifiedDeviceManagement;
export { FirebaseStatsDashboard, EnhancedDeviceCard, SensorDataCard };