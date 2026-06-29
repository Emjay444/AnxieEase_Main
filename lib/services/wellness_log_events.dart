import 'package:flutter/foundation.dart';

/// Cross-screen signal that wellness log data changed (e.g. a Calendar
/// add/edit/delete), so other already-mounted screens (e.g. Metrics) know
/// to refresh instead of keeping their last-loaded snapshot. The int value
/// itself is meaningless - only the fact that it changed matters.
class WellnessLogEvents {
  WellnessLogEvents._();

  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static void notifyChanged() {
    changed.value++;
  }
}
