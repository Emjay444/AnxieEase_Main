import 'lib/utils/timezone_utils.dart';

void main() {
  print('🕐 Debugging appointment time conversion...\n');
  
  // Simulate what happens when user selects Sep 4, 5 PM
  print('User Selection: Sep 4, 2025 at 5:00 PM Philippines time');
  
  // Step 1: Create Philippines DateTime (what the app does)
  final appointmentDateTime = TimezoneUtils.createPhilippinesDateTime(
    year: 2025,
    month: 9,
    day: 4,
    hour: 17, // 5 PM
    minute: 0,
  );
  
  print('Step 1 - Created DateTime (stored in DB): $appointmentDateTime');
  print('  └─ This should be 9 AM UTC (5 PM PHT - 8 hours)');
  
  // Step 2: Convert to ISO string (what gets stored in database)
  final isoString = TimezoneUtils.toIso8601String(appointmentDateTime);
  print('Step 2 - ISO string for database: $isoString');
  print('  └─ Should be 2025-09-04T09:00:00.000');
  
  // Step 3: Parse back from database (simulate reading from DB)
  final fromDatabase = TimezoneUtils.fromIso8601String(isoString);
  print('Step 3 - Read from database: $fromDatabase');
  print('  └─ Should be 9 AM UTC');
  
  // Step 4: Convert back to Philippines time for display
  final philippinesTime = TimezoneUtils.utcToPhilippines(fromDatabase);
  print('Step 4 - Convert to Philippines time: $philippinesTime');
  print('  └─ Should be 5 PM PHT (9 AM UTC + 8 hours)');
  
  // Step 5: Format for display (what user sees)
  final displayTime = TimezoneUtils.formatPhilippinesTime(fromDatabase);
  final displayDate = TimezoneUtils.formatPhilippinesDate(fromDatabase);
  
  print('Step 5 - Display to user:');
  print('  Date: $displayDate');
  print('  Time: $displayTime');
  
  print('\n📊 Summary:');
  print('Expected final time: 17:00 (5 PM)');
  print('Actual final time: ${philippinesTime.hour}:${philippinesTime.minute.toString().padLeft(2, '0')}');
  
  if (philippinesTime.hour == 17) {
    print('✅ SUCCESS: Time conversion working correctly!');
  } else {
    print('❌ PROBLEM: Time conversion is incorrect!');
    
    // Debug what went wrong
    print('\n🔍 Debug Info:');
    print('appointmentDateTime.isUtc: ${appointmentDateTime.isUtc}');
    print('fromDatabase.isUtc: ${fromDatabase.isUtc}');
  }
}
