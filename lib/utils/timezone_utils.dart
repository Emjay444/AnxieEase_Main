import 'package:intl/intl.dart';

/// Utility class for handling Philippines timezone (UTC+8)
class TimezoneUtils {
  // Philippines is UTC+8
  static const int philippinesOffsetHours = 8;
  static const Duration philippinesOffset = Duration(hours: philippinesOffsetHours);

  /// Get current Philippines time
  static DateTime now() {
    return DateTime.now().toUtc().add(philippinesOffset);
  }

  /// Convert UTC DateTime to Philippines time
  static DateTime utcToPhilippines(DateTime utcDateTime) {
    return utcDateTime.toUtc().add(philippinesOffset);
  }

  /// Convert Philippines time to UTC for database storage
  static DateTime philippinesToUtc(DateTime philippinesDateTime) {
    return philippinesDateTime.subtract(philippinesOffset);
  }

  /// Create a DateTime in Philippines timezone from date and time components
  static DateTime createPhilippinesDateTime({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    int second = 0,
    int millisecond = 0,
  }) {
    // Create the local datetime first
    final localDateTime = DateTime(year, month, day, hour, minute, second, millisecond);
    
    // Since we want this to represent Philippines time, we need to convert to UTC for storage
    // by subtracting the Philippines offset and making sure it's marked as UTC
    final utcDateTime = localDateTime.subtract(philippinesOffset);
    return DateTime.utc(utcDateTime.year, utcDateTime.month, utcDateTime.day, 
                       utcDateTime.hour, utcDateTime.minute, utcDateTime.second, utcDateTime.millisecond);
  }

  /// Format Philippines DateTime for display
  static String formatPhilippinesDate(DateTime dateTime, [String pattern = 'MMM dd, yyyy']) {
    final philippinesTime = utcToPhilippines(dateTime);
    return DateFormat(pattern).format(philippinesTime);
  }

  /// Format Philippines DateTime time for display
  static String formatPhilippinesTime(DateTime dateTime, [String pattern = 'h:mm a']) {
    final philippinesTime = utcToPhilippines(dateTime);
    return DateFormat(pattern).format(philippinesTime);
  }

  /// Format Philippines DateTime with timezone indicator
  static String formatPhilippinesDateTimeWithTimezone(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    return '${DateFormat('MMM dd, yyyy h:mm a').format(philippinesTime)} (PHT)';
  }

  /// Get ISO8601 string for database storage (UTC)
  static String toIso8601String(DateTime dateTime) {
    // The datetime should already be in UTC format from createPhilippinesDateTime
    // Don't call toUtc() again to avoid double conversion
    return dateTime.toIso8601String();
  }

  /// Parse ISO8601 string from database (assumed to be UTC)
  static DateTime fromIso8601String(String iso8601String) {
    // Parse the string as UTC without additional conversion
    return DateTime.parse(iso8601String).toUtc();
  }

  /// Check if a Philippines DateTime is in the past
  static bool isPast(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    final currentPhilippinesTime = now();
    return philippinesTime.isBefore(currentPhilippinesTime);
  }

  /// Check if a Philippines DateTime is today
  static bool isToday(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    final currentPhilippinesTime = now();
    
    return philippinesTime.year == currentPhilippinesTime.year &&
           philippinesTime.month == currentPhilippinesTime.month &&
           philippinesTime.day == currentPhilippinesTime.day;
  }

  /// Get the start of day in Philippines time (converted to UTC)
  static DateTime startOfDay(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    final startOfDay = DateTime(philippinesTime.year, philippinesTime.month, philippinesTime.day);
    return philippinesToUtc(startOfDay);
  }

  /// Get the end of day in Philippines time (converted to UTC)
  static DateTime endOfDay(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    final endOfDay = DateTime(philippinesTime.year, philippinesTime.month, philippinesTime.day, 23, 59, 59, 999);
    return philippinesToUtc(endOfDay);
  }

  /// Get a user-friendly relative time string in Philippines time
  static String getRelativeTime(DateTime dateTime) {
    final philippinesTime = utcToPhilippines(dateTime);
    final currentPhilippinesTime = now();
    final difference = philippinesTime.difference(currentPhilippinesTime);

    if (difference.isNegative) {
      // Past time
      final absDifference = difference.abs();
      if (absDifference.inMinutes < 60) {
        return '${absDifference.inMinutes} minutes ago';
      } else if (absDifference.inHours < 24) {
        return '${absDifference.inHours} hours ago';
      } else if (absDifference.inDays < 7) {
        return '${absDifference.inDays} days ago';
      } else {
        return formatPhilippinesDate(dateTime);
      }
    } else {
      // Future time
      if (difference.inMinutes < 60) {
        return 'in ${difference.inMinutes} minutes';
      } else if (difference.inHours < 24) {
        return 'in ${difference.inHours} hours';
      } else if (difference.inDays < 7) {
        return 'in ${difference.inDays} days';
      } else {
        return formatPhilippinesDate(dateTime);
      }
    }
  }
}
