import 'lib/models/appointment_model.dart';

void main() {
  print('🔍 Testing appointment status mapping fix...');
  
  // Test data simulating what comes from the database
  final testData = {
    'id': 'test-id',
    'psychologist_id': 'psych-id',
    'user_id': 'user-id',
    'appointment_date': '2025-09-04T18:00:00Z',
    'reason': 'test appointment',
    'status': 'declined',  // This is what the database has
    'response_message': null,
    'created_at': '2025-09-02T10:00:00Z',
  };
  
  // Create appointment model from the test data
  final appointment = AppointmentModel.fromJson(testData);
  
  print('📊 Results:');
  print('Database status: "${testData['status']}"');
  print('Parsed status enum: ${appointment.status}');
  print('Status text for UI: "${appointment.statusText}"');
  
  // Verify the fix worked
  if (appointment.status == AppointmentStatus.denied && 
      appointment.statusText == 'Denied') {
    print('✅ SUCCESS: "declined" now correctly maps to "denied"!');
    print('🎉 The app will now show the correct status instead of "Pending"');
  } else {
    print('❌ FAILED: Status mapping still has issues');
  }
}
