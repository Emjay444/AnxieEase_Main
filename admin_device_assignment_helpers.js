// Device Assignment Management Utilities
// Use these functions to manage device assignments from your admin interface

/**
 * Assign device to a user via Firebase Cloud Function
 */
async function assignDeviceToUser(userId, sessionId, adminNotes = '') {
  try {
    const functions = firebase.functions();
    const assignDevice = functions.httpsCallable('assignDeviceToUser');
    
    const result = await assignDevice({
      userId: userId,
      sessionId: sessionId,
      action: 'assign',
      adminNotes: adminNotes
    });
    
    console.log('✅ Device assigned successfully:', result.data);
    return result.data;
  } catch (error) {
    console.error('❌ Error assigning device:', error);
    throw error;
  }
}

/**
 * Unassign device from current user
 */
async function unassignDevice() {
  try {
    const functions = firebase.functions();
    const assignDevice = functions.httpsCallable('assignDeviceToUser');
    
    const result = await assignDevice({
      action: 'unassign'
    });
    
    console.log('✅ Device unassigned successfully:', result.data);
    return result.data;
  } catch (error) {
    console.error('❌ Error unassigning device:', error);
    throw error;
  }
}

/**
 * Get current device assignment status
 */
async function getDeviceAssignmentStatus() {
  try {
    const functions = firebase.functions();
    const getAssignment = functions.httpsCallable('getDeviceAssignment');
    
    const result = await getAssignment();
    console.log('📊 Device assignment status:', result.data);
    return result.data;
  } catch (error) {
    console.error('❌ Error getting assignment status:', error);
    throw error;
  }
}

/**
 * Listen to device assignment changes in real-time
 */
function listenToDeviceAssignment(callback) {
  const database = firebase.database();
  const assignmentRef = database.ref('/devices/AnxieEase001/assignment');
  
  return assignmentRef.on('value', (snapshot) => {
    const assignment = snapshot.val();
    callback(assignment);
  });
}

/**
 * Listen to user session data in real-time
 */
function listenToUserSession(userId, sessionId, callback) {
  const database = firebase.database();
  const sessionRef = database.ref(`/users/${userId}/sessions/${sessionId}`);
  
  return sessionRef.on('value', (snapshot) => {
    const sessionData = snapshot.val();
    callback(sessionData);
  });
}

/**
 * Get user session history data
 */
async function getUserSessionHistory(userId, sessionId, limit = 100) {
  try {
    const database = firebase.database();
    const historyRef = database.ref(`/users/${userId}/sessions/${sessionId}/history`);
    
    const snapshot = await historyRef
      .orderByKey()
      .limitToLast(limit)
      .once('value');
    
    return snapshot.val() || {};
  } catch (error) {
    console.error('❌ Error getting session history:', error);
    throw error;
  }
}

/**
 * Generate a new session ID
 */
function generateSessionId() {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  return `session_${timestamp}_${random}`;
}

/**
 * Example: Admin interface usage
 */
async function adminAssignDeviceExample() {
  try {
    // Check current assignment
    const currentStatus = await getDeviceAssignmentStatus();
    
    if (currentStatus.assigned) {
      console.log(`Device currently assigned to: ${currentStatus.assignedUser}`);
      
      // Unassign first
      await unassignDevice();
      console.log('Device unassigned');
    }
    
    // Assign to new user
    const newUserId = 'user_789';
    const newSessionId = generateSessionId();
    
    await assignDeviceToUser(newUserId, newSessionId, 'Testing session for new user');
    console.log(`Device assigned to ${newUserId} with session ${newSessionId}`);
    
    // Listen for real-time updates
    listenToUserSession(newUserId, newSessionId, (sessionData) => {
      console.log('Session updated:', sessionData);
    });
    
  } catch (error) {
    console.error('Error in admin assignment:', error);
  }
}

// Export functions if using modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    assignDeviceToUser,
    unassignDevice,
    getDeviceAssignmentStatus,
    listenToDeviceAssignment,
    listenToUserSession,
    getUserSessionHistory,
    generateSessionId,
    adminAssignDeviceExample
  };
}