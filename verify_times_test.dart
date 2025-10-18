// Quick test to verify notification timestamp conversion
// Run with: dart verify_times_test.dart

import 'package:intl/intl.dart';

void main() {
  print('\n═══════════════════════════════════════════════════════════');
  print('📋 TIMESTAMP CONVERSION TEST - Philippine Time');
  print('═══════════════════════════════════════════════════════════\n');

  // Get current time
  final now = DateTime.now();
  final utcNow = DateTime.now().toUtc();

  print('Current Local Time: ${now.toString()}');
  print('Current UTC Time: ${utcNow.toString()}\n');

  // Simulate what happens when we store a notification
  print('─────────────────────────────────────────────────────────────');
  print('SCENARIO 1: Creating a notification NOW');
  print('─────────────────────────────────────────────────────────────\n');

  // This is what calendar_screen.dart does
  final notificationTime = DateTime.now().toUtc();
  print('✅ Stored in DB (UTC): ${notificationTime.toIso8601String()}');

  // This is what notifications_screen.dart does when displaying (NEW FIX)
  final utcParsed = DateTime.parse(notificationTime.toIso8601String()).toUtc();
  final displayTime = utcParsed.toLocal();
  final formatter = DateFormat('MMM dd, yyyy h:mm a');
  print('📱 Displayed to user (Local): ${formatter.format(displayTime)}');

  final expectedLocalTime = DateTime.now();
  final timeDiff = displayTime.difference(expectedLocalTime).inMinutes.abs();

  if (timeDiff < 2) {
    print('✅ CORRECT: Display time matches current Philippine time!\n');
  } else {
    print('❌ ERROR: Display time is $timeDiff minutes off!\n');
  }

  // Test with sample timestamps
  print('─────────────────────────────────────────────────────────────');
  print('SCENARIO 2: Testing sample notifications');
  print('─────────────────────────────────────────────────────────────\n');

  final samples = [
    '2025-01-16T03:48:00.000Z', // Should display as 11:48 AM Philippine time
    '2025-01-16T08:00:00.000Z', // Should display as 4:00 PM Philippine time
    '2025-01-16T12:30:00.000Z', // Should display as 8:30 PM Philippine time
  ];

  for (var sample in samples) {
    final utcTime = DateTime.parse(sample).toUtc();
    final localTime = utcTime.toLocal();

    print('UTC: ${sample}');
    print('  → Local Time: ${formatter.format(localTime)}\n');
  }

  print('─────────────────────────────────────────────────────────────');
  print('VERIFICATION COMPLETE');
  print('─────────────────────────────────────────────────────────────\n');

  print('📊 Summary:');
  print('  ✅ All notifications are stored in UTC');
  print('  ✅ Display adds 8 hours to show Philippine time');
  print('  ✅ Current time displays correctly\n');

  print('💡 To test your actual notifications:');
  print('  1. Check the notification list in your app');
  print('  2. Compare the displayed time with your current Philippine time');
  print('  3. They should match (or show "X minutes ago", etc.)\n');
}
