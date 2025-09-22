import React, { useState, useEffect } from "react";
import { useAuth } from "../contexts/AuthContext";
import { adminService } from "../services/adminService";
import { psychologistService } from "../services/psychologistService";
import AddDoctorModal from "./AddDoctorModal";
import ProfilePicture from "./ProfilePicture";
import DeviceManagement from "./DeviceManagement";
import {
  Users,
  UserPlus,
  Settings,
  Activity,
  Search,
  Filter,
  MoreVertical,
  ChevronDown,
  Plus,
  Edit3,
  Trash2,
  Eye,
  Mail,
  Phone,
  Calendar,
  Clock,
  TrendingUp,
  UserCheck,
  UserX,
  BarChart3,
  CheckCircle,
  User,
  X,
  Smartphone,
} from "lucide-react";
import LogoutButton from "./LogoutButton";
// Charts
import { Pie, Bar, Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  ArcElement,
  Tooltip as ChartTooltip,
  Legend as ChartLegend,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Filler,
} from "chart.js";

ChartJS.register(
  ArcElement,
  ChartTooltip,
  ChartLegend,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Filler
);

// Success Modal Component
const SuccessModal = ({ isOpen, onClose, title, message, details = [] }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Blurred backdrop instead of black */}
      <div
        className="absolute inset-0 bg-white/20 backdrop-blur-md"
        onClick={onClose}
      ></div>

      {/* Modal content */}
      <div className="relative bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden animate-in zoom-in-95 duration-200">
        <div className="p-6">
          {/* Success icon and title */}
          <div className="flex items-center mb-4">
            <div className="flex-shrink-0 w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
              <CheckCircle className="h-6 w-6 text-green-600" />
            </div>
            <h3 className="ml-3 text-lg font-semibold text-gray-900">
              {title}
            </h3>
          </div>

          {/* Message */}
          <p className="text-gray-600 mb-4">{message}</p>

          {/* Details list */}
          {details.length > 0 && (
            <div className="space-y-3 mb-6">
              {details.map((detail, index) => (
                <div key={index} className="flex items-start space-x-2">
                  <div
                    className={`w-1.5 h-1.5 rounded-full mt-2 flex-shrink-0 ${
                      detail.type === "info"
                        ? "bg-blue-500"
                        : detail.type === "warning"
                        ? "bg-yellow-500"
                        : "bg-gray-400"
                    }`}
                  ></div>
                  <p
                    className={`text-sm ${
                      detail.type === "info"
                        ? "text-blue-700"
                        : detail.type === "warning"
                        ? "text-yellow-700"
                        : "text-gray-600"
                    }`}
                  >
                    {detail.text}
                  </p>
                </div>
              ))}
            </div>
          )}

          {/* OK button */}
          <button
            onClick={onClose}
            className="w-full bg-emerald-600 text-white py-2.5 px-4 rounded-lg hover:bg-emerald-700 transition-colors font-medium"
          >
            OK
          </button>
        </div>
      </div>
    </div>
  );
};

