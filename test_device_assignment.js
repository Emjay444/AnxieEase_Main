// Quick Device Assignment Test Script
// Run this to test your device assignment system

const AnxieEaseDeviceManager = require('./admin_device_manager.js');

async function runQuickTest() {
  const deviceManager = new AnxieEaseDeviceManager();
  
  console.log('🧪 Starting Device Assignment Test...\n');
  
  try {
    // Step 1: Check current status
    console.log('📊 Step 1: Checking current assignment status...');
    const currentStatus = await deviceManager.getDeviceAssignment();
    console.log('Current status:', currentStatus);
    
    // Step 2: Assign device to test user
    console.log('\n📱 Step 2: Assigning device to test user...');
    const sessionId = await deviceManager.assignDeviceToUser(
      'test_user_' + Date.now(),
      'Quick assignment test - ' + new Date().toLocaleString()
    );
    console.log('✅ Device assigned! Session ID:', sessionId);
    
    // Step 3: Send some test data
    console.log('\n📤 Step 3: Sending test data...');
    await deviceManager.sendTestData({
      heartRate: 75,
      spo2: 98,
      bodyTemp: 98.6,
      worn: 1
    });
    console.log('✅ Test data sent (HR: 75, SpO2: 98%)');
    
    // Wait a moment for data to process
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Step 4: Check assignment status again
    console.log('\n📊 Step 4: Checking assignment status after data...');
    const statusAfterData = await deviceManager.getDeviceAssignment();
    console.log('Status after data:', statusAfterData);
    
    // Step 5: Get user session data
    console.log('\n📈 Step 5: Getting user session data...');
    const sessionData = await deviceManager.getUserSessionData(
      statusAfterData.userId, 
      statusAfterData.sessionId
    );
    console.log('User session current data:', sessionData.current);
    console.log('Total data points:', sessionData.metadata?.totalDataPoints || 0);
    
    // Step 6: Send elevated heart rate (test anxiety detection)
    console.log('\n🚨 Step 6: Sending elevated heart rate for anxiety detection test...');
    await deviceManager.sendTestData({
      heartRate: 95, // Elevated
      spo2: 97,
      bodyTemp: 98.8,
      worn: 1
    });
    console.log('✅ Elevated HR data sent (HR: 95) - watch for anxiety detection!');
    
    // Step 7: Unassign device
    console.log('\n🔄 Step 7: Unassigning device...');
    await deviceManager.unassignDevice();
    console.log('✅ Device unassigned successfully');
    
    // Step 8: Final status check
    console.log('\n📊 Step 8: Final status check...');
    const finalStatus = await deviceManager.getDeviceAssignment();
    console.log('Final status:', finalStatus);
    
    console.log('\n🎉 All tests completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    
    // Try to cleanup
    try {
      console.log('🧹 Attempting cleanup...');
      await deviceManager.unassignDevice();
      console.log('✅ Cleanup completed');
    } catch (cleanupError) {
      console.log('⚠️ Cleanup failed:', cleanupError.message);
    }
  }
  
  process.exit(0);
}

// Run the test
runQuickTest();