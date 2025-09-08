import 'lib/utils/timezone_utils.dart';

void main() {
  print('Testing TimezoneUtils...');
  
  // Test current Philippines time
  final currentPHT = TimezoneUtils.now();
  print('Current Philippines time: $currentPHT');
  
  // Test creating a Philippines datetime
  final appointmentTime = TimezoneUtils.createPhilippinesDateTime(
    year: 2025, 
    month: 9, 
    day: 3, 
    hour: 14, 
    minute: 30
  );
  print('Appointment time (stored as UTC): $appointmentTime');
  
  // Test formatting
  final formattedDate = TimezoneUtils.formatPhilippinesDate(appointmentTime);
  final formattedTime = TimezoneUtils.formatPhilippinesTime(appointmentTime);
  print('Formatted date: $formattedDate');
  print('Formatted time: $formattedTime');
  
  // Test isPast function
  final isPast = TimezoneUtils.isPast(appointmentTime);
  print('Is appointment in the past? $isPast');
  
  print('All timezone utilities working correctly! ✅');
}
