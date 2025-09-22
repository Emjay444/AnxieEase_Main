import React, { useState, useEffect } from "react";
import { deviceService } from "../services/deviceService";
import { adminService } from "../services/adminService";
import {
  Smartphone,
  Battery,
  BatteryLow,
  Wifi,
  WifiOff,
  User,
  UserPlus,
  Clock,
  Calendar,
  AlertCircle,
  CheckCircle,
  XCircle,
  Activity,
  Settings,
  RefreshCw,
  Plus,
  Search,
  Filter,
  MoreVertical,
  Edit,
  Trash2,
  Eye,
  UserX,
  Timer,
  PlayCircle,
  PauseCircle,
  StopCircle,
  MessageSquare,
} from "lucide-react";

// Status badge component
const StatusBadge = ({ status, type = "assignment" }) => {
  const getStatusConfig = () => {
    if (type === "assignment") {
      switch (status) {
        case "available":
          return { color: "bg-green-100 text-green-800", icon: CheckCircle, label: "Available" };
        case "assigned":
          return { color: "bg-blue-100 text-blue-800", icon: User, label: "Assigned" };
        case "active":
          return { color: "bg-orange-100 text-orange-800", icon: Activity, label: "Active" };
        case "completed":
          return { color: "bg-gray-100 text-gray-800", icon: XCircle, label: "Completed" };
        default:
          return { color: "bg-gray-100 text-gray-800", icon: AlertCircle, label: status };
      }
    } else {
      switch (status) {
        case "idle":
          return { color: "bg-gray-100 text-gray-800", icon: PauseCircle, label: "Idle" };
        case "pending":
          return { color: "bg-yellow-100 text-yellow-800", icon: Timer, label: "Pending" };
        case "in_progress":
          return { color: "bg-green-100 text-green-800", icon: PlayCircle, label: "In Progress" };
        case "completed":
          return { color: "bg-blue-100 text-blue-800", icon: StopCircle, label: "Completed" };
        default:
          return { color: "bg-gray-100 text-gray-800", icon: AlertCircle, label: status };
      }
    }
  };

  const { color, icon: Icon, label } = getStatusConfig();
  
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${color}`}>
      <Icon className="h-3 w-3 mr-1" />
      {label}
    </span>
  );
};

// Device assignment modal
const DeviceAssignmentModal = ({ isOpen, onClose, device, availablePatients, onAssign }) => {
  const [selectedPatient, setSelectedPatient] = useState("");
  const [expirationDate, setExpirationDate] = useState("");
  const [adminNotes, setAdminNotes] = useState("");
  const [isAssigning, setIsAssigning] = useState(false);

  useEffect(() => {
    if (isOpen) {
      // Set default expiration to 7 days from now
      const defaultExpiry = new Date();
      defaultExpiry.setDate(defaultExpiry.getDate() + 7);
      setExpirationDate(defaultExpiry.toISOString().split('T')[0]);
    }
  }, [isOpen]);

  const handleAssign = async () => {
    if (!selectedPatient || !expirationDate) {
      alert("Please select a patient and expiration date");
      return;
    }

    setIsAssigning(true);
    try {
      const expiresAt = new Date(expirationDate + "T23:59:59").toISOString();
      await onAssign(device.device_id, selectedPatient, expiresAt, adminNotes);
      onClose();
      setSelectedPatient("");
      setAdminNotes("");
    } catch (error) {
      alert("Failed to assign device: " + error.message);
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
            Assign Device: {device.device_name}
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

// Device details modal
const DeviceDetailsModal = ({ isOpen, onClose, device }) => {
  if (!isOpen || !device) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 shadow-2xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-gray-900">Device Details</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg"
          >
            <XCircle className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        <div className="space-y-6">
          {/* Device Info */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-medium text-gray-900 mb-3">Device Information</h3>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Device ID:</span>
                  <span className="text-sm font-medium">{device.device_id}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Name:</span>
                  <span className="text-sm font-medium">{device.device_name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Status:</span>
                  <StatusBadge status={device.assignment_status} />
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Session:</span>
                  <StatusBadge status={device.session_status} type="session" />
                </div>
              </div>
            </div>

            <div>
              <h3 className="font-medium text-gray-900 mb-3">Technical Status</h3>
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Battery:</span>
                  <div className="flex items-center">
                    {device.battery_level > 20 ? (
                      <Battery className="h-4 w-4 text-green-600 mr-1" />
                    ) : (
                      <BatteryLow className="h-4 w-4 text-red-600 mr-1" />
                    )}
                    <span className="text-sm font-medium">{device.battery_level || 'Unknown'}%</span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Connection:</span>
                  <div className="flex items-center">
                    {device.is_online ? (
                      <Wifi className="h-4 w-4 text-green-600 mr-1" />
                    ) : (
                      <WifiOff className="h-4 w-4 text-red-600 mr-1" />
                    )}
                    <span className="text-sm font-medium">
                      {device.is_online ? 'Online' : 'Offline'}
                    </span>
                  </div>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Last Seen:</span>
                  <span className="text-sm font-medium">
                    {device.last_seen ? new Date(device.last_seen).toLocaleString() : 'Never'}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Assignment Info */}
          {device.user_id && (
            <div>
              <h3 className="font-medium text-gray-900 mb-3">Current Assignment</h3>
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <div className="flex justify-between">
                      <span className="text-sm text-blue-600">Assigned To:</span>
                      <span className="text-sm font-medium text-blue-900">
                        {device.assigned_user_name || 'Unknown User'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-blue-600">Assigned By:</span>
                      <span className="text-sm font-medium text-blue-900">
                        {device.admin_assigned_name || 'Unknown Admin'}
                      </span>
                    </div>
                  </div>
                  <div>
                    <div className="flex justify-between">
                      <span className="text-sm text-blue-600">Assigned At:</span>
                      <span className="text-sm font-medium text-blue-900">
                        {device.assigned_at ? new Date(device.assigned_at).toLocaleString() : 'Unknown'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-blue-600">Expires At:</span>
                      <span className="text-sm font-medium text-blue-900">
                        {device.expires_at ? new Date(device.expires_at).toLocaleString() : 'No expiration'}
                      </span>
                    </div>
                  </div>
                </div>
                {device.admin_notes && (
                  <div className="mt-3 pt-3 border-t border-blue-200">
                    <span className="text-sm text-blue-600">Admin Notes:</span>
                    <p className="text-sm text-blue-900 mt-1">{device.admin_notes}</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Session Notes */}
          {device.session_notes && (
            <div>
              <h3 className="font-medium text-gray-900 mb-3">Session Notes</h3>
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <p className="text-sm text-gray-700">{device.session_notes}</p>
              </div>
            </div>
          )}
        </div>

        <div className="flex justify-end pt-6 border-t mt-6">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

// Main DeviceManagement component
const DeviceManagement = () => {
  const [devices, setDevices] = useState([]);
  const [availablePatients, setAvailablePatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterStatus, setFilterStatus] = useState("all");
  
  // Modal states
  const [showAssignmentModal, setShowAssignmentModal] = useState(false);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [selectedDevice, setSelectedDevice] = useState(null);

  // Statistics
  const [stats, setStats] = useState({
    total: 0,
    available: 0,
    assigned: 0,
    active: 0,
    completed: 0,
  });

  // Load data
  const loadDevices = async () => {
    try {
      const devicesData = await deviceService.getAllDevices();
      setDevices(devicesData);
      
      const statsData = await deviceService.getDeviceStats();
      setStats(statsData);
    } catch (error) {
      console.error("Error loading devices:", error);
      setError("Failed to load devices");
    }
  };

  const loadAvailablePatients = async () => {
    try {
      const patients = await deviceService.getAvailablePatients();
      setAvailablePatients(patients);
    } catch (error) {
      console.error("Error loading patients:", error);
    }
  };

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      await Promise.all([loadDevices(), loadAvailablePatients()]);
    } catch (error) {
      setError("Failed to load data");
    } finally {
      setLoading(false);
    }
  };

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
  }, []);

  // Handle device assignment
  const handleAssignDevice = async (deviceId, userId, expiresAt, adminNotes) => {
    try {
      await deviceService.assignDeviceToUser(deviceId, userId, expiresAt, adminNotes);
      await loadData(); // Reload all data
      
      // Log activity
      const device = devices.find(d => d.device_id === deviceId);
      const patient = availablePatients.find(p => p.id === userId);
      await adminService.logActivity(
        null,
        "Device Assignment",
        `Device ${device?.device_name || deviceId} assigned to ${patient?.name || 'unknown patient'}`
      );
    } catch (error) {
      throw error;
    }
  };

  // Handle device release
  const handleReleaseDevice = async (device) => {
    if (!confirm(`Are you sure you want to release ${device.device_name} from ${device.assigned_user_name}?`)) {
      return;
    }

    try {
      await deviceService.releaseDeviceAssignment(device.device_id);
      await loadData(); // Reload all data
      
      // Log activity
      await adminService.logActivity(
        null,
        "Device Release",
        `Device ${device.device_name} released from ${device.assigned_user_name}`
      );
    } catch (error) {
      alert("Failed to release device: " + error.message);
    }
  };

  // Filter devices
  const filteredDevices = devices.filter(device => {
    const matchesSearch = device.device_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         device.device_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         (device.assigned_user_name && device.assigned_user_name.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesFilter = filterStatus === "all" || device.assignment_status === filterStatus;
    
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
          <h2 className="text-xl font-semibold text-gray-900">Device Management</h2>
          <p className="text-sm text-gray-600 mt-1">
            Manage AnxieEase wearable devices and user assignments
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

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Devices</p>
              <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
            </div>
            <Smartphone className="h-6 w-6 text-emerald-600" />
          </div>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Available</p>
              <p className="text-2xl font-bold text-green-600">{stats.available}</p>
            </div>
            <CheckCircle className="h-6 w-6 text-green-600" />
          </div>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Assigned</p>
              <p className="text-2xl font-bold text-blue-600">{stats.assigned}</p>
            </div>
            <User className="h-6 w-6 text-blue-600" />
          </div>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Active</p>
              <p className="text-2xl font-bold text-orange-600">{stats.active}</p>
            </div>
            <Activity className="h-6 w-6 text-orange-600" />
          </div>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Completed</p>
              <p className="text-2xl font-bold text-gray-600">{stats.completed}</p>
            </div>
            <XCircle className="h-6 w-6 text-gray-600" />
          </div>
        </div>
      </div>

      {/* Filters */}
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
          <option value="completed">Completed</option>
        </select>
      </div>

      {/* Devices List */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        {filteredDevices.length === 0 ? (
          <div className="text-center py-12">
            <Smartphone className="h-12 w-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">No devices found</p>
            {searchTerm && (
              <button
                onClick={() => setSearchTerm("")}
                className="text-emerald-600 hover:text-emerald-700 font-medium mt-2"
              >
                Clear search
              </button>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Device
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Assigned To
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Battery & Connection
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredDevices.map((device) => (
                  <tr key={device.device_id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="flex-shrink-0">
                          <Smartphone className="h-8 w-8 text-emerald-600" />
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-gray-900">
                            {device.device_name}
                          </div>
                          <div className="text-sm text-gray-500">
                            {device.device_id}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="space-y-1">
                        <StatusBadge status={device.assignment_status} />
                        <StatusBadge status={device.session_status} type="session" />
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {device.assigned_user_name ? (
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {device.assigned_user_name}
                          </div>
                          {device.expires_at && (
                            <div className="text-xs text-gray-500">
                              Expires: {new Date(device.expires_at).toLocaleDateString()}
                            </div>
                          )}
                        </div>
                      ) : (
                        <span className="text-sm text-gray-400 italic">Unassigned</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center space-x-3">
                        <div className="flex items-center">
                          {device.battery_level > 20 ? (
                            <Battery className="h-4 w-4 text-green-600 mr-1" />
                          ) : (
                            <BatteryLow className="h-4 w-4 text-red-600 mr-1" />
                          )}
                          <span className="text-sm">{device.battery_level || '?'}%</span>
                        </div>
                        <div className="flex items-center">
                          {device.is_online ? (
                            <Wifi className="h-4 w-4 text-green-600" />
                          ) : (
                            <WifiOff className="h-4 w-4 text-red-600" />
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <div className="flex items-center space-x-2">
                        {device.assignment_status === 'available' ? (
                          <button
                            onClick={() => {
                              setSelectedDevice(device);
                              setShowAssignmentModal(true);
                            }}
                            className="text-emerald-600 hover:text-emerald-900 px-2 py-1 rounded border border-emerald-600 hover:border-emerald-900 text-xs font-medium transition-colors"
                          >
                            Assign
                          </button>
                        ) : (
                          <button
                            onClick={() => handleReleaseDevice(device)}
                            className="text-red-600 hover:text-red-900 px-2 py-1 rounded border border-red-600 hover:border-red-900 text-xs font-medium transition-colors"
                          >
                            Release
                          </button>
                        )}
                        <button
                          onClick={() => {
                            setSelectedDevice(device);
                            setShowDetailsModal(true);
                          }}
                          className="text-blue-600 hover:text-blue-900"
                        >
                          View
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
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
        onAssign={handleAssignDevice}
      />

      {/* Details Modal */}
      <DeviceDetailsModal
        isOpen={showDetailsModal}
        onClose={() => {
          setShowDetailsModal(false);
          setSelectedDevice(null);
        }}
        device={selectedDevice}
      />
    </div>
  );
};

export default DeviceManagement;