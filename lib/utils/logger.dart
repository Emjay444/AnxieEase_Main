import 'package:flutter/foundation.dart';

/// Central lightweight logger to gate verbose output in one place.
/// Usage: set [AppLogger.verbose] early (e.g. in main) then call d/i/w/e.
class AppLogger {
  static bool verbose = false; // enable detailed logs

  static void d(String msg) {
    if (verbose) debugPrint('DEBUG: $msg');
  }

  static void i(String msg) {
    debugPrint('INFO:  $msg');
  }

  static void w(String msg) {
    debugPrint('WARN:  $msg');
  }

  static void e(String msg, [Object? err, StackTrace? st]) {
    debugPrint('ERROR: $msg' + (err != null ? ' -> $err' : ''));
    if (st != null && verbose) {
      debugPrint(st.toString());
    }
  }
}

/// Legacy Logger wrapper retained for existing calls (maps to AppLogger).
class Logger {
  static const String _tag = 'AnxieEase';

  static void info(String message) => AppLogger.i('[$_tag] $message');
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      AppLogger.e('[$_tag] $message', error, stackTrace);
  static void warning(String message) => AppLogger.w('[$_tag] $message');
  static void debug(String message) => AppLogger.d('[$_tag] $message');
}
