# 🧪 Device Assignment Testing Guide for AnxieEase

## Overview
Your AnxieEase system has multiple ways to handle device assignments. This guide shows you how to test each method.

## 🎯 Testing Methods Available

### 1. **Admin Device Manager (Node.js)**
**File**: `admin_device_manager.js`
**Best for**: Direct Firebase testing, debugging device assignments

```javascript
const AnxieEaseDeviceManager = require('./admin_device_manager.js');
const deviceManager = new AnxieEaseDeviceManager();

// Test assignment
async function testDeviceAssignment() {
  try {
    // 1. Assign device to user
    const sessionId = await deviceManager.assignDeviceToUser(
      'user_123', 
      'Testing heart rate detection accuracy'
    );
    console.log('✅ Device assigned, session:', sessionId);
    
    // 2. Send test data
    await deviceManager.sendTestData({
      heartRate: 85,
      spo2: 98,
      bodyTemp: 98.6,
      worn: 1
    });
    
    // 3. Check assignment status
    const status = await deviceManager.getDeviceAssignment();
    console.log('📊 Assignment status:', status);
    
    // 4. Get user session data
    const sessionData = await deviceManager.getUserSessionData('user_123', sessionId);
    console.log('📈 User session data:', sessionData);
    
    // 5. Unassign when done
    await deviceManager.unassignDevice();
    console.log('✅ Device unassigned');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

testDeviceAssignment();
```

### 2. **Web Admin Dashboard**
**File**: `web_unified_device_management.jsx`
**Best for**: Production admin interface with GUI

```javascript
// In your web browser console (when admin dashboard is open)
const unifiedDeviceService = new UnifiedDeviceService();

// Test assignment through web interface
async function testWebAssignment() {
  try {
    // 1. Get available devices
    const devices = await unifiedDeviceService.getAllDevices();
    console.log('Available devices:', devices);
    
    // 2. Get available patients
    const patients = await unifiedDeviceService.getAvailablePatients();
    console.log('Available patients:', patients);
    
    // 3. Assign device to patient
    await unifiedDeviceService.assignDeviceToUser(
      'AnxieEase001',
      'user_123',
      new Date(Date.now() + 24*60*60*1000), // Expires in 24 hours
      'Testing anxiety detection system'
    );
    
    // 4. Check assignment
    const deviceInfo = await unifiedDeviceService.getDeviceInfo('AnxieEase001');
    console.log('Device assignment info:', deviceInfo);
    
  } catch (error) {
    console.error('Web assignment test failed:', error);
  }
}

testWebAssignment();
```

### 3. **Flutter App Testing**
**Files**: `admin_assigned_device_screen.dart`, `testing_device_assignment_screen.dart`
**Best for**: Testing mobile app device assignment flow

```dart
// In your Flutter app debug console or test file
void testMobileAssignment() async {
  final adminDeviceService = AdminDeviceManagementService();
  
  // Test admin-managed assignment
  final assignmentStatus = await adminDeviceService.checkDeviceAssignment();
  
  print('Assignment status: ${assignmentStatus.status}');
  print('Device ID: ${assignmentStatus.deviceId}');
  print('Expires at: ${assignmentStatus.expiresAt}');
  
  if (assignmentStatus.status == DeviceAssignmentStatusType.assigned) {
    print('✅ Device is assigned to current user');
    
    // Test device sharing service
    final deviceSharingService = DeviceSharingService();
    final isAssigned = await deviceSharingService.isDeviceAssignedToCurrentUser();
    print('Device sharing service confirms: $isAssigned');
    
    // Get user's virtual device ID
    final virtualDeviceId = await deviceSharingService.getCurrentUserDeviceId();
    print('Virtual device ID: $virtualDeviceId');
  }
}
```

## 🔍 **Firebase Structure to Monitor**

When testing, watch these Firebase paths:

### Device Assignment Path:
```
/devices/
└── AnxieEase001/
    ├── assignment/
    │   ├── assignedUser: "user_123"
    │   ├── activeSessionId: "session_1727234567890"
    │   ├── assignedAt: 1727234567890
    │   ├── assignedBy: "admin"
    │   └── status: "active"
    ├── current/
    │   ├── heartRate: 85
    │   ├── spo2: 98
    │   ├── timestamp: 1727234567890
    │   └── worn: 1
    └── history/
        └── 1727234567890/
            ├── heartRate: 85
            └── timestamp: 1727234567890
```

### User Session Path:
```
/users/
└── user_123/
    └── sessions/
        └── session_1727234567890/
            ├── metadata/
            │   ├── deviceId: "AnxieEase001"
            │   ├── startTime: 1727234567890
            │   └── status: "active"
            ├── current/
            │   ├── heartRate: 85
            │   └── lastUpdated: 1727234567890
            └── data/
                └── 1727234567890/
                    ├── heartRate: 85
                    └── timestamp: 1727234567890
```

## 🧪 **Step-by-Step Testing Scenarios**

### Scenario 1: Basic Assignment Test
```bash
# 1. Run in PowerShell/Terminal
cd "C:\Users\molin\OneDrive\Desktop\Capstone\AnxieEase\AnxieEase_Main"
node -e "
const deviceManager = require('./admin_device_manager.js');
const manager = new deviceManager();
manager.assignDeviceToUser('test_user_001', 'Basic assignment test')
  .then(sessionId => console.log('Session created:', sessionId))
  .catch(err => console.error('Error:', err));
"
```

### Scenario 2: Real-time Data Flow Test
```javascript
// In Node.js environment
const deviceManager = new AnxieEaseDeviceManager();

// Step 1: Assign device
const sessionId = await deviceManager.assignDeviceToUser('test_user_001', 'Data flow test');

// Step 2: Start monitoring user data
const unsubscribe = deviceManager.monitorDataFlow((source, data) => {
  console.log(`📊 Data from ${source}:`, data);
});

// Step 3: Send test data every 10 seconds
const interval = setInterval(async () => {
  await deviceManager.sendTestData({
    heartRate: Math.floor(Math.random() * 40) + 60, // 60-100 BPM
    spo2: Math.floor(Math.random() * 5) + 95, // 95-100%
    bodyTemp: (Math.random() * 2) + 97.5, // 97.5-99.5°F
    worn: 1
  });
  console.log('📤 Test data sent');
}, 10000);

// Step 4: Stop after 2 minutes
setTimeout(async () => {
  clearInterval(interval);
  unsubscribe();
  await deviceManager.unassignDevice();
  console.log('✅ Test completed');
}, 120000);
```

### Scenario 3: Multi-User Assignment Test
```javascript
// Test what happens when device is already assigned
async function testMultiUserConflict() {
  const deviceManager = new AnxieEaseDeviceManager();
  
  try {
    // Assign to first user
    await deviceManager.assignDeviceToUser('user_001', 'First assignment');
    console.log('✅ First user assigned');
    
    // Try to assign to second user (should fail)
    await deviceManager.assignDeviceToUser('user_002', 'Second assignment');
    console.log('❌ This should not happen!');
    
  } catch (error) {
    console.log('✅ Correctly prevented double assignment:', error.message);
  }
  
  // Clean up
  await deviceManager.unassignDevice();
}

testMultiUserConflict();
```

## 🔧 **Testing Your Anxiety Detection**

