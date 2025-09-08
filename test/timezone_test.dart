import 'package:flutter_test/flutter_test.dart';
import 'package:anxiease/utils/timezone_utils.dart';

void main() {
  group('Philippines Timezone Tests', () {
    test('should correctly convert local time to Philippines time', () {
      // Test current Philippines time
      final philippinesTime = TimezoneUtils.now();
      final utcTime = DateTime.now().toUtc();
      
      // Philippines should be 8 hours ahead of UTC
      final expectedPhilippinesTime = utcTime.add(const Duration(hours: 8));
      
      expect(philippinesTime.hour, expectedPhilippinesTime.hour);
      expect(philippinesTime.day, expectedPhilippinesTime.day);
    });

    test('should correctly create Philippines DateTime from components', () {
      // Create a Philippines datetime for 2:00 PM on Sep 4, 2025
      final philippinesDateTime = TimezoneUtils.createPhilippinesDateTime(
        year: 2025,
        month: 9,
        day: 4,
        hour: 14, // 2 PM
        minute: 0,
      );

      // This should be stored as UTC (6 AM UTC)
      final utcDateTime = philippinesDateTime;
      expect(utcDateTime.hour, 6); // 14 - 8 = 6 UTC
      expect(utcDateTime.day, 4);
      expect(utcDateTime.month, 9);
      expect(utcDateTime.year, 2025);
    });

    test('should correctly format Philippines time for display', () {
      // Create a UTC datetime (6 AM UTC = 2 PM PHT)
      final utcDateTime = DateTime.utc(2025, 9, 4, 6, 0);
      
      final formattedDate = TimezoneUtils.formatPhilippinesDate(utcDateTime);
      final formattedTime = TimezoneUtils.formatPhilippinesTime(utcDateTime);
      
      expect(formattedDate, 'Sep 04, 2025');
      expect(formattedTime, '2:00 PM');
    });

    test('should correctly check if time is past in Philippines timezone', () {
      // Create a time that is in the past in Philippines time
      final pastTime = DateTime.now().toUtc().subtract(const Duration(hours: 10));
      expect(TimezoneUtils.isPast(pastTime), true);
      
      // Create a time that is in the future in Philippines time
      final futureTime = DateTime.now().toUtc().add(const Duration(hours: 10));
      expect(TimezoneUtils.isPast(futureTime), false);
    });

    test('should correctly format datetime with timezone indicator', () {
      final utcDateTime = DateTime.utc(2025, 9, 4, 6, 0); // 6 AM UTC = 2 PM PHT
      final formatted = TimezoneUtils.formatPhilippinesDateTimeWithTimezone(utcDateTime);
      
      expect(formatted, 'Sep 04, 2025 2:00 PM (PHT)');
    });

    test('should correctly convert UTC to Philippines and back', () {
      final originalUtc = DateTime.utc(2025, 9, 4, 6, 0);
      
      // Convert to Philippines time
      final philippinesTime = TimezoneUtils.utcToPhilippines(originalUtc);
      expect(philippinesTime.hour, 14); // 6 + 8 = 14 (2 PM)
      
      // Convert back to UTC
      final backToUtc = TimezoneUtils.philippinesToUtc(philippinesTime);
      expect(backToUtc.hour, originalUtc.hour);
      expect(backToUtc.day, originalUtc.day);
    });
  });
}
