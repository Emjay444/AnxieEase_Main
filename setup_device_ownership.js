// Firebase Device Ownership Setup Script
// Run this script to set up device ownership records in your Firebase database

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// Download your service account key from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./path/to/your/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://your-project-id-default-rtdb.firebaseio.com/' // Replace with your database URL
});

const db = admin.database();

async function setupDeviceOwnership() {
  try {
    // Example: Set up AnxieEase001 device ownership
    const deviceId = 'AnxieEase001';
    const userId = 'YOUR_USER_ID_HERE'; // Replace with actual user ID from Firebase Auth
    
    const deviceOwnership = {
      userId: userId,
      deviceType: 'AnxieEase_Wearable',
      createdAt: admin.database.ServerValue.TIMESTAMP,
      isActive: true,
      deviceName: 'AnxieEase Device 001',
      sharedWith: {} // Can add other user IDs here for sharing
    };

    await db.ref(`device_ownership/${deviceId}`).set(deviceOwnership);
    
    console.log(`✅ Successfully set up ownership for device ${deviceId}`);
    console.log(`👤 Owner: ${userId}`);
    
    // Also create initial metadata for the device
    const deviceMetadata = {
      deviceType: 'AnxieEase_Wearable',
      status: 'active',
      isSimulated: false,
      lastSeen: admin.database.ServerValue.TIMESTAMP,
      firmwareVersion: '1.0.0'
    };

    await db.ref(`devices/${deviceId}/metadata`).set(deviceMetadata);
    console.log(`✅ Device metadata initialized for ${deviceId}`);
    
  } catch (error) {
    console.error('❌ Error setting up device ownership:', error);
  } finally {
    admin.app().delete();
  }
}

// Function to add a new device for a user
async function addUserDevice(userId, deviceId, deviceType = 'AnxieEase_Wearable') {
  try {
    const deviceOwnership = {
      userId: userId,
      deviceType: deviceType,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      isActive: true,
      deviceName: `${deviceType} ${deviceId}`,
      sharedWith: {}
    };

    await db.ref(`device_ownership/${deviceId}`).set(deviceOwnership);
    console.log(`✅ Device ${deviceId} registered to user ${userId}`);
    
    return true;
  } catch (error) {
    console.error('❌ Error adding device:', error);
    return false;
  }
}

// Function to share device access
async function shareDevice(deviceId, ownerUserId, shareWithUserId) {
  try {
    // Verify ownership first
    const ownership = await db.ref(`device_ownership/${deviceId}`).once('value');
    if (!ownership.exists() || ownership.val().userId !== ownerUserId) {
      throw new Error('Device not found or user is not the owner');
    }
    
    await db.ref(`device_ownership/${deviceId}/sharedWith/${shareWithUserId}`).set({
      grantedAt: admin.database.ServerValue.TIMESTAMP,
      permissions: ['read'] // Can be 'read', 'write', or both
    });
    
    console.log(`✅ Device ${deviceId} shared with user ${shareWithUserId}`);
    return true;
  } catch (error) {
    console.error('❌ Error sharing device:', error);
    return false;
  }
}

// Run the setup
if (require.main === module) {
  setupDeviceOwnership();
}

module.exports = {
  setupDeviceOwnership,
  addUserDevice,
  shareDevice
};