const AdminPanelNew = () => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState("overview");
  const [psychologistSearchTerm, setPsychologistSearchTerm] = useState("");
  const [patientSearchTerm, setPatientSearchTerm] = useState("");
  const [patientSortBy, setPatientSortBy] = useState("all"); // all, assigned, unassigned, name

  // Pagination state for activity logs
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);

  // Analytics state
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [loading, setLoading] = useState(true);
  const [showAddPsychologistModal, setShowAddPsychologistModal] =
    useState(false);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [isCreatingPsychologist, setIsCreatingPsychologist] = useState(false);
  const [successMessage, setSuccessMessage] = useState({
    title: "",
    message: "",
    details: [],
  });

  // Real data states - connected to Supabase
  const [stats, setStats] = useState({
    totalPsychologists: 0,
    totalPatients: 0,
    activeAssignments: 0,
    pendingRequests: 0,
  });

  const [psychologists, setPsychologists] = useState([]);
  const [patients, setPatients] = useState([]);
  const [unassignedPatients, setUnassignedPatients] = useState([]);
  const [activityLogs, setActivityLogs] = useState([]);
  const [analyticsData, setAnalyticsData] = useState({
    genderDistribution: { male: 0, female: 0, other: 0 },
    ageDistribution: { "18-25": 0, "26-35": 0, "36-45": 0, "46+": 0 },
    monthlyRegistrations: {
      Jan: 0,
      Feb: 0,
      Mar: 0,
      Apr: 0,
      May: 0,
      Jun: 0,
      Jul: 0,
      Aug: 0,
      Sep: 0,
      Oct: 0,
      Nov: 0,
      Dec: 0,
    },
    totalPatients: 0,
  });

  // State for psychologist actions
  const [selectedPsychologist, setSelectedPsychologist] = useState(null);
  const [showViewModal, setShowViewModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showOptionsMenu, setShowOptionsMenu] = useState(null);
  const [showDeleteConfirmModal, setShowDeleteConfirmModal] = useState(false);
  const [psychologistToDelete, setPsychologistToDelete] = useState(null);
  const [showActivateConfirmModal, setShowActivateConfirmModal] =
    useState(false);
  const [psychologistToToggle, setPsychologistToToggle] = useState(null);
  const [showResetEmailModal, setShowResetEmailModal] = useState(false);
  const [psychologistToReset, setPsychologistToReset] = useState(null);
  const [isSendingResetEmail, setIsSendingResetEmail] = useState(false);

  // State for patient actions
  const [selectedPatient, setSelectedPatient] = useState(null);
  const [showPatientViewModal, setShowPatientViewModal] = useState(false);
  const [showPatientEditModal, setShowPatientEditModal] = useState(false);
  const [showAssignmentModal, setShowAssignmentModal] = useState(false);
  const [patientToAssign, setPatientToAssign] = useState(null);
  const [showConfirmationModal, setShowConfirmationModal] = useState(false);
  const [pendingAssignment, setPendingAssignment] = useState(null);

  // Load real data from Supabase
  const loadDashboardData = async () => {
    try {
      setLoading(true);

      // Load dashboard statistics
      const statsData = await adminService.getDashboardStats();
      setStats({
        totalPsychologists: statsData.psychologistsCount || 0,
        totalPatients: statsData.patientsCount || 0,
        activeAssignments:
          statsData.patientsCount - statsData.unassignedPatientsCount || 0,
        pendingRequests: statsData.unassignedPatientsCount || 0,
      });

      // Load unassigned patients
      const unassignedData = await adminService.getUnassignedPatients();
      setUnassignedPatients(unassignedData);

      // Load all users and separate patients
      const allUsers = await adminService.getAllUsers();
      const patientsList = allUsers.filter((user) => user.role === "patient");
      setPatients(patientsList);

      // Load psychologists
      const psychologistsList = await psychologistService.getAllPsychologists();
      console.log("Loaded psychologists:", psychologistsList);
      console.log(
        "Psychologist avatar URLs:",
        psychologistsList.map((p) => ({
          name: p.name,
          avatar_url: p.avatar_url,
        }))
      );
      setPsychologists(psychologistsList);

      // Load activity logs
      const logs = await adminService.getActivityLogs();
      setActivityLogs(logs);

      // Load analytics data
      const analytics = await adminService.getAnalyticsData(selectedYear);
      setAnalyticsData(analytics);

      console.log("Dashboard data loaded:", {
        stats: statsData,
        unassigned: unassignedData,
        patients: patientsList,
        psychologists: psychologistsList,
        logs: logs,
        analytics: analytics,
      });
    } catch (error) {
      console.error("Error loading dashboard data:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  // Reset pagination when switching to activity tab
  useEffect(() => {
    if (activeTab === "activity") {
      setCurrentPage(1);
    }
  }, [activeTab]);

  // Load analytics data when year changes
  const loadAnalyticsData = async (year) => {
    try {
      const analytics = await adminService.getAnalyticsData(year);
      setAnalyticsData(analytics);
    } catch (error) {
      console.error("Error loading analytics data:", error);
    }
  };

  // Effect to reload analytics when year changes
  useEffect(() => {
    loadAnalyticsData(selectedYear);
  }, [selectedYear]);

  // Handle adding new psychologist
  const handleAddPsychologist = async (psychologistData) => {
    try {
      // Show immediate loading feedback
      setIsCreatingPsychologist(true);

      // Set psychologist as inactive by default until email is verified
      const psychologistWithStatus = {
        ...psychologistData,
        is_active: false, // Set to inactive until email verification
      };

      // Close the modal immediately but keep loading state
      setShowAddPsychologistModal(false);

      const newPsychologist = await psychologistService.createPsychologist(
        psychologistWithStatus
      );

      // Refresh the psychologists list
      const updatedPsychologists =
        await psychologistService.getAllPsychologists();
      setPsychologists(updatedPsychologists);

      // Refresh stats
      const statsData = await adminService.getDashboardStats();
      setStats({
        totalPsychologists: statsData.psychologistsCount || 0,
        totalPatients: statsData.patientsCount || 0,
        activeAssignments:
          statsData.patientsCount - statsData.unassignedPatientsCount || 0,
        pendingRequests: 0,
      });

      // Show success modal with detailed information
      setSuccessMessage({
        title: "Psychologist Account Created Successfully!",
        message: `Dr. ${psychologistData.name}'s account has been created and an invitation email has been sent.`,
        details: [
          {
            type: "info",
            text: `An email verification link has been sent to ${psychologistData.email}.`,
          },
          {
            type: "warning",
            text: "The account will remain inactive until the psychologist verifies their email address.",
          },
          {
            type: "info",
            text: "Once verified, they can complete their profile setup and begin seeing patients.",
          },
        ],
      });
      setShowSuccessModal(true);
    } catch (error) {
      console.error("Error adding psychologist:", error);
      alert("❌ Failed to create psychologist account: " + error.message);
    } finally {
      // Clear loading state
      setIsCreatingPsychologist(false);
    }
  };

  // Handle psychologist actions
  const handleViewPsychologist = (psychologist) => {
    setSelectedPsychologist(psychologist);
    setShowViewModal(true);
  };

  const handleEditPsychologist = (psychologist) => {
    setSelectedPsychologist(psychologist);
    setShowEditModal(true);
  };

  const handlePsychologistOptions = (psychologistId) => {
    setShowOptionsMenu(
      showOptionsMenu === psychologistId ? null : psychologistId
    );
  };

  const handleDeactivatePsychologist = async (psychologist) => {
    try {
      // Check if we're deactivating or activating
      const newStatus = !psychologist.is_active;

      if (!newStatus) {
        // Deactivating - use the special deactivation method with patient check
        await psychologistService.deactivatePsychologist(psychologist.id);
      } else {
        // Activating - use regular update method
        await psychologistService.updatePsychologist(psychologist.id, {
          is_active: newStatus,
        });
      }

      // Update local state
      setPsychologists((prev) =>
        prev.map((p) =>
          p.id === psychologist.id ? { ...p, is_active: newStatus } : p
        )
      );

      setShowOptionsMenu(null);
      alert(
        `Psychologist ${newStatus ? "activated" : "deactivated"} successfully!`
      );
    } catch (error) {
      console.error("Error updating psychologist:", error);

      // Show user-friendly error message
      if (error.message.includes("assigned patient")) {
        alert(
          `⚠️ Cannot Deactivate Psychologist\n\n${error.message}\n\nPlease go to the Patients tab to reassign these patients to another psychologist first.`
        );
      } else {
        alert("❌ Failed to update psychologist status: " + error.message);
      }
    }
  };

  // Patient handler functions
  const handleViewPatient = (patient) => {
    setSelectedPatient(patient);
    setShowPatientViewModal(true);
  };

  const handleEditPatient = (patient) => {
    setSelectedPatient(patient);
    setShowPatientEditModal(true);
  };

  // Handle opening assignment modal
  const handleOpenAssignmentModal = (patient) => {
    setPatientToAssign(patient);
    setShowAssignmentModal(true);
  };

  // Handle assignment confirmation
  const handleAssignmentConfirmation = (
    patientId,
    psychologistId,
    psychologistName,
    isUnassign = false
  ) => {
    // Get patient name more efficiently
    const patientName =
      patientToAssign?.name ||
      (patientToAssign?.first_name && patientToAssign?.last_name
        ? `${patientToAssign.first_name} ${patientToAssign.last_name}`
        : patientToAssign?.first_name || patientToAssign?.last_name) ||
      patientToAssign?.email?.split("@")[0] ||
      "Unknown Patient";

    // Set all states together to minimize re-renders
    setPendingAssignment({
      patientId,
      psychologistId,
      psychologistName,
      isUnassign,
      patientName,
    });
    setShowAssignmentModal(false);
    setShowConfirmationModal(true);
  };

  // Confirm the assignment
  const confirmAssignment = async () => {
    if (!pendingAssignment) return;

    setShowConfirmationModal(false);

    try {
      await handlePsychologistAssignment(
        pendingAssignment.patientId,
        pendingAssignment.psychologistId
      );

      // Show success modal instead of alert
      setSuccessMessage({
        title: pendingAssignment.isUnassign
          ? "Patient Unassigned"
          : "Patient Assigned",
        message: pendingAssignment.isUnassign
          ? `${pendingAssignment.patientName} has been unassigned successfully.`
          : `${pendingAssignment.patientName} has been assigned to ${pendingAssignment.psychologistName}.`,
        details: [],
      });
      setShowSuccessModal(true);
    } catch (error) {
      console.error("Assignment error:", error);
      // Show error in success modal format
      setSuccessMessage({
        title: "Assignment Failed",
        message: `Failed to ${
          pendingAssignment.isUnassign ? "unassign" : "assign"
        } patient. Please try again.`,
        details: [{ text: error.message, type: "warning" }],
      });
      setShowSuccessModal(true);
    } finally {
      setPendingAssignment(null);
      setPatientToAssign(null);
    }
  };

  // Handle psychologist assignment change
  const handlePsychologistAssignment = async (patientId, psychologistId) => {
    try {
      const result = await adminService.assignPatientToPsychologist(
        patientId,
        psychologistId
      );

      if (result.success) {
        // Update the local state to reflect the change
        setPatients(
          patients.map((patient) =>
            patient.id === patientId
              ? {
                  ...patient,
                  assigned_psychologist_id: psychologistId,
                  assigned_psychologist_name: psychologistId
                    ? psychologists.find((p) => p.id === psychologistId)
                        ?.name || null
                    : null,
                }
              : patient
          )
        );

        // Reload dashboard data to refresh stats
        await loadDashboardData();

        return { success: true };
      } else {
        throw new Error(result.error);
      }
    } catch (error) {
      console.error("Error with patient assignment:", error);
      throw error;
    }
  };

  const StatCard = ({ title, value, icon: Icon, trend, color = "emerald" }) => {
    const palette = {
      emerald: { bg: "bg-emerald-50", text: "text-emerald-600" },
      green: { bg: "bg-green-50", text: "text-green-600" },
      purple: { bg: "bg-purple-50", text: "text-purple-600" },
      orange: { bg: "bg-orange-50", text: "text-orange-600" },
      blue: { bg: "bg-blue-50", text: "text-blue-600" },
      yellow: { bg: "bg-yellow-50", text: "text-yellow-600" },
      gray: { bg: "bg-gray-50", text: "text-gray-600" },
    };
    const colors = palette[color] || palette.emerald;
    return (
      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">{title}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
            {trend && (
              <div className="flex items-center mt-2">
                <TrendingUp className="h-4 w-4 text-green-500 mr-1" />
                <span className="text-sm text-green-600">{trend}</span>
              </div>
            )}
          </div>
          <div className={`p-3 rounded-lg ${colors.bg}`}>
            <Icon className={`h-6 w-6 ${colors.text}`} />
          </div>
        </div>
      </div>
    );
  };

  const TabButton = ({ tab, label, icon: Icon, isActive, onClick }) => (
    <button
      onClick={onClick}
      className={`flex items-center px-4 py-2 rounded-lg font-medium transition-colors ${
        isActive
          ? "bg-emerald-100 text-emerald-700 border border-emerald-200"
          : "text-gray-600 hover:text-gray-900 hover:bg-gray-50"
      }`}
    >
      <Icon className="h-4 w-4 mr-2" />
      {label}
    </button>
  );

  const PsychologistCard = ({ psychologist }) => (
    <div
      className={`bg-white rounded-xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-all ${
        !psychologist.is_active ? "opacity-60 bg-gray-50" : ""
      }`}
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className={`${!psychologist.is_active ? "opacity-60" : ""}`}>
            <ProfilePicture patient={psychologist} size={48} className="" />
          </div>
          <div>
            <h3
              className={`font-semibold ${
                psychologist.is_active ? "text-gray-900" : "text-gray-500"
              }`}
            >
              {psychologist.name}
            </h3>
            <p
              className={`text-sm ${
                psychologist.is_active ? "text-gray-600" : "text-gray-400"
              }`}
            >
              {psychologist.specialization || ""}
            </p>
          </div>
        </div>
        <div className="relative">
          <button
            onClick={() => handlePsychologistOptions(psychologist.id)}
            className="p-2 hover:bg-gray-100 rounded-lg"
          >
            <MoreVertical className="h-4 w-4 text-gray-400" />
          </button>

          {/* Dropdown Menu */}
          {showOptionsMenu === psychologist.id && (
            <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg z-50 border border-gray-200">
              <div className="py-1">
                <button
                  onClick={() => {
                    setShowOptionsMenu(null);
                    setPsychologistToToggle(psychologist);
                    setShowActivateConfirmModal(true);
                  }}
                  className={`block w-full text-left px-4 py-2 text-sm hover:bg-gray-100 ${
                    psychologist.is_active
                      ? "text-orange-600"
                      : "text-green-600"
                  }`}
                >
                  {psychologist.is_active ? "Deactivate" : "Activate"}
                </button>
                <button
                  onClick={() => {
                    setShowOptionsMenu(null);
                    setPsychologistToReset(psychologist);
                    setShowResetEmailModal(true);
                  }}
                  className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                >
                  Send Reset Email
                </button>
                <button
                  onClick={() => {
                    console.log(
                      "Delete button clicked for:",
                      psychologist.name
                    );
                    setShowOptionsMenu(null);
                    setPsychologistToDelete(psychologist);
                    setShowDeleteConfirmModal(true);
                  }}
                  className="block w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50"
                >
                  Delete
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="space-y-3">
        <div
          className={`flex items-center text-sm ${
            psychologist.is_active ? "text-gray-600" : "text-gray-400"
          }`}
        >
          <Mail className="h-4 w-4 mr-2" />
          {psychologist.email}
        </div>
        <div
          className={`flex items-center text-sm ${
            psychologist.is_active ? "text-gray-600" : "text-gray-400"
          }`}
        >
          <Phone className="h-4 w-4 mr-2" />
          {psychologist.contact || "No contact info"}
        </div>
        <div
          className={`flex items-center text-sm ${
            psychologist.is_active ? "text-gray-600" : "text-gray-400"
          }`}
        >
          <Calendar className="h-4 w-4 mr-2" />
          Joined {new Date(psychologist.created_at).toLocaleDateString()}
        </div>
      </div>

      <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-100">
        <span
          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
            psychologist.is_active
              ? "bg-green-100 text-green-800"
              : "bg-red-100 text-red-800"
          }`}
        >
          {psychologist.is_active ? "Active" : "Deactivated"}
        </span>
        <div className="flex space-x-2">
          <button
            onClick={() => handleViewPsychologist(psychologist)}
            className={`text-sm font-medium ${
              psychologist.is_active
                ? "text-blue-600 hover:text-blue-900"
                : "text-gray-400 hover:text-gray-500"
            }`}
          >
            View
          </button>
        </div>
      </div>
    </div>
  );

  // Don't show full-screen loading after initial load
  if (loading && !stats.totalPsychologists && !stats.totalPatients) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-app-light">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <img
                src="/anxieease-logo.png"
                alt="AnxieEase"
                className="h-6 w-6 logo-breathe"
                onError={(e) => {
                  e.currentTarget.style.display = "none";
                }}
              />
              <h1 className="text-2xl font-bold text-gray-900">
                AnxieEase Admin
              </h1>
              <span className="text-sm text-gray-500">Dashboard</span>
            </div>

            <div className="flex items-center space-x-4">
              {/* User Menu */}
              <div className="flex items-center space-x-3">
                <div className="text-right">
                  <p className="text-sm font-medium text-gray-900">
                    Welcome back!
                  </p>
                  <p className="text-xs text-gray-500">{user?.email}</p>
                </div>
                <LogoutButton variant="icon" />
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="p-6">
        {/* Navigation Tabs */}
        <div className="flex space-x-2 mb-6">
          <TabButton
            tab="overview"
            label="Overview"
            icon={BarChart3}
            isActive={activeTab === "overview"}
            onClick={() => setActiveTab("overview")}
          />
          <TabButton
            tab="psychologists"
            label="Psychologists"
            icon={Users}
            isActive={activeTab === "psychologists"}
            onClick={() => setActiveTab("psychologists")}
          />
          <TabButton
            tab="patients"
            label="Patients"
            icon={UserPlus}
            isActive={activeTab === "patients"}
            onClick={() => setActiveTab("patients")}
          />
          <TabButton
            tab="devices"
            label="Device Management"
            icon={Smartphone}
            isActive={activeTab === "devices"}
            onClick={() => setActiveTab("devices")}
          />
          <TabButton
            tab="activity"
            label="Activity"
            icon={Activity}
            isActive={activeTab === "activity"}
            onClick={() => setActiveTab("activity")}
          />
        </div>

        {/* Overview Tab */}
        {activeTab === "overview" && (
          <div className="space-y-6">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <StatCard
                title="Total Psychologists"
                value={stats.totalPsychologists}
                icon={Users}
                color="emerald"
              />
              <StatCard
                title="Total Patients"
                value={stats.totalPatients}
                icon={UserPlus}
                color="green"
              />
              <StatCard
                title="Active Assignments"
                value={stats.activeAssignments}
                icon={UserCheck}
                color="purple"
              />
            </div>

            {/* Quick Actions */}
            <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">
                Quick Actions
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <button
                  onClick={() => setActiveTab("psychologists")}
                  className="flex items-center p-4 text-left border-2 border-dashed border-gray-300 rounded-lg hover:border-emerald-500 hover:bg-emerald-50 transition-colors"
                >
                  <Plus className="h-5 w-5 text-emerald-600 mr-3" />
                  <div>
                    <p className="font-medium text-gray-900">
                      Add Psychologist
                    </p>
                    <p className="text-sm text-gray-600">
                      Create new psychologist profile
                    </p>
                  </div>
                </button>
                <button
                  onClick={() => setActiveTab("patients")}
                  className="flex items-center p-4 text-left border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors"
                >
                  <UserCheck className="h-5 w-5 text-blue-600 mr-3" />
                  <div>
                    <p className="font-medium text-gray-900">Assign Patient</p>
                    <p className="text-sm text-gray-600">
                      View and manage patient assignments
                    </p>
                  </div>
                </button>
                <button
                  onClick={() => setActiveTab("devices")}
                  className="flex items-center p-4 text-left border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-colors"
                >
                  <Smartphone className="h-5 w-5 text-purple-600 mr-3" />
                  <div>
                    <p className="font-medium text-gray-900">Manage Devices</p>
                    <p className="text-sm text-gray-600">
                      Assign and monitor AnxieEase devices
                    </p>
                  </div>
                </button>
              </div>
            </div>

            {/* Analytics Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Gender Distribution */}
              <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
                <div className="flex items-center mb-4">
                  <User className="h-5 w-5 text-emerald-600 mr-2" />
                  <h3 className="text-lg font-semibold text-gray-900">
                    Gender Distribution
                  </h3>
                </div>
                <div className="space-y-4">
                  <div className="w-full h-64">
                    <Pie
                      data={{
                        labels: ["Male", "Female"],
                        datasets: [
                          {
                            data: [
                              analyticsData.genderDistribution.male || 0,
                              analyticsData.genderDistribution.female || 0,
                            ],
                            backgroundColor: ["#22c55e", "#ef4444"], // green, red
                            borderColor: "#ffffff",
                            borderWidth: 2,
                          },
                        ],
                      }}
                      options={{
                        maintainAspectRatio: false,
                        plugins: {
                          legend: { position: "bottom" },
                        },
                      }}
                    />
                  </div>
                  <div className="pt-2 border-t border-gray-200">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium text-gray-700">
                        Total:
                      </span>
                      <span className="font-semibold">
                        {analyticsData.totalPatients} patients
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Age Distribution */}
              <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
                <div className="flex items-center mb-4">
                  <Calendar className="h-5 w-5 text-blue-600 mr-2" />
                  <h3 className="text-lg font-semibold text-gray-900">
                    Age Distribution
                  </h3>
                </div>
                <div className="w-full h-64">
                  <Bar
                    data={{
                      labels: (() => {
                        const hist = analyticsData.ageHistogram || {};
                        const present = Object.keys(hist)
                          .map((k) => parseInt(k, 10))
                          .filter((age) => age >= 0 && age <= 120);
                        const minAge = 18;
                        const maxPresent = present.length
                          ? Math.max(...present)
                          : 60;
                        const maxAge = Math.min(Math.max(maxPresent, 60), 100);
                        return Array.from(
                          { length: maxAge - minAge + 1 },
                          (_, i) => minAge + i
                        );
                      })(),
                      datasets: [
                        {
                          label: "Patients",
                          data: (() => {
                            const hist = analyticsData.ageHistogram || {};
                            const minAge = 18;
                            const labels = (() => {
                              const present = Object.keys(hist)
                                .map((k) => parseInt(k, 10))
                                .filter((age) => age >= 0 && age <= 120);
                              const maxPresent = present.length
                                ? Math.max(...present)
                                : 60;
                              const maxAge = Math.min(
                                Math.max(maxPresent, 60),
                                100
                              );
                              return Array.from(
                                { length: maxAge - minAge + 1 },
                                (_, i) => minAge + i
                              );
                            })();
                            return labels.map((a) => hist[String(a)] || 0);
                          })(),
                          backgroundColor: "#3b82f6", // blue-500
                          borderRadius: 4,
                          borderSkipped: false,
                          barThickness: 14,
                          maxBarThickness: 18,
                          categoryPercentage: 1.0,
                          barPercentage: 1.0,
                        },
                      ],
                    }}
                    options={{
                      maintainAspectRatio: false,
                      plugins: { legend: { display: false } },
                      scales: {
                        x: {
                          grid: { display: false },
                          ticks: {
                            autoSkip: false,
                            maxRotation: 0,
                            minRotation: 0,
                            callback: function (value, index, ticks) {
                              const label = this.getLabelForValue(value);
                              const total = ticks.length;
                              // Dynamic density: show about 10–15 labels
                              const N =
                                total > 45
                                  ? 4
                                  : total > 30
                                  ? 3
                                  : total > 20
                                  ? 2
                                  : 1;
                              return index % N === 0 ? label : "";
                            },
                          },
                        },
                        y: {
                          beginAtZero: true,
                          ticks: { precision: 0 },
                          suggestedMax: (() => {
                            const hist = analyticsData.ageHistogram || {};
                            const vals = Object.values(hist).map(
                              (v) => Number(v) || 0
                            );
                            const maxVal = vals.length ? Math.max(...vals) : 0;
                            const padded = Math.ceil(maxVal * 1.2);
                            return Math.max(10, padded);
                          })(),
                        },
                      },
                    }}
                  />
                </div>
              </div>

              {/* Monthly Registrations */}
              <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center">
                    <TrendingUp className="h-5 w-5 text-purple-600 mr-2" />
                    <h3 className="text-lg font-semibold text-gray-900">
                      Monthly Registrations
                    </h3>
                  </div>
                  <select
                    value={selectedYear}
                    onChange={(e) => setSelectedYear(parseInt(e.target.value))}
                    className="text-sm bg-white border border-gray-300 rounded-md px-3 py-1 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  >
                    {(() => {
                      const currentYear = new Date().getFullYear();
                      const years = [];
                      for (
                        let year = currentYear;
                        year >= currentYear - 10;
                        year--
                      ) {
                        years.push(year);
                      }
                      return years.map((year) => (
                        <option key={year} value={year}>
                          {year}
                        </option>
                      ));
                    })()}
                  </select>
                </div>
                <div className="w-full h-64">
                  <Line
                    data={{
                      labels: Object.keys(
                        analyticsData.monthlyRegistrations || {}
                      ),
                      datasets: [
                        {
                          label: `Registrations ${selectedYear}`,
                          data: Object.values(
                            analyticsData.monthlyRegistrations || {}
                          ),
                          borderColor: "#a855f7", // purple-500
                          backgroundColor: "rgba(168, 85, 247, 0.15)",
                          tension: 0.3,
                          fill: true,
                          pointRadius: 3,
                          pointBackgroundColor: "#7c3aed", // purple-600
                        },
                      ],
                    }}
                    options={{
                      maintainAspectRatio: false,
                      plugins: { legend: { display: false } },
                      scales: {
                        x: { grid: { display: false } },
                        y: {
                          beginAtZero: true,
                          ticks: { precision: 0 },
                          // Ensure at least 10 on the Y-axis; add headroom when data is higher
                          suggestedMax: (() => {
                            const vals = Object.values(
                              analyticsData.monthlyRegistrations || {}
                            ).map((v) => Number(v) || 0);
                            const maxVal = vals.length ? Math.max(...vals) : 0;
                            const padded = Math.ceil(maxVal * 1.2);
                            return Math.max(10, padded);
                          })(),
                        },
                      },
                    }}
                  />
                </div>
                <div className="pt-2 border-t border-gray-200 mt-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-gray-700">
                      Total {selectedYear}:
                    </span>
                    <span className="font-semibold">
                      {Object.values(
                        analyticsData.monthlyRegistrations || {}
                      ).reduce((sum, count) => sum + count, 0)}{" "}
                      patients
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Psychologists Tab */}
        {activeTab === "psychologists" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold text-gray-900">
                Psychologists
              </h2>
              <button
                onClick={() => setShowAddPsychologistModal(true)}
                className="flex items-center px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Psychologist
              </button>
            </div>

            {/* Search Bar for Psychologists */}
            <div className="relative max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search psychologists..."
                value={psychologistSearchTerm}
                onChange={(e) => setPsychologistSearchTerm(e.target.value)}
                className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {psychologists.filter(
                (psychologist) =>
                  psychologist.name
                    .toLowerCase()
                    .includes(psychologistSearchTerm.toLowerCase()) ||
                  psychologist.email
                    .toLowerCase()
                    .includes(psychologistSearchTerm.toLowerCase())
              ).length > 0 ? (
                psychologists
                  .filter(
                    (psychologist) =>
                      psychologist.name
                        .toLowerCase()
                        .includes(psychologistSearchTerm.toLowerCase()) ||
                      psychologist.email
                        .toLowerCase()
                        .includes(psychologistSearchTerm.toLowerCase())
                  )
                  .map((psychologist) => (
                    <PsychologistCard
                      key={psychologist.id}
                      psychologist={psychologist}
                    />
                  ))
              ) : (
                <div className="col-span-full flex flex-col items-center justify-center py-12 text-center">
                  <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                    <Search className="h-8 w-8 text-gray-400" />
                  </div>
                  <h3 className="text-lg font-medium text-gray-900 mb-2">
                    No psychologists found
                  </h3>
                  <p className="text-gray-500 mb-4">
                    {psychologistSearchTerm.trim()
                      ? `No psychologists match "${psychologistSearchTerm}". Try adjusting your search terms.`
                      : "No psychologists have been added yet."}
                  </p>
                  {psychologistSearchTerm.trim() && (
                    <button
                      onClick={() => setPsychologistSearchTerm("")}
                      className="text-emerald-600 hover:text-emerald-700 font-medium"
                    >
                      Clear search
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Patients Tab */}
        {activeTab === "patients" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold text-gray-900">Patients</h2>
              <div className="flex space-x-2">
                {/* Sort Dropdown */}
                <select
                  value={patientSortBy}
                  onChange={(e) => setPatientSortBy(e.target.value)}
                  className="flex items-center px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                >
                  <option value="all">All Patients</option>
                  <option value="assigned">Assigned Patients</option>
                  <option value="unassigned">Unassigned Patients</option>
                  <option value="name">Sort by Name</option>
                </select>
                <button className="flex items-center px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                  <Filter className="h-4 w-4 mr-2" />
                  Filter
                </button>
              </div>
            </div>

            {/* Search Bar for Patients */}
            <div className="relative max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search patients..."
                value={patientSearchTerm}
                onChange={(e) => setPatientSearchTerm(e.target.value)}
                className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              />
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Patient
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Assigned Psychologist
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {(() => {
                      // First filter by search term
                      let filteredPatients = patients.filter((patient) => {
                        const patientName =
                          patient.name ||
                          `${patient.first_name || ""} ${
                            patient.last_name || ""
                          }`.trim() ||
                          patient.email?.split("@")[0] ||
                          "Unknown";

                        return patientName
                          .toLowerCase()
                          .includes(patientSearchTerm.toLowerCase());
                      });

                      // Then apply sorting/filtering by assignment status
                      switch (patientSortBy) {
                        case "assigned":
                          filteredPatients = filteredPatients.filter(
                            (patient) => patient.assigned_psychologist_id
                          );
                          break;
                        case "unassigned":
                          filteredPatients = filteredPatients.filter(
                            (patient) => !patient.assigned_psychologist_id
                          );
                          break;
                        case "name":
                          filteredPatients = filteredPatients.sort((a, b) => {
                            const nameA =
                              a.name ||
                              `${a.first_name || ""} ${
                                a.last_name || ""
                              }`.trim() ||
                              "Unknown";
                            const nameB =
                              b.name ||
                              `${b.first_name || ""} ${
                                b.last_name || ""
                              }`.trim() ||
                              "Unknown";
                            return nameA.localeCompare(nameB);
                          });
                          break;
                        case "all":
                        default:
                          // Sort by assignment status first (assigned first), then by name
                          filteredPatients = filteredPatients.sort((a, b) => {
                            // First priority: assignment status (assigned patients first)
                            const aAssigned = !!a.assigned_psychologist_id;
                            const bAssigned = !!b.assigned_psychologist_id;

                            if (aAssigned !== bAssigned) {
                              return bAssigned - aAssigned; // assigned (true) comes before unassigned (false)
                            }

                            // Second priority: alphabetical by name
                            const nameA =
                              a.name ||
                              `${a.first_name || ""} ${
                                a.last_name || ""
                              }`.trim() ||
                              "Unknown";
                            const nameB =
                              b.name ||
                              `${b.first_name || ""} ${
                                b.last_name || ""
                              }`.trim() ||
                              "Unknown";
                            return nameA.localeCompare(nameB);
                          });
                          break;
                      }

                      if (patients.length > 0 && filteredPatients.length > 0) {
                        return filteredPatients.map((patient) => (
                          <tr key={patient.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                              <div className="flex items-center space-x-3">
                                <div className="flex-shrink-0">
                                  {patient.assigned_psychologist_id ? (
                                    <div
                                      className="w-3 h-3 bg-green-500 rounded-full"
                                      title="Assigned"
                                    ></div>
                                  ) : (
                                    <div
                                      className="w-3 h-3 bg-gray-400 rounded-full"
                                      title="Unassigned"
                                    ></div>
                                  )}
                                </div>
                                <div>
                                  <div className="text-sm font-medium text-gray-900">
                                    {patient.name ||
                                      `${patient.first_name || ""} ${
                                        patient.last_name || ""
                                      }`.trim() ||
                                      patient.email?.split("@")[0] ||
                                      "Unknown"}
                                  </div>
                                </div>
                              </div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <div className="text-sm text-gray-900">
                                {patient.assigned_psychologist_name ? (
                                  <div className="flex items-center space-x-2">
                                    <UserCheck className="h-4 w-4 text-green-600" />
                                    <span className="text-green-600 font-medium">
                                      {patient.assigned_psychologist_name}
                                    </span>
                                  </div>
                                ) : (
                                  <div className="flex items-center space-x-2">
                                    <UserX className="h-4 w-4 text-gray-400" />
                                    <span className="text-gray-400 italic">
                                      Unassigned
                                    </span>
                                  </div>
                                )}
                              </div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                              <div className="flex items-center space-x-2">
                                {/* Assignment button */}
                                <button
                                  onClick={() =>
                                    handleOpenAssignmentModal(patient)
                                  }
                                  className="text-emerald-600 hover:text-emerald-900 px-2 py-1 rounded border border-emerald-600 hover:border-emerald-900 text-xs font-medium transition-colors"
                                >
                                  {patient.assigned_psychologist_id
                                    ? "Reassign"
                                    : "Assign"}
                                </button>

                                {/* View button */}
                                <button
                                  onClick={() => handleViewPatient(patient)}
                                  className="text-blue-600 hover:text-blue-900"
                                >
                                  View
                                </button>
                              </div>
                            </td>
                          </tr>
                        ));
                      } else if (
                        patients.length > 0 &&
                        filteredPatients.length === 0 &&
                        patientSearchTerm
                      ) {
                        // Show no results message when search yields no results
                        return (
                          <tr>
                            <td colSpan="3" className="px-6 py-12 text-center">
                              <div className="flex flex-col items-center justify-center space-y-4">
                                <div className="bg-gray-100 p-3 rounded-full">
                                  <svg
                                    className="h-8 w-8 text-gray-400"
                                    fill="none"
                                    viewBox="0 0 24 24"
                                    stroke="currentColor"
                                  >
                                    <path
                                      strokeLinecap="round"
                                      strokeLinejoin="round"
                                      strokeWidth={2}
                                      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                                    />
                                  </svg>
                                </div>
                                <div className="text-center">
                                  <h3 className="text-lg font-medium text-gray-900 mb-1">
                                    No patients found
                                  </h3>
                                  <p className="text-gray-500 mb-4">
                                    No patients match your search for "
                                    {patientSearchTerm}"
                                  </p>
                                  <button
                                    onClick={() => setPatientSearchTerm("")}
                                    className="text-emerald-600 hover:text-emerald-800 font-medium"
                                  >
                                    Clear search
                                  </button>
                                </div>
                              </div>
                            </td>
                          </tr>
                        );
                      } else {
                        // Show default no patients message
                        return (
                          <tr>
                            <td
                              colSpan="3"
                              className="px-6 py-8 text-center text-gray-500"
                            >
                              {loading
                                ? "Loading patients..."
                                : "No patients found"}
                            </td>
                          </tr>
                        );
                      }
                    })()}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Device Management Tab */}
        {activeTab === "devices" && (
          <DeviceManagement />
        )}

        {/* Activity Tab */}
        {activeTab === "activity" && (
          <div className="space-y-6">
            <h2 className="text-xl font-semibold text-gray-900">
              Recent Activity
            </h2>
            <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
              {loading ? (
                <div className="text-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600 mx-auto"></div>
                  <p className="text-gray-500 mt-2">Loading activity logs...</p>
                </div>
              ) : activityLogs.length > 0 ? (
                (() => {
                  // Calculate pagination
                  const totalPages = Math.ceil(
                    activityLogs.length / itemsPerPage
                  );
                  const startIndex = (currentPage - 1) * itemsPerPage;
                  const endIndex = startIndex + itemsPerPage;
                  const currentLogs = activityLogs.slice(startIndex, endIndex);

                  return (
                    <>
                      <div className="space-y-4">
                        {currentLogs.map((log, index) => (
                          <div
                            key={log.id || index}
                            className="flex items-start space-x-4 p-4 bg-gray-50 rounded-lg border border-gray-100 hover:bg-gray-100 transition-colors"
                          >
                            <div className="flex-shrink-0">
                              <div className="w-8 h-8 bg-emerald-100 rounded-full flex items-center justify-center">
                                <Activity className="h-4 w-4 text-emerald-600" />
                              </div>
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center justify-between">
                                <p className="text-sm font-medium text-gray-900">
                                  {log.action}
                                </p>
                                <span className="text-xs text-gray-500">
                                  {new Date(log.timestamp).toLocaleString()}
                                </span>
                              </div>
                              {log.details && (
                                <p className="text-sm text-gray-600 mt-1">
                                  {log.details}
                                </p>
                              )}
                              {log.user_id && (
                                <p className="text-xs text-gray-400 mt-1">
                                  User ID: {log.user_id}
                                </p>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>

                      {/* Pagination Controls */}
                      {totalPages > 1 && (
                        <div className="flex items-center justify-between mt-6 pt-4 border-t border-gray-200">
                          <div className="text-sm text-gray-500">
                            Showing {startIndex + 1} to{" "}
                            {Math.min(endIndex, activityLogs.length)} of{" "}
                            {activityLogs.length} activity logs
                          </div>
                          <div className="flex items-center space-x-2">
                            <button
                              onClick={() => setCurrentPage(currentPage - 1)}
                              disabled={currentPage === 1}
                              className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
                                currentPage === 1
                                  ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                                  : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                              }`}
                            >
                              Previous
                            </button>

                            {/* Page Numbers */}
                            <div className="flex items-center space-x-1">
                              {Array.from(
                                { length: totalPages },
                                (_, i) => i + 1
                              ).map((pageNum) => {
                                // Show first page, last page, current page, and pages around current
                                const showPage =
                                  pageNum === 1 ||
                                  pageNum === totalPages ||
                                  Math.abs(pageNum - currentPage) <= 1;

                                if (
                                  !showPage &&
                                  pageNum !== 2 &&
                                  pageNum !== totalPages - 1
                                ) {
                                  // Show ellipsis for gaps
                                  if (pageNum === 2 && currentPage > 4) {
                                    return (
                                      <span
                                        key={pageNum}
                                        className="text-gray-400"
                                      >
                                        ...
                                      </span>
                                    );
                                  }
                                  if (
                                    pageNum === totalPages - 1 &&
                                    currentPage < totalPages - 3
                                  ) {
                                    return (
                                      <span
                                        key={pageNum}
                                        className="text-gray-400"
                                      >
                                        ...
                                      </span>
                                    );
                                  }
                                  return null;
                                }

                                return (
                                  <button
                                    key={pageNum}
                                    onClick={() => setCurrentPage(pageNum)}
                                    className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
                                      currentPage === pageNum
                                        ? "bg-emerald-600 text-white"
                                        : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                    }`}
                                  >
                                    {pageNum}
                                  </button>
                                );
                              })}
                            </div>

                            <button
                              onClick={() => setCurrentPage(currentPage + 1)}
                              disabled={currentPage === totalPages}
                              className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
                                currentPage === totalPages
                                  ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                                  : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                              }`}
                            >
                              Next
                            </button>
                          </div>
                        </div>
                      )}
                    </>
                  );
                })()
              ) : (
                <div className="text-center py-8">
                  <Activity className="h-12 w-12 text-gray-300 mx-auto mb-4" />
                  <p className="text-gray-500">No activity logs found</p>
                  <p className="text-sm text-gray-400 mt-1">
                    Activity will appear here as users interact with the system
                  </p>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Add Psychologist Modal */}
      <AddDoctorModal
        show={showAddPsychologistModal}
        onClose={() => setShowAddPsychologistModal(false)}
        onSave={handleAddPsychologist}
        isLoading={isCreatingPsychologist}
      />

      {/* Success Modal */}
      <SuccessModal
        isOpen={showSuccessModal}
        onClose={() => setShowSuccessModal(false)}
        title={successMessage.title}
        message={successMessage.message}
        details={successMessage.details}
        type="success"
      />

      {/* View Psychologist Modal */}
      {showViewModal && selectedPsychologist && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-semibold text-gray-900">
                Psychologist Details
              </h2>
              <button
                onClick={() => setShowViewModal(false)}
                className="p-2 hover:bg-gray-100 rounded-lg"
              >
                <X className="h-5 w-5 text-gray-500" />
              </button>
            </div>

            <div className="space-y-6">
              <div className="flex items-center space-x-4">
                <ProfilePicture
                  patient={selectedPsychologist}
                  size={64}
                  className=""
                />
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">
                    {selectedPsychologist.name}
                  </h3>
                  {selectedPsychologist.specialization && (
                    <p className="text-gray-600">
                      {selectedPsychologist.specialization}
                    </p>
                  )}
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-2 ${
                      selectedPsychologist.is_active
                        ? "bg-green-100 text-green-800"
                        : "bg-yellow-100 text-yellow-800"
                    }`}
                  >
                    {selectedPsychologist.is_active
                      ? "Active"
                      : "Pending Email Verification"}
                  </span>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h4 className="font-medium text-gray-900 mb-3">
                    Contact Information
                  </h4>
                  <div className="space-y-2">
                    <div className="flex items-center text-sm">
                      <Mail className="h-4 w-4 mr-2 text-gray-400" />
                      <span className="text-gray-600">
                        {selectedPsychologist.email}
                      </span>
                    </div>
                    <div className="flex items-center text-sm">
                      <Phone className="h-4 w-4 mr-2 text-gray-400" />
                      <span className="text-gray-600">
                        {selectedPsychologist.contact || "Not provided"}
                      </span>
                    </div>
                  </div>
                </div>

                <div>
                  <h4 className="font-medium text-gray-900 mb-3">
                    Account Information
                  </h4>
                  <div className="space-y-2">
                    <div className="flex items-center text-sm">
                      <Calendar className="h-4 w-4 mr-2 text-gray-400" />
                      <span className="text-gray-600">
                        Joined{" "}
                        {new Date(
                          selectedPsychologist.created_at
                        ).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="flex items-center text-sm">
                      <Users className="h-4 w-4 mr-2 text-gray-400" />
                      <span className="text-gray-600">
                        Sex: {selectedPsychologist.sex}
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Assigned Patients Section */}
              <div>
                <h4 className="font-medium text-gray-900 mb-3 flex items-center">
                  <Users className="h-5 w-5 mr-2 text-emerald-600" />
                  Assigned Patients
                </h4>
                {(() => {
                  const assignedPatients = patients.filter(
                    (patient) =>
                      patient.assigned_psychologist_id ===
                      selectedPsychologist.id
                  );

                  if (assignedPatients.length === 0) {
                    return (
                      <div className="bg-gray-50 rounded-lg p-4 text-center">
                        <div className="text-gray-400 mb-2">
                          <Users className="h-8 w-8 mx-auto" />
                        </div>
                        <p className="text-gray-600 text-sm">
                          No patients assigned yet
                        </p>
                      </div>
                    );
                  }

                  return (
                    <div className="space-y-3">
                      {assignedPatients.map((patient, index) => (
                        <div
                          key={patient.id}
                          className="bg-blue-50 border border-blue-200 rounded-lg p-3"
                        >
                          <div className="flex items-center justify-between">
                            <div className="flex items-center space-x-3">
                              <ProfilePicture
                                patient={patient}
                                size={32}
                                className=""
                              />
                              <div>
                                <p className="font-medium text-blue-900">
                                  {patient.name ||
                                    `${patient.first_name || ""} ${
                                      patient.last_name || ""
                                    }`.trim() ||
                                    patient.email?.split("@")[0] ||
                                    "Unknown Patient"}
                                </p>
                                <p className="text-xs text-blue-600">
                                  {patient.email}
                                </p>
                              </div>
                            </div>
                            <div className="text-right">
                              <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                Assigned
                              </span>
                              {patient.created_at && (
                                <p className="text-xs text-blue-600 mt-1">
                                  Since{" "}
                                  {new Date(
                                    patient.created_at
                                  ).toLocaleDateString()}
                                </p>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                      <div className="text-center pt-2">
                        <p className="text-sm text-gray-600">
                          Total: {assignedPatients.length} patient
                          {assignedPatients.length !== 1 ? "s" : ""}
                        </p>
                      </div>
                    </div>
                  );
                })()}
              </div>

              <div className="flex justify-end pt-4 border-t">
                <button
                  onClick={() => setShowViewModal(false)}
                  className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit Psychologist Modal */}
      {showEditModal && selectedPsychologist && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-lg w-full mx-4">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-semibold text-gray-900">
                Edit Psychologist
              </h2>
              <button
                onClick={() => setShowEditModal(false)}
                className="p-2 hover:bg-gray-100 rounded-lg"
              >
                <X className="h-5 w-5 text-gray-500" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name
                </label>
                <input
                  type="text"
                  defaultValue={selectedPsychologist.name}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  defaultValue={selectedPsychologist.email}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Contact Number
                </label>
                <input
                  type="tel"
                  defaultValue={selectedPsychologist.contact || ""}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Specialization
                </label>
                <input
                  type="text"
                  defaultValue={selectedPsychologist.specialization || ""}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>

            <div className="flex justify-end space-x-3 pt-6 border-t mt-6">
              <button
                onClick={() => setShowEditModal(false)}
                className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  // Add save functionality here
                  alert("Save functionality coming soon!");
                  setShowEditModal(false);
                }}
                className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Loading Overlay for Creating Psychologist */}
      {isCreatingPsychologist && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-8 shadow-2xl flex flex-col items-center space-y-4 max-w-sm mx-4">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
            <div className="text-center">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                Creating Psychologist Account
              </h3>
              <p className="text-sm text-gray-600">
                Please wait while we set up the account and send the invitation
                email...
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirmModal && psychologistToDelete && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-md w-full mx-4">
            <div className="flex items-center justify-center mb-6">
              <div className="bg-red-100 p-3 rounded-full">
                <svg
                  className="h-6 w-6 text-red-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.888-.833-2.664 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                  />
                </svg>
              </div>
            </div>

            <div className="text-center mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                Delete Psychologist
              </h3>
              <p className="text-sm text-gray-600 mb-4">
                Are you sure you want to delete{" "}
                <strong>{psychologistToDelete.name}</strong>?
              </p>
              <p className="text-xs text-red-600">
                This action cannot be undone. All patient assignments and
                records will be removed.
              </p>
            </div>

            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowDeleteConfirmModal(false);
                  setPsychologistToDelete(null);
                }}
                className="flex-1 bg-gray-100 text-gray-900 py-2.5 px-4 rounded-lg hover:bg-gray-200 transition-colors font-medium"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  // Add delete functionality here
                  alert("Delete functionality coming soon!");
                  setShowDeleteConfirmModal(false);
                  setPsychologistToDelete(null);
                }}
                className="flex-1 bg-red-600 text-white py-2.5 px-4 rounded-lg hover:bg-red-700 transition-colors font-medium"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Activate/Deactivate Confirmation Modal */}
      {showActivateConfirmModal && psychologistToToggle && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-md w-full mx-4">
            <div className="flex items-center justify-center mb-6">
              <div
                className={`p-3 rounded-full ${
                  psychologistToToggle.is_active
                    ? "bg-orange-100"
                    : "bg-green-100"
                }`}
              >
                {psychologistToToggle.is_active ? (
                  <svg
                    className="h-6 w-6 text-orange-600"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636M5.636 18.364l12.728-12.728"
                    />
                  </svg>
                ) : (
                  <svg
                    className="h-6 w-6 text-green-600"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                )}
              </div>
            </div>

            <div className="text-center mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {psychologistToToggle.is_active ? "Deactivate" : "Activate"}{" "}
                Psychologist
              </h3>
              <p className="text-sm text-gray-600 mb-4">
                Are you sure you want to{" "}
                {psychologistToToggle.is_active ? "deactivate" : "activate"}{" "}
                <strong>{psychologistToToggle.name}</strong>?
              </p>
              {psychologistToToggle.is_active && (
                <p className="text-xs text-orange-600">
                  ⚠️ This will prevent the psychologist from accessing their
                  account and seeing patients.
                </p>
              )}
            </div>

            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowActivateConfirmModal(false);
                  setPsychologistToToggle(null);
                }}
                className="flex-1 bg-gray-100 text-gray-900 py-2.5 px-4 rounded-lg hover:bg-gray-200 transition-colors font-medium"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  handleDeactivatePsychologist(psychologistToToggle);
                  setShowActivateConfirmModal(false);
                  setPsychologistToToggle(null);
                }}
                className={`flex-1 py-2.5 px-4 rounded-lg transition-colors font-medium text-white ${
                  psychologistToToggle.is_active
                    ? "bg-orange-600 hover:bg-orange-700"
                    : "bg-green-600 hover:bg-green-700"
                }`}
              >
                {psychologistToToggle.is_active ? "Deactivate" : "Activate"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Send Reset Email Confirmation Modal */}
      {showResetEmailModal && psychologistToReset && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-md w-full mx-4">
            <div className="flex items-center justify-center mb-6">
              <div className="bg-blue-100 p-3 rounded-full">
                <svg
                  className="h-6 w-6 text-blue-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                  />
                </svg>
              </div>
            </div>

            <div className="text-center mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                Send Password Reset Email
              </h3>
              <p className="text-sm text-gray-600 mb-4">
                Send a password reset link to{" "}
                <strong>{psychologistToReset.name}</strong>?
              </p>
              <div className="bg-blue-50 p-3 rounded-lg mb-4">
                <p className="text-xs text-blue-700">
                  📧 Reset link will be sent to:{" "}
                  <strong>{psychologistToReset.email}</strong>
                </p>
              </div>
              <p className="text-xs text-gray-500">
                The psychologist will receive an email with instructions to
                reset their password.
              </p>
            </div>

            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowResetEmailModal(false);
                  setPsychologistToReset(null);
                }}
                className="flex-1 bg-gray-100 text-gray-900 py-2.5 px-4 rounded-lg hover:bg-gray-200 transition-colors font-medium"
              >
                Cancel
              </button>
              <button
                onClick={async () => {
                  try {
                    setIsSendingResetEmail(true);
                    const result = await psychologistService.sendResetEmail(
                      psychologistToReset.id
                    );

                    // Show success modal
                    setSuccessMessage({
                      title: "Password Reset Email Sent!",
                      message: `A password reset email has been sent to ${psychologistToReset.email}.`,
                      details: [
                        {
                          type: "info",
                          text: `${psychologistToReset.name} will receive an email with instructions to reset their password.`,
                        },
                        {
                          type: "success",
                          text: "The email should arrive within a few minutes.",
                        },
                      ],
                    });
                    setShowSuccessModal(true);

                    setShowResetEmailModal(false);
                    setPsychologistToReset(null);
                  } catch (error) {
                    console.error("Error sending reset email:", error);
                    alert(`Error sending reset email: ${error.message}`);
                  } finally {
                    setIsSendingResetEmail(false);
                  }
                }}
                disabled={isSendingResetEmail}
                className="flex-1 bg-blue-600 text-white py-2.5 px-4 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
              >
                {isSendingResetEmail ? "Sending..." : "Send Reset Email"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Patient View Modal */}
      {showPatientViewModal && selectedPatient && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            {/* Header */}
            <div className="bg-gradient-to-r from-emerald-600 to-emerald-700 px-6 py-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                    <Users className="h-5 w-5 text-white" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">
                      Patient Details
                    </h3>
                    <p className="text-emerald-100 text-sm">
                      Complete patient information
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setShowPatientViewModal(false)}
                  className="text-white/80 hover:text-white transition-colors p-1"
                >
                  <X className="h-6 w-6" />
                </button>
              </div>
            </div>

            {/* Content */}
            <div className="p-6">
              {/* Patient Name - Featured */}
              <div className="text-center mb-6 pb-4 border-b border-gray-200">
                <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-3 overflow-hidden ring-2 ring-white shadow-sm">
                  <ProfilePicture
                    patient={selectedPatient}
                    size={64}
                    className="h-16 w-16 block"
                  />
                </div>
                <h2 className="text-xl font-bold text-gray-900">
                  {selectedPatient.name}
                </h2>
                <p className="text-gray-500 text-sm mt-1">Patient Profile</p>
              </div>

              {/* Information Grid */}
              <div className="grid grid-cols-1 gap-4">
                {/* Email */}
                <div className="flex items-start space-x-3 p-3 bg-blue-50 rounded-lg">
                  <div className="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                    <Mail className="h-4 w-4 text-blue-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <label className="block text-sm font-medium text-blue-900 mb-1">
                      Email Address
                    </label>
                    <p className="text-blue-800 break-all">
                      {selectedPatient.email}
                    </p>
                  </div>
                </div>

                {/* Contact Number */}
                <div className="flex items-start space-x-3 p-3 bg-green-50 rounded-lg">
                  <div className="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                    <Phone className="h-4 w-4 text-green-600" />
                  </div>
                  <div className="flex-1">
                    <label className="block text-sm font-medium text-green-900 mb-1">
                      Contact Number
                    </label>
                    <p className="text-green-800">
                      {selectedPatient.contact_number || "No contact number"}
                    </p>
                  </div>
                </div>

                {/* Personal Information Row */}
                <div className="grid grid-cols-2 gap-3">
                  {/* Gender */}
                  <div className="flex items-start space-x-2 p-3 bg-purple-50 rounded-lg">
                    <div className="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                      <Users className="h-4 w-4 text-purple-600" />
                    </div>
                    <div className="flex-1">
                      <label className="block text-sm font-medium text-purple-900 mb-1">
                        Gender
                      </label>
                      <p className="text-purple-800">
                        {selectedPatient.gender || "Not specified"}
                      </p>
                    </div>
                  </div>

                  {/* Birth Date */}
                  <div className="flex items-start space-x-2 p-3 bg-orange-50 rounded-lg">
                    <div className="w-8 h-8 bg-orange-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                      <Calendar className="h-4 w-4 text-orange-600" />
                    </div>
                    <div className="flex-1">
                      <label className="block text-sm font-medium text-orange-900 mb-1">
                        Birth Date
                      </label>
                      <p className="text-orange-800">
                        {selectedPatient.birth_date
                          ? new Date(
                              selectedPatient.birth_date
                            ).toLocaleDateString("en-GB")
                          : "Not specified"}
                      </p>
                    </div>
                  </div>
                </div>

                {/* System Information Row */}
                <div className="grid grid-cols-2 gap-3">
                  {/* Date Added */}
                  <div className="flex items-start space-x-2 p-3 bg-gray-50 rounded-lg">
                    <div className="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                      <Clock className="h-4 w-4 text-gray-600" />
                    </div>
                    <div className="flex-1">
                      <label className="block text-sm font-medium text-gray-900 mb-1">
                        Date Added
                      </label>
                      <p className="text-gray-800">
                        {selectedPatient.date_added}
                      </p>
                    </div>
                  </div>

                  {/* Assigned Psychologist */}
                  <div className="flex items-start space-x-2 p-3 bg-emerald-50 rounded-lg">
                    <div className="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                      <UserCheck className="h-4 w-4 text-emerald-600" />
                    </div>
                    <div className="flex-1">
                      <label className="block text-sm font-medium text-emerald-900 mb-1">
                        Assigned Psychologist
                      </label>
                      <p className="text-emerald-800 font-medium">
                        {selectedPatient.assigned_psychologist_name || (
                          <span className="text-gray-500 font-normal italic">
                            Unassigned
                          </span>
                        )}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="bg-gray-50 px-6 py-4 flex justify-end">
              <button
                onClick={() => setShowPatientViewModal(false)}
                className="px-6 py-2.5 bg-gray-800 text-white rounded-lg hover:bg-gray-900 transition-colors font-medium"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Patient Edit Modal */}
      {showPatientEditModal && selectedPatient && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 shadow-2xl max-w-md w-full mx-4">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-gray-900">
                Edit Patient
              </h3>
              <button
                onClick={() => setShowPatientEditModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg
                  className="h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name
                </label>
                <input
                  type="text"
                  defaultValue={selectedPatient.name}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  defaultValue={selectedPatient.email}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Assigned Psychologist
                </label>
                <select className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500">
                  <option value="">No assignment</option>
                  {psychologists.map((psych) => (
                    <option
                      key={psych.id}
                      value={psych.id}
                      selected={
                        psych.id === selectedPatient.assigned_psychologist_id
                      }
                    >
                      {psych.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="flex justify-end space-x-3 mt-6">
              <button
                onClick={() => setShowPatientEditModal(false)}
                className="px-4 py-2 bg-gray-100 text-gray-900 rounded-lg hover:bg-gray-200 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  // TODO: Implement save functionality
                  alert("Save functionality to be implemented");
                  setShowPatientEditModal(false);
                }}
                className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Assignment Modal */}
      {showAssignmentModal && patientToAssign && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-gray-900/60 backdrop-blur-sm transition-opacity"
            onClick={() => {
              setShowAssignmentModal(false);
              setPatientToAssign(null);
            }}
          ></div>

          {/* Modal content */}
          <div className="relative bg-white rounded-lg shadow-xl max-w-lg w-full overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h2 className="text-xl font-semibold text-gray-900">
                {patientToAssign.assigned_psychologist_id
                  ? "Reassign Patient"
                  : "Assign Patient"}
              </h2>
              <button
                onClick={() => {
                  setShowAssignmentModal(false);
                  setPatientToAssign(null);
                }}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="p-6">
              {/* Patient Info Header */}
              <div className="flex items-center space-x-4 mb-6">
                <ProfilePicture
                  userId={patientToAssign.user_id || patientToAssign.id}
                  name={
                    patientToAssign.name ||
                    `${patientToAssign.first_name || ""} ${
                      patientToAssign.last_name || ""
                    }`.trim() ||
                    patientToAssign.email?.split("@")[0] ||
                    "Unknown Patient"
                  }
                  size={48}
                />
                <div>
                  <h3 className="text-lg font-medium text-gray-900">
                    {patientToAssign.name ||
                      `${patientToAssign.first_name || ""} ${
                        patientToAssign.last_name || ""
                      }`.trim() ||
                      patientToAssign.email?.split("@")[0] ||
                      "Unknown Patient"}
                  </h3>
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    Patient
                  </span>
                </div>
              </div>

              {/* Current Assignment */}
              {patientToAssign.assigned_psychologist_id && (
                <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-xl">
                  <div className="flex items-center space-x-2 mb-2">
                    <UserCheck className="h-5 w-5 text-blue-600" />
                    <span className="text-sm font-semibold text-blue-800">
                      Currently Assigned
                    </span>
                  </div>
                  <p className="text-blue-700 font-medium ml-7">
                    {patientToAssign.assigned_psychologist_name ||
                      "Unknown Psychologist"}
                  </p>
                </div>
              )}

              {/* Psychologist Selection */}
              <div className="space-y-4">
                <h4 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                  <User className="h-5 w-5 text-gray-600 mr-2" />
                  {patientToAssign.assigned_psychologist_id
                    ? "Choose New Assignment"
                    : "Choose Psychologist"}
                </h4>

                {/* Unassign option (only if currently assigned) */}
                {patientToAssign.assigned_psychologist_id && (
                  <button
                    onClick={() =>
                      handleAssignmentConfirmation(
                        patientToAssign.id,
                        null,
                        null,
                        true
                      )
                    }
                    className="w-full text-left p-4 border-2 border-red-200 rounded-xl hover:bg-red-50 hover:border-red-300 transition-all duration-200 group"
                  >
                    <div className="flex items-center space-x-3">
                      <div className="flex-shrink-0 w-10 h-10 bg-red-100 rounded-full flex items-center justify-center group-hover:bg-red-200 transition-colors">
                        <UserX className="h-5 w-5 text-red-600" />
                      </div>
                      <div>
                        <div className="text-sm font-semibold text-red-700">
                          Remove Assignment
                        </div>
                        <div className="text-xs text-red-600">
                          Patient will become unassigned
                        </div>
                      </div>
                    </div>
                  </button>
                )}

                {/* List of available psychologists */}
                <div className="space-y-3 max-h-64 overflow-y-auto">
                  {psychologists
                    .filter(
                      (p) =>
                        (p.status === "active" ||
                          p.is_active === true ||
                          !p.hasOwnProperty("status")) &&
                        p.id !== patientToAssign.assigned_psychologist_id
                    )
                    .map((psychologist) => (
                      <button
                        key={psychologist.id}
                        onClick={() =>
                          handleAssignmentConfirmation(
                            patientToAssign.id,
                            psychologist.id,
                            psychologist.name ||
                              `${psychologist.first_name || ""} ${
                                psychologist.last_name || ""
                              }`.trim() ||
                              "Unnamed Psychologist",
                            false
                          )
                        }
                        className="w-full text-left p-4 border-2 border-gray-200 rounded-xl hover:bg-emerald-50 hover:border-emerald-300 hover:shadow-md transition-all duration-200 group"
                      >
                        <div className="flex items-center space-x-3">
                          <div className="flex-shrink-0 w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center group-hover:bg-emerald-200 transition-colors">
                            <UserCheck className="h-5 w-5 text-emerald-600" />
                          </div>
                          <div className="flex-1">
                            <div className="text-sm font-semibold text-gray-900">
                              {psychologist.name ||
                                `${psychologist.first_name || ""} ${
                                  psychologist.last_name || ""
                                }`.trim() ||
                                "Unnamed Psychologist"}
                            </div>
                            <div className="text-xs text-gray-500 mt-1">
                              {psychologist.email}
                            </div>
                          </div>
                          <div className="flex-shrink-0">
                            <div className="w-6 h-6 bg-emerald-600 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                              <svg
                                className="w-3 h-3 text-white"
                                fill="currentColor"
                                viewBox="0 0 20 20"
                              >
                                <path
                                  fillRule="evenodd"
                                  d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                  clipRule="evenodd"
                                />
                              </svg>
                            </div>
                          </div>
                        </div>
                      </button>
                    ))}
                </div>

                {/* No psychologists available */}
                {psychologists.filter(
                  (p) =>
                    (p.status === "active" ||
                      p.is_active === true ||
                      !p.hasOwnProperty("status")) &&
                    p.id !== patientToAssign.assigned_psychologist_id
                ).length === 0 && (
                  <div className="text-center py-12 bg-gray-50 rounded-xl border-2 border-dashed border-gray-300">
                    <div className="flex flex-col items-center space-y-3">
                      <div className="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center">
                        <UserX className="h-8 w-8 text-gray-400" />
                      </div>
                      <div>
                        <p className="text-lg font-medium text-gray-600">
                          No Available Psychologists
                        </p>
                        <p className="text-sm text-gray-400 mt-1 max-w-xs">
                          All psychologists may be inactive or this patient may
                          already be assigned to all available psychologists
                        </p>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Footer */}
            <div className="bg-gray-50 px-6 py-4 border-t border-gray-200">
              <div className="flex justify-end space-x-3">
                <button
                  onClick={() => {
                    setShowAssignmentModal(false);
                    setPatientToAssign(null);
                  }}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Modal */}
      {showConfirmationModal && pendingAssignment && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-gray-900/60 backdrop-blur-sm transition-opacity"
            onClick={() => {
              setShowConfirmationModal(false);
              setPendingAssignment(null);
            }}
          ></div>

          {/* Modal content */}
          <div className="relative bg-white rounded-lg shadow-xl max-w-lg w-full max-h-screen overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h2 className="text-xl font-semibold text-gray-900">
                {pendingAssignment.isUnassign
                  ? "Confirm Unassignment"
                  : "Confirm Assignment"}
              </h2>
              <button
                onClick={() => {
                  setShowConfirmationModal(false);
                  setPendingAssignment(null);
                }}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="h-6 w-6" />
              </button>
            </div>

            {/* Content */}
            <div className="p-6">
              {/* Patient Info Header */}
              <div className="flex items-center space-x-4 mb-6">
                <ProfilePicture
                  userId={pendingAssignment.patientId}
                  name={pendingAssignment.patientName}
                  size={48}
                />
                <div>
                  <h3 className="text-lg font-medium text-gray-900">
                    {pendingAssignment.patientName}
                  </h3>
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    Patient
                  </span>
                </div>
              </div>

              {/* Assignment Details */}
              <div className="grid grid-cols-1 gap-6">
                {pendingAssignment.isUnassign ? (
                  <div>
                    <h4 className="text-sm font-medium text-gray-900 mb-3">
                      Action Details
                    </h4>
                    <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                      <div className="flex items-start space-x-3">
                        <UserX className="h-5 w-5 text-red-600 mt-0.5" />
                        <div>
                          <p className="text-sm font-medium text-red-900">
                            Remove Assignment
                          </p>
                          <p className="text-sm text-red-700 mt-1">
                            This patient will become unassigned and available
                            for reassignment to another psychologist.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div>
                    <h4 className="text-sm font-medium text-gray-900 mb-3">
                      Assignment Details
                    </h4>
                    <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
                      <div className="flex items-start space-x-3">
                        <UserCheck className="h-5 w-5 text-emerald-600 mt-0.5" />
                        <div>
                          <p className="text-sm font-medium text-emerald-900">
                            Assign to Psychologist
                          </p>
                          <p className="text-sm text-gray-600 mt-1">
                            <span className="font-medium text-emerald-700">
                              {pendingAssignment.psychologistName}
                            </span>
                          </p>
                          <p className="text-xs text-emerald-600 mt-2">
                            The psychologist will be notified of this new
                            assignment.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Footer */}
            <div className="bg-gray-50 px-6 py-4 border-t border-gray-200">
              <div className="flex justify-end space-x-3">
                <button
                  onClick={() => {
                    setShowConfirmationModal(false);
                    setPendingAssignment(null);
                  }}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                >
                  Close
                </button>
                <button
                  onClick={confirmAssignment}
                  className={`px-4 py-2 text-sm font-medium text-white rounded-lg focus:outline-none focus:ring-2 transition-colors ${
                    pendingAssignment.isUnassign
                      ? "bg-red-600 hover:bg-red-700 focus:ring-red-500"
                      : "bg-emerald-600 hover:bg-emerald-700 focus:ring-emerald-500"
                  }`}
                >
                  {pendingAssignment.isUnassign
                    ? "Confirm Unassignment"
                    : "Confirm Assignment"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminPanelNew;
