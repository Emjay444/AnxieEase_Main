class BaselineConfig {
  // Default guided session duration (minutes)
  static const int defaultMinutes = 5;

  // Suggest recalibration every N days
  static const int weeklyRefreshDays = 7;

  // If resting HR deviates from baseline by this many BPM, suggest recalibration
  static const int driftThresholdBpm = 5;

  // Movement threshold (%) to consider the user at rest
  static const double restfulMovementThreshold = 10.0;
}