### Test Sustained Anxiety Detection
```javascript
async function testAnxietyDetection() {
  const deviceManager = new AnxieEaseDeviceManager();
  
  // 1. Assign device
  const sessionId = await deviceManager.assignDeviceToUser('test_user_anxiety', 'Anxiety detection test');
  
  // 2. Send normal heart rate first
  for (let i = 0; i < 5; i++) {
    await deviceManager.sendTestData({
      heartRate: 70 + Math.floor(Math.random() * 10), // 70-80 BPM (normal)
      spo2: 98,
      worn: 1
    });
    await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
  }
  
  // 3. Send elevated heart rate for 30+ seconds (should trigger anxiety detection)
  console.log('🚨 Starting elevated heart rate simulation...');
  for (let i = 0; i < 4; i++) {
    await deviceManager.sendTestData({
      heartRate: 95 + Math.floor(Math.random() * 10), // 95-105 BPM (elevated)
      spo2: 97,
      worn: 1
    });
    console.log(`📤 Elevated HR sent (${i + 1}/4)`);
    await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
  }
  
  // 4. Wait and check if anxiety alert was triggered
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  // 5. Clean up
  await deviceManager.unassignDevice();
  console.log('✅ Anxiety detection test completed');
}

testAnxietyDetection();
```

## 🎮 **Quick Test Commands**

### Test Device Assignment (PowerShell)
```powershell
cd "C:\Users\molin\OneDrive\Desktop\Capstone\AnxieEase\AnxieEase_Main"

# Quick assign test
node -e "const dm = new (require('./admin_device_manager.js'))(); dm.assignDeviceToUser('quick_test', 'Quick test').then(s => console.log('Session:', s))"

# Quick status check
node -e "const dm = new (require('./admin_device_manager.js'))(); dm.getDeviceAssignment().then(s => console.log('Status:', s))"

# Quick unassign
node -e "const dm = new (require('./admin_device_manager.js'))(); dm.unassignDevice().then(() => console.log('Unassigned'))"
```

### Monitor Assignment Changes (Real-time)
```javascript
// Run this in Node.js to watch assignment changes
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: "https://anxieease-sensors-default-rtdb.firebaseio.com"
});

const db = admin.database();
const assignmentRef = db.ref('/devices/AnxieEase001/assignment');

assignmentRef.on('value', (snapshot) => {
  const assignment = snapshot.val();
  console.log('📊 Assignment changed:', assignment);
});

console.log('👀 Monitoring device assignment changes...');
```

## 🚀 **Production Testing Checklist**

- [ ] **Assignment Works**: Device can be assigned to users
- [ ] **Data Flows**: Device data reaches user sessions
- [ ] **Conflict Prevention**: Can't assign device to multiple users
- [ ] **Unassignment Works**: Device can be released properly
- [ ] **Session Cleanup**: Old sessions are cleaned up
- [ ] **Real-time Updates**: Data updates in real-time
- [ ] **Anxiety Detection**: Sustained detection triggers alerts
- [ ] **Mobile App Integration**: Flutter app shows assignment status
- [ ] **Web Dashboard**: Admin can manage assignments via web interface
- [ ] **Multi-User Support**: Multiple users can use device sequentially

## 📱 **Testing Your New Anxiety Detection Cloud Function**

Since we just fixed your `realTimeSustainedAnxietyDetection`, test it:

```javascript
// Test with your corrected Cloud Function
async function testNewAnxietyFunction() {
  const deviceManager = new AnxieEaseDeviceManager();
  
  // 1. Assign device (creates proper assignment structure)
  const sessionId = await deviceManager.assignDeviceToUser('anxiety_test_user', 'Testing new anxiety function');
  
  // 2. Send elevated data to trigger the Cloud Function
  await deviceManager.sendTestData({
    heartRate: 95, // Above typical 70 BPM baseline
    spo2: 97,
    worn: 1
  });
  
  // 3. The Cloud Function should:
  // - Check device assignment ✅
  // - Get user baseline ✅ 
  // - Analyze user session history ✅
  // - Send user-specific notification ✅
  
  console.log('✅ New anxiety detection Cloud Function triggered!');
  
  // Clean up
  await deviceManager.unassignDevice();
}

testNewAnxietyFunction();
```

This testing guide covers all your device assignment methods! Which testing scenario would you like to start with?