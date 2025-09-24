// Simple Admin Interface for Device Assignment
// Use this in your admin dashboard or as standalone scripts

const admin = require("firebase-admin");

// Initialize Firebase Admin (add your service account key)
// For production, use environment variables for the service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(), // or use service account
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

class AnxieEaseDeviceManager {
  /**
   * Assign device to a user for testing
   * @param {string} userId - The user ID
   * @param {string} sessionDescription - Description of the test session
   * @returns {Promise<string>} - Returns the session ID
   */
  async assignDeviceToUser(
    userId,
    sessionDescription = "Device testing session"
  ) {
    try {
      const sessionId = `session_${Date.now()}`;

      // Check if device is already assigned
      const currentAssignment = await this.getDeviceAssignment();
      if (currentAssignment.assigned) {
        throw new Error(
          `Device is already assigned to user: ${currentAssignment.userId}`
        );
      }

      // Assign device
      await db.ref("devices/AnxieEase001/assignment").set({
        userId: userId,
        sessionId: sessionId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        assignedBy: "admin",
        description: sessionDescription,
        status: "active",
      });

      // Create user session
      await db.ref(`users/${userId}/sessions/${sessionId}/metadata`).set({
        deviceId: "AnxieEase001",
        startTime: admin.database.ServerValue.TIMESTAMP,
        status: "active",
        description: sessionDescription,
        totalDataPoints: 0,
        lastActivity: admin.database.ServerValue.TIMESTAMP,
      });

      console.log(
        `✅ Device assigned to user ${userId} (Session: ${sessionId})`
      );
      return sessionId;
    } catch (error) {
      console.error("❌ Error assigning device:", error.message);
      throw error;
    }
  }

  /**
   * Get current device assignment status
   * @returns {Promise<Object>} - Assignment status
   */
  async getDeviceAssignment() {
    try {
      const snapshot = await db
        .ref("devices/AnxieEase001/assignment")
        .once("value");
      const assignment = snapshot.val();

      if (!assignment) {
        return {
          assigned: false,
          message: "Device is not assigned to any user",
        };
      }

      return {
        assigned: true,
        userId: assignment.userId,
        sessionId: assignment.sessionId,
        assignedAt: assignment.assignedAt,
        description: assignment.description,
        status: assignment.status,
      };
    } catch (error) {
      console.error("❌ Error getting assignment:", error.message);
      throw error;
    }
  }

  /**
   * Unassign device from current user
   * @returns {Promise<void>}
   */
  async unassignDevice() {
    try {
      const currentAssignment = await this.getDeviceAssignment();

      if (!currentAssignment.assigned) {
        console.log("ℹ️ Device is not currently assigned");
        return;
      }

      // Mark session as completed
      await db
        .ref(
          `users/${currentAssignment.userId}/sessions/${currentAssignment.sessionId}/metadata/status`
        )
        .set("completed");
      await db
        .ref(
          `users/${currentAssignment.userId}/sessions/${currentAssignment.sessionId}/metadata/endTime`
        )
        .set(admin.database.ServerValue.TIMESTAMP);

      // Remove assignment
      await db.ref("devices/AnxieEase001/assignment").remove();

      console.log(`✅ Device unassigned from user ${currentAssignment.userId}`);
    } catch (error) {
      console.error("❌ Error unassigning device:", error.message);
      throw error;
    }
  }

  /**
   * Get user session data
   * @param {string} userId - User ID
   * @param {string} sessionId - Session ID
   * @returns {Promise<Object>} - Session data
   */
  async getUserSessionData(userId, sessionId) {
    try {
      const snapshot = await db
        .ref(`users/${userId}/sessions/${sessionId}`)
        .once("value");
      const sessionData = snapshot.val();

      if (!sessionData) {
        throw new Error(`Session not found: ${sessionId} for user ${userId}`);
      }

      return sessionData;
    } catch (error) {
      console.error("❌ Error getting session data:", error.message);
      throw error;
    }
  }

  /**
   * List all sessions for a user
   * @param {string} userId - User ID
   * @returns {Promise<Array>} - List of sessions
   */
  async getUserSessions(userId) {
    try {
      const snapshot = await db.ref(`users/${userId}/sessions`).once("value");
      const sessions = snapshot.val();

      if (!sessions) {
        return [];
      }

      return Object.keys(sessions).map((sessionId) => ({
        sessionId,
        ...sessions[sessionId].metadata,
      }));
    } catch (error) {
      console.error("❌ Error getting user sessions:", error.message);
      throw error;
    }
  }

  /**
   * Send test data to device (simulates wearable device)
   * @param {Object} data - Health data to send
   * @returns {Promise<void>}
   */
  async sendTestData(data = {}) {
    try {
      const testData = {
        heartRate: data.heartRate || Math.floor(Math.random() * 40) + 60, // 60-100 BPM
        spo2: data.spo2 || Math.floor(Math.random() * 5) + 95, // 95-100%
        temperature: data.temperature || Math.random() * 2 + 97, // 97-99°F
        movementLevel: data.movementLevel || Math.floor(Math.random() * 100), // 0-100
        timestamp: Date.now(),
        batteryLevel: data.batteryLevel || Math.floor(Math.random() * 30) + 70, // 70-100%
      };

      // Send to current (real-time)
      await db.ref("devices/AnxieEase001/current").set(testData);

      // Send to history
      await db
        .ref(`devices/AnxieEase001/history/${testData.timestamp}`)
        .set(testData);

      console.log("📤 Test data sent:", testData);
    } catch (error) {
      console.error("❌ Error sending test data:", error.message);
      throw error;
    }
  }

  /**
   * Monitor real-time data flow
   * @param {Function} callback - Called when data is received
   * @returns {Function} - Unsubscribe function
   */
  monitorDataFlow(callback) {
    const deviceCurrentRef = db.ref("devices/AnxieEase001/current");

    deviceCurrentRef.on("value", (snapshot) => {
      const data = snapshot.val();
      if (data) {
        callback("device", data);
      }
    });

    return () => deviceCurrentRef.off();
  }

  /**
   * Real-time assignment status monitor
   * @param {Function} callback - Called when assignment changes
   * @returns {Function} - Unsubscribe function
   */
  monitorAssignmentStatus(callback) {
    const assignmentRef = db.ref("devices/AnxieEase001/assignment");

    assignmentRef.on("value", (snapshot) => {
      const assignment = snapshot.val();
      callback(assignment);
    });

    return () => assignmentRef.off();
  }
}

// Export the class for use in your admin interface
module.exports = AnxieEaseDeviceManager;

// Example usage (uncomment to test):
/*
async function exampleUsage() {
  const deviceManager = new AnxieEaseDeviceManager();
  
  try {
    // Assign device to user
    const sessionId = await deviceManager.assignDeviceToUser('user_123', 'Testing heart rate monitoring');
    
    // Send some test data
    await deviceManager.sendTestData({ heartRate: 85, spo2: 98 });
    
    // Wait a moment for Cloud Functions to process
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Get user session data
    const sessionData = await deviceManager.getUserSessionData('user_123', sessionId);
    console.log('Session data:', sessionData);
    
    // Unassign device
    await deviceManager.unassignDevice();
    
  } catch (error) {
    console.error('Example failed:', error);
  }
}

// Uncomment to run example:
// exampleUsage();
*/
