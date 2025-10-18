/**
 * ============================================
 * EXAMPLE: HOW TO USE THE JOURNAL SERVICE IN YOUR PSYCHOLOGIST DASHBOARD
 * ============================================
 */

// ==========================================
// 1. INITIALIZATION
// ==========================================

// Initialize the service with your Supabase credentials
const journalService = new PsychologistJournalService(
  'https://gqsustjxzjzfntcsnvpk.supabase.co', // Your Supabase URL
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' // Your Supabase Anon Key
);

// ==========================================
// 2. GET ALL SHARED JOURNALS FROM ASSIGNED PATIENTS
// ==========================================

async function loadAllSharedJournals() {
  try {
    const journals = await journalService.getAllAssignedPatientsSharedJournals({
      limit: 50,
      orderBy: 'date',
      ascending: false
    });

    console.log(`Found ${journals.length} shared journals`);
    
    // Display journals
    journals.forEach(journal => {
      console.log(`
        Patient: ${journal.patient.name}
        Date: ${journal.date}
        Content: ${journal.content.substring(0, 100)}...
      `);
    });

    return journals;
  } catch (error) {
    console.error('Error loading journals:', error);
  }
}

// ==========================================
// 3. GET JOURNALS FROM A SPECIFIC PATIENT
// ==========================================

async function loadPatientJournals(patientId) {
  try {
    const journals = await journalService.getPatientSharedJournals(patientId, 20);
    
    console.log(`Found ${journals.length} journals from patient`);
    return journals;
  } catch (error) {
    console.error('Error loading patient journals:', error);
  }
}

// ==========================================
// 4. GET LIST OF ALL ASSIGNED PATIENTS
// ==========================================

async function loadPatientList() {
  try {
    const patients = await journalService.getAssignedPatients();
    
    patients.forEach(patient => {
      console.log(`
        ${patient.name} (${patient.email})
        Total Journals: ${patient.total_journals}
        Shared: ${patient.shared_journals}
      `);
    });

    return patients;
  } catch (error) {
    console.error('Error loading patients:', error);
  }
}

// ==========================================
// 5. SEARCH JOURNALS
// ==========================================

async function searchPatientJournals() {
  try {
    const results = await journalService.searchJournals({
      keyword: 'anxiety',          // Search for keyword
      startDate: '2025-01-01',     // From this date
      endDate: '2025-10-19',       // To this date
      patientId: 'optional-id'     // Optional: filter by patient
    });

    console.log(`Found ${results.length} matching journals`);
    return results;
  } catch (error) {
    console.error('Error searching journals:', error);
  }
}

// ==========================================
// 6. GET STATISTICS
// ==========================================

async function loadStatistics() {
  try {
    const stats = await journalService.getJournalStatistics();
    
    console.log(`
      Total Patients: ${stats.total_patients}
      Total Shared Journals: ${stats.total_shared_journals}
      This Month: ${stats.journals_this_month}
      This Week: ${stats.journals_this_week}
      Patients Sharing: ${stats.patients_sharing}
      Average per Patient: ${stats.average_journals_per_patient}
    `);

    return stats;
  } catch (error) {
    console.error('Error loading statistics:', error);
  }
}

// ==========================================
// 7. DISPLAY JOURNALS IN HTML
// ==========================================

async function displayJournalsInDashboard() {
  const journals = await journalService.getAllAssignedPatientsSharedJournals({ limit: 20 });
  const container = document.getElementById('journals-container');
  
  container.innerHTML = journals.map(journal => `
    <div class="journal-card">
      <div class="journal-header">
        <h3>${journal.patient.name}</h3>
        <span class="journal-date">${journalService.formatDate(journal.date)}</span>
        <span class="journal-time">${journalService.formatRelativeTime(journal.created_at)}</span>
      </div>
      <div class="journal-content">
        ${journal.title ? `<h4>${journal.title}</h4>` : ''}
        <p>${journal.content}</p>
      </div>
    </div>
  `).join('');
}

// ==========================================
// 8. EXAMPLE: DASHBOARD WITH FILTERING
// ==========================================

class JournalDashboard {
  constructor() {
    this.journalService = new PsychologistJournalService(
      'YOUR_SUPABASE_URL',
      'YOUR_SUPABASE_KEY'
    );
    this.currentFilter = 'all';
  }

  async init() {
    // Load initial data
    await this.loadPatients();
    await this.loadJournals();
    await this.loadStats();
  }

  async loadPatients() {
    const patients = await this.journalService.getAssignedPatients();
    this.renderPatientList(patients);
  }

  async loadJournals(patientId = null) {
    let journals;
    
    if (patientId) {
      journals = await this.journalService.getPatientSharedJournals(patientId);
    } else {
      journals = await this.journalService.getAllAssignedPatientsSharedJournals();
    }
    
    this.renderJournals(journals);
  }

  async loadStats() {
    const stats = await this.journalService.getJournalStatistics();
    this.renderStatistics(stats);
  }

  renderPatientList(patients) {
    const container = document.getElementById('patient-list');
    container.innerHTML = `
      <div class="patient-item" onclick="dashboard.loadJournals()">
        <strong>All Patients</strong>
      </div>
      ${patients.map(patient => `
        <div class="patient-item" onclick="dashboard.loadJournals('${patient.id}')">
          <strong>${patient.name}</strong>
          <span class="badge">${patient.shared_journals} shared</span>
        </div>
      `).join('')}
    `;
  }

  renderJournals(journals) {
    const container = document.getElementById('journal-list');
    
    if (journals.length === 0) {
      container.innerHTML = '<p class="empty-state">No shared journals yet</p>';
      return;
    }

    container.innerHTML = journals.map(journal => `
      <div class="journal-card">
        <div class="journal-meta">
          <span class="patient-name">${journal.patient.name}</span>
          <span class="date">${this.journalService.formatDate(journal.date)}</span>
        </div>
        ${journal.title ? `<h3>${journal.title}</h3>` : ''}
        <div class="journal-text">${journal.content}</div>
        <div class="journal-footer">
          <small>${this.journalService.formatRelativeTime(journal.created_at)}</small>
        </div>
      </div>
    `).join('');
  }

  renderStatistics(stats) {
    document.getElementById('stats-container').innerHTML = `
      <div class="stat-card">
        <h4>${stats.total_patients}</h4>
        <p>Total Patients</p>
      </div>
      <div class="stat-card">
        <h4>${stats.total_shared_journals}</h4>
        <p>Shared Journals</p>
      </div>
      <div class="stat-card">
        <h4>${stats.journals_this_week}</h4>
        <p>This Week</p>
      </div>
      <div class="stat-card">
        <h4>${stats.patients_sharing}</h4>
        <p>Patients Sharing</p>
      </div>
    `;
  }
}

// Initialize dashboard
const dashboard = new JournalDashboard();
dashboard.init();
