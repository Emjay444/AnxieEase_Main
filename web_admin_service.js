import { supabase } from "./supabaseClient";

// Mock data for development
const mockActivityLogs = [
  {
    id: "mock-1",
    user_id: "admin",
    action: "Admin Login",
    details: "Admin user logged in to the system",
    timestamp: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: "mock-2",
    user_id: "admin",
    action: "View Psychologists",
    details: "Admin viewed the list of psychologists",
    timestamp: new Date(Date.now() - 7200000).toISOString(),
  },
];

const mockUnassignedPatients = [
  {
    id: "mock-patient-1",
    name: "John Smith",
    email: "john.smith@example.com",
    created_at: new Date(Date.now() - 86400000).toISOString(),
    date_added: new Date(Date.now() - 86400000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 86400000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    is_active: true,
    assigned_psychologist_id: null,
  },
  {
    id: "mock-patient-2",
    name: "Jane Doe",
    email: "jane.doe@example.com",
    created_at: new Date(Date.now() - 172800000).toISOString(),
    date_added: new Date(Date.now() - 172800000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 172800000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    is_active: true,
    assigned_psychologist_id: null,
  },
];

// Mock user data
const mockUsers = [
  {
    id: "user-1",
    name: "John Smith",
    email: "john.smith@example.com",
    role: "patient",
    created_at: new Date(Date.now() - 86400000).toISOString(),
    date_added: new Date(Date.now() - 86400000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 86400000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    assigned_psychologist_id: null,
    is_active: true,
  },
  {
    id: "user-2",
    name: "Jane Doe",
    email: "jane.doe@example.com",
    role: "patient",
    created_at: new Date(Date.now() - 172800000).toISOString(),
    date_added: new Date(Date.now() - 172800000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 172800000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    assigned_psychologist_id: "87364523",
    is_active: true,
  },
  {
    id: "user-3",
    name: "Bob Johnson",
    email: "bob.johnson@example.com",
    role: "patient",
    created_at: new Date(Date.now() - 259200000).toISOString(),
    date_added: new Date(Date.now() - 259200000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 259200000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    assigned_psychologist_id: null,
    is_active: true,
  },
  {
    id: "user-4",
    name: "Sarah Williams",
    email: "sarah.williams@example.com",
    role: "patient",
    created_at: new Date(Date.now() - 345600000).toISOString(),
    date_added: new Date(Date.now() - 345600000).toLocaleDateString("en-GB"),
    time_added: new Date(Date.now() - 345600000).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
    assigned_psychologist_id: "23847659",
    is_active: true,
  },
];

export const adminService = {
  // Helper function to replace UUIDs with names in activity details
  async replaceIdsWithNames(details) {
    if (!details || typeof details !== "string") return details;

    // Manual mapping for known UUIDs (fallback approach)
    const knownUsers = {
      "e0997cb7-68df-41e6-923f-48107872d434": "Jamie Lou Sabeniano Mapalad",
      "627f6a9f-c0f4-47a2-a136-9e280c7f4faa": "Mark Joseph Rosales Molina",
    };

    // First try manual mapping for known problematic UUIDs
    let processedDetails = details;
    for (const [uuid, name] of Object.entries(knownUsers)) {
      const regex = new RegExp(uuid, "gi");
      processedDetails = processedDetails.replace(regex, name);
    }

    // Then try database lookup for any remaining UUIDs
    const uuidRegex =
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
    const remainingUuids = processedDetails.match(uuidRegex);

    if (remainingUuids && remainingUuids.length > 0) {
      // For each remaining UUID, try to get the corresponding name
      for (const uuid of remainingUuids) {
        try {
          // Try different possible ID column names
          let userData = null;

          // First try with 'id' column
          try {
            const { data, error } = await supabase
              .from("user_profiles")
              .select("first_name, last_name, role")
              .eq("id", uuid)
              .maybeSingle();

            if (!error && data) {
              userData = data;
            }
          } catch (err) {
            // Try with 'user_id' column if 'id' fails
            try {
              const { data, error } = await supabase
                .from("user_profiles")
                .select("first_name, last_name, role")
                .eq("user_id", uuid)
                .maybeSingle();

              if (!error && data) {
                userData = data;
              }
            } catch (err2) {
              console.log(
                `Could not resolve UUID ${uuid} with either id or user_id:`,
                err2
              );
            }
          }

          if (userData) {
            const name =
              `${userData.first_name || ""} ${
                userData.last_name || ""
              }`.trim() || `Unknown ${userData.role || "User"}`;

            // Replace the UUID with the name
            processedDetails = processedDetails.replace(
              new RegExp(uuid, "g"),
              name
            );
          }
        } catch (err) {
          // If we can't find the user, leave the UUID as is
          console.log(`Could not resolve UUID ${uuid}:`, err);
        }
      }
    }

    return processedDetails;
  },

  // Get activity logs with optional date filtering
  async getActivityLogs(dateFilter = null) {
    try {
      // Check if activity_logs table exists first
      const { error: tableError } = await supabase
        .from("activity_logs")
        .select("id")
        .limit(1);

      // If table doesn't exist or we don't have access, return mock data
      if (tableError) {
        console.log("Activity logs table not available:", tableError.message);

        // Return filtered mock data if date filter is provided
        if (dateFilter) {
          const filterDate = new Date(dateFilter);
          return mockActivityLogs.filter((log) => {
            const logDate = new Date(log.timestamp);
            return (
              logDate.getDate() === filterDate.getDate() &&
              logDate.getMonth() === filterDate.getMonth() &&
              logDate.getFullYear() === filterDate.getFullYear()
            );
          });
        }

        // Otherwise return all mock data
        return mockActivityLogs;
      }

      // Table exists, proceed with query
      let query = supabase
        .from("activity_logs")
        .select("*")
        .order("timestamp", { ascending: false });

      if (dateFilter) {
        // Format date as ISO string and filter for that day
        const selectedDate = new Date(dateFilter);
        const startOfDay = new Date(
          selectedDate.setHours(0, 0, 0, 0)
        ).toISOString();
        const endOfDay = new Date(
          selectedDate.setHours(23, 59, 59, 999)
        ).toISOString();

        query = query.gte("timestamp", startOfDay).lte("timestamp", endOfDay);
      }

      const { data, error } = await query;

      if (error) {
        console.log("Error fetching activity logs:", error.message);
        return mockActivityLogs;
      }

      // Process the logs to replace UUIDs with names
      if (data && data.length > 0) {
        const processedLogs = await Promise.all(
          data.map(async (log) => ({
            ...log,
            details: await this.replaceIdsWithNames(log.details),
          }))
        );
        return processedLogs;
      }

      return data || [];
    } catch (error) {
      console.error("Get activity logs error:", error.message);
      // Ensure we return at least the mock data
      return mockActivityLogs;
    }
  },

  // Log an activity action
  async logActivity(userId, action, details) {
    try {
      // Get current authenticated user if userId is invalid
      let validUserId = userId;

      // Check if userId is the placeholder or invalid
      if (!userId || userId === "00000000-0000-0000-0000-000000000000") {
        // Try to get current authenticated user
        const { data: authUser } = await supabase.auth.getUser();
        if (authUser?.user?.id) {
          validUserId = authUser.user.id;
        } else {
          // If no auth user, set to null for database
          validUserId = null;
        }
      }

      // Try to insert the activity log
      const { data, error } = await supabase
        .from("activity_logs")
        .insert([
          {
            user_id: validUserId, // Can be null if no valid user
            action,
            details,
            timestamp: new Date().toISOString(),
          },
        ])
        .select();

      if (error) {
        console.log("Using mock activity logging due to error:", error.message);
        // Add to mock logs for the UI to display
        const mockLog = {
          id: `mock-${mockActivityLogs.length + 1}`,
          user_id: validUserId,
          action,
          details,
          timestamp: new Date().toISOString(),
        };
        mockActivityLogs.unshift(mockLog);
        return mockLog;
      }

      return data[0];
    } catch (error) {
      console.error("Log activity error:", error.message);
      // Add to mock logs even on error to ensure UI shows something
      const mockLog = {
        id: `mock-${mockActivityLogs.length + 1}`,
        user_id: null, // Set to null instead of invalid UUID
        action,
        details,
        timestamp: new Date().toISOString(),
      };
      mockActivityLogs.unshift(mockLog);
      return mockLog;
    }
  },

  // Get dashboard statistics
  async getDashboardStats() {
    try {
      // Get count of active psychologists
      const { data: psychologistsCount, error: psychologistsError } =
        await supabase
          .from("psychologists")
          .select("id", { count: "exact" })
          .eq("is_active", true);

      if (psychologistsError) {
        console.error(
          "Error fetching psychologists count:",
          psychologistsError.message
        );
        return {
          psychologistsCount: 0,
          patientsCount: 0,
          unassignedPatientsCount: 0,
        };
      }

      // Get count of all patients from user_profiles table (role 'patient' or blank)
      const { data: patientsCount, error: patientsError } = await supabase
        .from("user_profiles")
        .select("id", { count: "exact" })
        .or("role.eq.patient,role.is.null,role.eq.");

      if (patientsError) {
        console.error("Error fetching patients count:", patientsError.message);
        return {
          psychologistsCount: psychologistsCount.length,
          patientsCount: 0,
          unassignedPatientsCount: 0,
        };
      }

      // Get count of unassigned patients (role 'patient' or blank)
      const { data: unassignedCount, error: unassignedError } = await supabase
        .from("user_profiles")
        .select("id", { count: "exact" })
        .or("role.eq.patient,role.is.null,role.eq.")
        .is("assigned_psychologist_id", null);

      if (unassignedError) {
        console.error(
          "Error fetching unassigned count:",
          unassignedError.message
        );
        return {
          psychologistsCount: psychologistsCount.length,
          patientsCount: patientsCount.length,
          unassignedPatientsCount: 0,
        };
      }

      return {
        psychologistsCount: psychologistsCount.length,
        patientsCount: patientsCount.length,
        unassignedPatientsCount: unassignedCount.length,
      };
    } catch (error) {
      console.error("Get dashboard stats error:", error.message);
      return {
        psychologistsCount: 0,
        patientsCount: 0,
        unassignedPatientsCount: 0,
      };
    }
  },

  // Get unassigned patients
  async getUnassignedPatients() {
    try {
      // Query from the user_profiles table
      const { data, error } = await supabase
        .from("user_profiles")
        .select("*")
        .or("role.eq.patient,role.is.null,role.eq.")
        .is("assigned_psychologist_id", null);

      if (error) {
        console.error("Error fetching unassigned patients:", error.message);
        return [];
      }

      // Process data to match expected format
      return data.map((patient) => ({
        id: patient.id,
        email:
          patient.email ||
          `user-${patient.id.substring(0, 8)}@anxieease.com`,
        name:
          `${patient.first_name || ""} ${patient.last_name || ""}`.trim() ||
          "Unknown",
        role: "patient",
        created_at: patient.created_at,
        date_added: new Date(patient.created_at).toLocaleDateString("en-GB"),
        time_added: new Date(patient.created_at).toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        }),
        assigned_psychologist_id: null,
        is_active: patient.is_email_verified,
      }));
    } catch (error) {
      console.error("Get unassigned patients error:", error.message);
      return [];
    }
  },

  // Get all patients
  async getAllUsers() {
    try {
      // Fetch from user_profiles without strict role filter
      const { data, error } = await supabase
        .from("user_profiles")
        .select(
          `
          *,
          psychologists:assigned_psychologist_id(name)
        `
        );

      if (error) {
        console.error("Get patients error:", error.message);
        return [];
      }

      if (!data || data.length === 0) {
        console.log("getAllUsers: user_profiles returned 0 rows");
        return [];
      }

      // Also fetch psychologists to exclude them from patients list
      const { data: psychRows, error: psychErr } = await supabase
        .from("psychologists")
        .select("id,email");

      if (psychErr) {
        console.log("getAllUsers: psychologists lookup failed:", psychErr.message);
      }

      const psychIdSet = new Set((psychRows || []).map((p) => p.id));
      const psychEmailSet = new Set(
        (psychRows || [])
          .map((p) => (p.email || "").toLowerCase())
          .filter(Boolean)
      );

      // Consider records with role 'patient' (case-insensitive) OR missing/blank role as patients
      // Exclude records that match psychologists by id or email
      const patients = data.filter((u) => {
        const role = (u.role || "").toString().trim().toLowerCase();
        const email = (u.email || "").toLowerCase();
        const isPsychById = psychIdSet.has(u.id);
        const isPsychByEmail = email && psychEmailSet.has(email);
        const classifyAsPatient = role === "patient" || role === "";
        
        return !isPsychById && !isPsychByEmail && classifyAsPatient;
      });

      console.log(`getAllUsers: Found ${patients.length} patients from ${data.length} user_profiles`);

      return patients.map((patient) => ({
        id: patient.id,
        avatar_url: patient.avatar_url || null,
        email:
          patient.email ||
          `${patient.first_name?.toLowerCase() || "user"}.${
            patient.last_name?.toLowerCase() || patient.id.substring(0, 8)
          }@anxieease.com`,
        contact_number: patient.contact_number || "No contact number",
        gender: patient.gender || "Not specified",
        birth_date: patient.birth_date || "Not specified",
        name:
          [patient.first_name, patient.middle_name, patient.last_name]
            .filter(Boolean)
            .join(" ") || "Unknown",
        role: "patient",
        created_at: patient.created_at,
        date_added: new Date(patient.created_at).toLocaleDateString("en-GB"),
        time_added: new Date(patient.created_at).toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        }),
        assigned_psychologist_id: patient.assigned_psychologist_id || null,
        assigned_psychologist_name: patient.psychologists?.name || null,
        is_active: patient.is_email_verified,
      }));
    } catch (error) {
      console.error("Get all users error:", error.message);
      return [];
    }
  },

  // Assign patient to psychologist
  async assignPatientToPsychologist(patientId, psychologistId) {
    try {
      // First get patient name for the activity log
      const { data: patientData, error: patientError } = await supabase
        .from("user_profiles")
        .select("first_name, last_name")
        .eq("id", patientId)
        .single();

      if (patientError) {
        console.error("Error fetching patient data:", patientError.message);
        return { success: false, error: patientError.message };
      }

      let psychologistName = null;
      if (psychologistId) {
        // Try to get psychologist name from psychologists table first
        const { data: psychData, error: psychError } = await supabase
          .from("psychologists")
          .select("name")
          .eq("id", psychologistId)
          .single();

        if (psychError) {
          console.error(
            "Error fetching psychologist data:",
            psychError.message
          );
          // Fallback: try to get from user_profiles table
          const { data: userPsychData, error: userPsychError } = await supabase
            .from("user_profiles")
            .select("first_name, last_name")
            .eq("id", psychologistId)
            .maybeSingle();

          if (!userPsychError && userPsychData) {
            psychologistName =
              `${userPsychData.first_name || ""} ${
                userPsychData.last_name || ""
              }`.trim() || "Unknown Psychologist";
          } else {
            psychologistName = "Unknown Psychologist";
          }
        } else {
          psychologistName = psychData.name || "Unknown Psychologist";
        }
      }

      const patientName =
        `${patientData.first_name || ""} ${
          patientData.last_name || ""
        }`.trim() || "Unknown Patient";

      // Now update the assignment
      const { data, error } = await supabase
        .from("user_profiles")
        .update({ assigned_psychologist_id: psychologistId })
        .eq("id", patientId)
        .select("first_name, last_name");

      if (error) {
        console.error("Error assigning patient:", error.message);
        return { success: false, error: error.message };
      }

      // Get current authenticated user for activity logging
      const { data: authUser } = await supabase.auth.getUser();
      const currentUserId = authUser?.user?.id || null;

      // Log the assignment activity with names instead of IDs
      const actionType = psychologistId
        ? "Patient Assignment"
        : "Patient Unassignment";
      const actionDetails = psychologistId
        ? `Patient ${patientName} assigned to psychologist ${psychologistName}`
        : `Patient ${patientName} unassigned from psychologist`;

      await this.logActivity(currentUserId, actionType, actionDetails);

      return { success: true, data };
    } catch (error) {
      console.error("Assign patient error:", error.message);
      return { success: false, error: error.message };
    }
  },

  // Delete an activity log
  async deleteActivityLog(logId) {
    try {
      const { data, error } = await supabase
        .from("activity_logs")
        .delete()
        .match({ id: logId });

      if (error) {
        console.log("Error deleting activity log:", error.message);
        // Remove from mock logs if using mock data
        const index = mockActivityLogs.findIndex((log) => log.id === logId);
        if (index !== -1) {
          mockActivityLogs.splice(index, 1);
        }
        return { success: true }; // Return success even for mock data
      }

      return { success: true };
    } catch (error) {
      console.error("Delete activity log error:", error.message);
      return { success: false, error: error.message };
    }
  },

  // Get analytics data for dashboard charts
  async getAnalyticsData(year = new Date().getFullYear()) {
    try {
      // Get gender distribution
      const { data: genderData, error: genderError } = await supabase
        .from("user_profiles")
        .select("gender")
        .eq("role", "patient");

      if (genderError) {
        console.error("Error fetching gender data:", genderError.message);
      }

      // Get age distribution (calculate from birth_date)
      const { data: ageData, error: ageError } = await supabase
        .from("user_profiles")
        .select("birth_date")
        .eq("role", "patient")
        .not("birth_date", "is", null);

      if (ageError) {
        console.error("Error fetching age data:", ageError.message);
      }

      // Get monthly registrations for specified year
      const { data: registrationData, error: registrationError } =
        await supabase
          .from("user_profiles")
          .select("created_at")
          .eq("role", "patient")
          .gte("created_at", `${year}-01-01`)
          .lt("created_at", `${year + 1}-01-01`);

      if (registrationError) {
        console.error(
          "Error fetching registration data:",
          registrationError.message
        );
      }

      // Process gender distribution
      const genderStats = {
        male: 0,
        female: 0,
        other: 0,
      };

      if (genderData) {
        genderData.forEach((user) => {
          const gender = user.gender?.toLowerCase();
          if (gender === "male" || gender === "m") {
            genderStats.male++;
          } else if (gender === "female" || gender === "f") {
            genderStats.female++;
          } else {
            genderStats.other++;
          }
        });
      }

      // Process age distribution (bucketed) and exact-age histogram
      const ageStats = {
        "18-25": 0,
        "26-35": 0,
        "36-45": 0,
        "46+": 0,
      };
      const ageHistogram = {}; // { '18': 3, '19': 1, ... }

      if (ageData) {
        const currentDate = new Date();
        ageData.forEach((user) => {
          if (user.birth_date) {
            const birthDate = new Date(user.birth_date);
            const age = currentDate.getFullYear() - birthDate.getFullYear();
            const monthDiff = currentDate.getMonth() - birthDate.getMonth();
            const adjustedAge =
              monthDiff < 0 ||
              (monthDiff === 0 && currentDate.getDate() < birthDate.getDate())
                ? age - 1
                : age;

            // Build exact-age histogram (limit to a reasonable range)
            if (adjustedAge >= 0 && adjustedAge <= 120) {
              const key = String(adjustedAge);
              ageHistogram[key] = (ageHistogram[key] || 0) + 1;
            }

            if (adjustedAge >= 18 && adjustedAge <= 25) {
              ageStats["18-25"]++;
            } else if (adjustedAge >= 26 && adjustedAge <= 35) {
              ageStats["26-35"]++;
            } else if (adjustedAge >= 36 && adjustedAge <= 45) {
              ageStats["36-45"]++;
            } else if (adjustedAge >= 46) {
              ageStats["46+"]++;
            }
          }
        });
      }

      // Process monthly registrations
      const monthlyStats = {
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
      };

      if (registrationData) {
        registrationData.forEach((user) => {
          if (user.created_at) {
            const month = new Date(user.created_at).toLocaleString("default", {
              month: "short",
            });
            if (monthlyStats.hasOwnProperty(month)) {
              monthlyStats[month]++;
            }
          }
        });
      }

      return {
        genderDistribution: genderStats,
        ageDistribution: ageStats,
        ageHistogram,
        monthlyRegistrations: monthlyStats,
        totalPatients: genderData?.length || 0,
      };
    } catch (error) {
      console.error("Error fetching analytics data:", error.message);
      return {
        genderDistribution: { male: 0, female: 0, other: 0 },
        ageDistribution: { "18-25": 0, "26-35": 0, "36-45": 0, "46+": 0 },
        ageHistogram: {},
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
      };
    }
  },
};
