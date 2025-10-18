/**
 * ============================================
 * PSYCHOLOGIST JOURNAL SERVICE
 * ============================================
 * Service for psychologists to view shared patient journals
 * 
 * Usage:
 * 1. Include this file in your psychologist dashboard
 * 2. Initialize with your Supabase credentials
 * 3. Call methods to fetch and display journals
 */

class PsychologistJournalService {
  constructor(supabaseUrl, supabaseKey) {
    this.supabaseUrl = supabaseUrl;
    this.supabaseKey = supabaseKey;
  }

  /**
   * Helper method to make authenticated requests to Supabase
   */
  async _makeRequest(endpoint, options = {}) {
    const url = `${this.supabaseUrl}/rest/v1/${endpoint}`;
    const headers = {
      'apikey': this.supabaseKey,
      'Authorization': `Bearer ${this.supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...options.headers
    };

    const response = await fetch(url, {
      ...options,
      headers
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Supabase request failed: ${error}`);
    }

    return response.json();
  }

  /**
   * Get all shared journals from all assigned patients
   * @param {Object} options - Query options
   * @param {number} options.limit - Maximum number of journals to fetch
   * @param {string} options.orderBy - Field to order by (default: 'date')
   * @param {boolean} options.ascending - Order direction (default: false)
   * @returns {Promise<Array>} Array of journal entries with patient info
   */
  async getAllAssignedPatientsSharedJournals(options = {}) {
    const {
      limit = 100,
      orderBy = 'date',
      ascending = false
    } = options;

    try {
      // Get psychologist's user ID from session
      const psychologistUserId = this._getCurrentUserId();
      if (!psychologistUserId) {
        throw new Error('Not authenticated');
      }

      // First, get the psychologist's ID
      const psychologists = await this._makeRequest(
        `psychologists?user_id=eq.${psychologistUserId}&is_active=eq.true&select=id,first_name,last_name`
      );

      if (!psychologists || psychologists.length === 0) {
        throw new Error('Psychologist profile not found or inactive');
      }

      const psychologistId = psychologists[0].id;

      // Get all shared journals from assigned patients
      const journals = await this._makeRequest(
        `journals?` +
        `shared_with_psychologist=eq.true&` +
        `select=id,date,title,content,created_at,updated_at,` +
        `user_profiles!inner(id,first_name,last_name,email,assigned_psychologist_id)&` +
        `user_profiles.assigned_psychologist_id=eq.${psychologistId}&` +
        `order=${orderBy}.${ascending ? 'asc' : 'desc'}` +
        (limit ? `&limit=${limit}` : '')
      );

      // Format the response
      return journals.map(journal => ({
        id: journal.id,
        date: journal.date,
        title: journal.title,
        content: journal.content,
        created_at: journal.created_at,
        updated_at: journal.updated_at,
        patient: {
          id: journal.user_profiles.id,
          name: `${journal.user_profiles.first_name || ''} ${journal.user_profiles.last_name || ''}`.trim(),
          email: journal.user_profiles.email
        }
      }));
    } catch (error) {
      console.error('Error fetching shared journals:', error);
      throw error;
    }
  }

  /**
   * Get shared journals from a specific patient
   * @param {string} patientId - Patient's user ID
   * @param {number} limit - Maximum number of journals to fetch
   * @returns {Promise<Array>} Array of journal entries
   */
  async getPatientSharedJournals(patientId, limit = 50) {
    try {
      // Get psychologist's user ID
      const psychologistUserId = this._getCurrentUserId();
      if (!psychologistUserId) {
        throw new Error('Not authenticated');
      }

      // Get the psychologist's ID
      const psychologists = await this._makeRequest(
        `psychologists?user_id=eq.${psychologistUserId}&is_active=eq.true&select=id`
      );

      if (!psychologists || psychologists.length === 0) {
        throw new Error('Psychologist profile not found');
      }

      const psychologistId = psychologists[0].id;

      // Verify patient is assigned to this psychologist
      const patients = await this._makeRequest(
        `user_profiles?id=eq.${patientId}&assigned_psychologist_id=eq.${psychologistId}&select=id,first_name,last_name,email`
      );

      if (!patients || patients.length === 0) {
        throw new Error('Patient not assigned to you or does not exist');
      }

      // Get shared journals
      const journals = await this._makeRequest(
        `journals?user_id=eq.${patientId}&shared_with_psychologist=eq.true&order=date.desc&limit=${limit}`
      );

      return journals.map(journal => ({
        ...journal,
        patient_name: `${patients[0].first_name || ''} ${patients[0].last_name || ''}`.trim()
      }));
    } catch (error) {
      console.error('Error fetching patient journals:', error);
      throw error;
    }
  }

  /**
   * Get all assigned patients
   * @returns {Promise<Array>} Array of patients with journal counts
   */
  async getAssignedPatients() {
    try {
      const psychologistUserId = this._getCurrentUserId();
      if (!psychologistUserId) {
        throw new Error('Not authenticated');
      }

      // Get psychologist ID
      const psychologists = await this._makeRequest(
        `psychologists?user_id=eq.${psychologistUserId}&is_active=eq.true&select=id`
      );

      if (!psychologists || psychologists.length === 0) {
        throw new Error('Psychologist profile not found');
      }

      const psychologistId = psychologists[0].id;

      // Get all assigned patients
      const patients = await this._makeRequest(
        `user_profiles?assigned_psychologist_id=eq.${psychologistId}&select=id,first_name,last_name,email,created_at`
      );

      // For each patient, get journal counts
      const patientsWithJournalCounts = await Promise.all(
        patients.map(async (patient) => {
          try {
            const journals = await this._makeRequest(
              `journals?user_id=eq.${patient.id}&select=id,shared_with_psychologist`
            );

            const sharedCount = journals.filter(j => j.shared_with_psychologist).length;

            return {
              id: patient.id,
              name: `${patient.first_name || ''} ${patient.last_name || ''}`.trim(),
              email: patient.email,
              created_at: patient.created_at,
              total_journals: journals.length,
              shared_journals: sharedCount
            };
          } catch (error) {
            console.error(`Error fetching journals for patient ${patient.id}:`, error);
            return {
              id: patient.id,
              name: `${patient.first_name || ''} ${patient.last_name || ''}`.trim(),
              email: patient.email,
              created_at: patient.created_at,
              total_journals: 0,
              shared_journals: 0
            };
          }
        })
      );

      return patientsWithJournalCounts;
    } catch (error) {
      console.error('Error fetching assigned patients:', error);
      throw error;
    }
  }

  /**
   * Search journals by content or date
   * @param {Object} searchParams - Search parameters
   * @param {string} searchParams.keyword - Keyword to search in content
   * @param {string} searchParams.startDate - Start date (YYYY-MM-DD)
   * @param {string} searchParams.endDate - End date (YYYY-MM-DD)
   * @param {string} searchParams.patientId - Filter by specific patient
   * @returns {Promise<Array>} Filtered journals
   */
  async searchJournals(searchParams = {}) {
    try {
      const allJournals = await this.getAllAssignedPatientsSharedJournals({ limit: 1000 });

      let filtered = allJournals;

      // Filter by keyword in content
      if (searchParams.keyword) {
        const keyword = searchParams.keyword.toLowerCase();
        filtered = filtered.filter(j => 
          j.content.toLowerCase().includes(keyword) ||
          (j.title && j.title.toLowerCase().includes(keyword))
        );
      }

      // Filter by date range
      if (searchParams.startDate) {
        filtered = filtered.filter(j => j.date >= searchParams.startDate);
      }
      if (searchParams.endDate) {
        filtered = filtered.filter(j => j.date <= searchParams.endDate);
      }

      // Filter by patient
      if (searchParams.patientId) {
        filtered = filtered.filter(j => j.patient.id === searchParams.patientId);
      }

      return filtered;
    } catch (error) {
      console.error('Error searching journals:', error);
      throw error;
    }
  }

  /**
   * Get journal statistics
   * @returns {Promise<Object>} Statistics about journals
   */
  async getJournalStatistics() {
    try {
      const journals = await this.getAllAssignedPatientsSharedJournals({ limit: 1000 });
      const patients = await this.getAssignedPatients();

      const now = new Date();
      const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      const thisWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

      return {
        total_patients: patients.length,
        total_shared_journals: journals.length,
        journals_this_month: journals.filter(j => new Date(j.date) >= thisMonth).length,
        journals_this_week: journals.filter(j => new Date(j.date) >= thisWeek).length,
        patients_sharing: patients.filter(p => p.shared_journals > 0).length,
        average_journals_per_patient: patients.length > 0 
          ? (journals.length / patients.length).toFixed(1)
          : 0
      };
    } catch (error) {
      console.error('Error calculating statistics:', error);
      throw error;
    }
  }

  /**
   * Helper to get current user ID from Supabase session
   * You'll need to implement this based on how you manage authentication
   */
  _getCurrentUserId() {
    // Option 1: From Supabase auth (if you're using @supabase/supabase-js)
    if (typeof supabase !== 'undefined') {
      const session = supabase.auth.getSession();
      return session?.user?.id;
    }

    // Option 2: From localStorage (common pattern)
    const session = localStorage.getItem('supabase.auth.token');
    if (session) {
      try {
        const parsed = JSON.parse(session);
        return parsed?.currentSession?.user?.id;
      } catch (e) {
        console.error('Error parsing session:', e);
      }
    }

    // Option 3: You can also pass it manually
    return this.psychologistUserId;
  }

  /**
   * Set the psychologist user ID manually (if not using session)
   */
  setPsychologistUserId(userId) {
    this.psychologistUserId = userId;
  }

  /**
   * Format date for display
   */
  formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }

  /**
   * Format relative time (e.g., "2 days ago")
   */
  formatRelativeTime(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
    if (diffDays < 365) return `${Math.floor(diffDays / 30)} months ago`;
    return `${Math.floor(diffDays / 365)} years ago`;
  }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PsychologistJournalService;
}
