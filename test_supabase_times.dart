import 'lib/utils/timezone_utils.dart';

void main() {
  print('🕐 Testing current appointment creation times...\n');
  
  // Test different appointment times to see what gets stored in Supabase
  final testTimes = [
    {'name': '9:00 AM PHT', 'hour': 9},
    {'name': '1:00 PM PHT', 'hour': 13},
    {'name': '5:00 PM PHT', 'hour': 17},
    {'name': '8:00 PM PHT', 'hour': 20},
  ];
  
  for (var time in testTimes) {
    print('📅 ${time['name']} appointment:');
    
    final appointmentDateTime = TimezoneUtils.createPhilippinesDateTime(
      year: 2025,
      month: 9,
      day: 4,
      hour: time['hour'] as int,
      minute: 0,
    );
    
    final isoString = TimezoneUtils.toIso8601String(appointmentDateTime);
    
    print('  Philippines time: ${time['name']}');
    print('  Stored in DB (UTC): $isoString');
    print('  Expected UTC: ${_getExpectedUTC(time['hour'] as int)}');
    print('');
  }
  
  print('📊 Key Points:');
  print('• Supabase SHOULD store times in UTC (this is correct)');
  print('• Philippines is UTC+8, so PHT times get stored 8 hours earlier in UTC');
  print('• 5:00 PM PHT should be stored as 09:00:00 UTC');
  print('• App should convert back to PHT for display');
}

String _getExpectedUTC(int phtHour) {
  final utcHour = (phtHour - 8) % 24;
  if (utcHour < 0) {
    return '${(24 + utcHour).toString().padLeft(2, '0')}:00:00 UTC (previous day)';
  }
  return '${utcHour.toString().padLeft(2, '0')}:00:00 UTC';
}
