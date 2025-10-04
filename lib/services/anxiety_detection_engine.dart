import 'dart:math' as math;

/// Comprehensive anxiety detection result
class AnxietyDetectionResult {
  final bool triggered;
  final String reason;
  final double confidenceLevel; // 0.0 to 1.0
  final bool requiresUserConfirmation;
  final Map<String, dynamic> metrics;
  final Map<String, bool> abnormalMetrics;
  final DateTime timestamp;

  const AnxietyDetectionResult({
    required this.triggered,
    required this.reason,
    required this.confidenceLevel,
    required this.requiresUserConfirmation,
    required this.metrics,
    required this.abnormalMetrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'triggered': triggered,
        'reason': reason,
        'confidenceLevel': confidenceLevel,
        'requiresUserConfirmation': requiresUserConfirmation,
        'metrics': metrics,
        'abnormalMetrics': abnormalMetrics,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Heart rate analysis result
class HeartRateAnalysis {
  final bool isAbnormal;
  final String type; // 'high', 'low', 'normal'
  final double percentageAboveResting;
  final double currentHR;
  final double restingHR;
  final bool sustainedFor30Seconds;

  const HeartRateAnalysis({
    required this.isAbnormal,
    required this.type,
    required this.percentageAboveResting,
    required this.currentHR,
    required this.restingHR,
    required this.sustainedFor30Seconds,
  });
}

/// SpO2 analysis result
class SpO2Analysis {
  final bool isAbnormal;
  final String severity; // 'normal', 'low', 'critical'
  final double currentSpO2;
  final bool requiresConfirmation;

  const SpO2Analysis({
    required this.isAbnormal,
    required this.severity,
    required this.currentSpO2,
    required this.requiresConfirmation,
  });
}

/// Movement analysis result
class MovementAnalysis {
  final bool hasSpikes;
  final double movementIntensity; // 0-100
  final bool indicatesAnxiety; // tremors, shaking patterns
  final List<double> recentMovementData;

  const MovementAnalysis({
    required this.hasSpikes,
    required this.movementIntensity,
    required this.indicatesAnxiety,
    required this.recentMovementData,
  });
}

/// Comprehensive multi-parameter anxiety detection system
class AnxietyDetectionEngine {
  static const double _highHRThresholdMin = 0.20; // 20% above resting
  static const double _highHRThresholdMax = 0.30; // 30% above resting
  static const double _lowHRThreshold = 50.0; // BPM
  static const double _spo2LowThreshold = 94.0; // % (reverted back)
  static const double _spo2CriticalThreshold = 90.0; // % (reverted back)
  static const int _sustainedDurationSeconds = 60; // kept as 60 seconds

  // Historical data for sustained detection
  final List<double> _recentHeartRates = [];
  final List<double> _recentSpO2Values = [];
  final List<double> _recentMovementLevels = [];
  final List<DateTime> _timestamps = [];

  // Keep 2 minutes of data for sustained analysis
  static const int _maxHistoryLength = 120; // 2 minutes at 1-second intervals

  /// Main anxiety detection method
  AnxietyDetectionResult detectAnxiety({
    required double currentHeartRate,
    required double restingHeartRate,
    required double currentSpO2,
    required double currentMovement,
    double? bodyTemperature,
  }) {
    final now = DateTime.now();

    // Update historical data
    _updateHistoricalData(currentHeartRate, currentSpO2, currentMovement, now);

    // Analyze each parameter
    final hrAnalysis = _analyzeHeartRate(currentHeartRate, restingHeartRate);
    final spo2Analysis = _analyzeSpO2(currentSpO2);
    final movementAnalysis = _analyzeMovement(currentMovement);

    // Count abnormal metrics
    final abnormalMetrics = <String, bool>{
      'heartRate': hrAnalysis.isAbnormal,
      'spO2': spo2Analysis.isAbnormal,
      'movement': movementAnalysis.hasSpikes,
    };

    final abnormalCount = abnormalMetrics.values.where((v) => v).length;

    // Apply trigger logic
    return _applyTriggerLogic(
      hrAnalysis: hrAnalysis,
      spo2Analysis: spo2Analysis,
      movementAnalysis: movementAnalysis,
      abnormalCount: abnormalCount,
      abnormalMetrics: abnormalMetrics,
      bodyTemperature: bodyTemperature,
      timestamp: now,
    );
  }

  /// Update historical data for sustained detection
  void _updateHistoricalData(
      double hr, double spo2, double movement, DateTime timestamp) {
    _recentHeartRates.add(hr);
    _recentSpO2Values.add(spo2);
    _recentMovementLevels.add(movement);
    _timestamps.add(timestamp);

    // Keep only recent data
    while (_timestamps.length > _maxHistoryLength) {
      _recentHeartRates.removeAt(0);
      _recentSpO2Values.removeAt(0);
      _recentMovementLevels.removeAt(0);
      _timestamps.removeAt(0);
    }
  }

  /// Analyze heart rate patterns
  HeartRateAnalysis _analyzeHeartRate(double currentHR, double restingHR) {
    final percentageAbove = ((currentHR - restingHR) / restingHR);
    final isHigh = percentageAbove >= _highHRThresholdMin;
    final isLow = currentHR < _lowHRThreshold;
    final isAbnormal = isHigh || isLow;

    // Check if sustained for 30 seconds
    final sustainedFor30Seconds =
        _isHeartRateSustained(isHigh ? 'high' : 'low', restingHR);

    return HeartRateAnalysis(
      isAbnormal: isAbnormal && sustainedFor30Seconds,
      type: isHigh ? 'high' : (isLow ? 'low' : 'normal'),
      percentageAboveResting: percentageAbove * 100,
      currentHR: currentHR,
      restingHR: restingHR,
      sustainedFor30Seconds: sustainedFor30Seconds,
    );
  }

  /// Check if heart rate has been sustained in abnormal range
  bool _isHeartRateSustained(String type, double restingHR) {
    if (_recentHeartRates.length < _sustainedDurationSeconds) {
      return false;
    }

    // Check last 30 seconds of data
    final recentData = _recentHeartRates.sublist(
        math.max(0, _recentHeartRates.length - _sustainedDurationSeconds));

    return recentData.every((hr) {
      if (type == 'high') {
        return (hr - restingHR) / restingHR >= _highHRThresholdMin;
      } else if (type == 'low') {
        return hr < _lowHRThreshold;
      }
      return false;
    });
  }

  /// Analyze SpO2 levels
  SpO2Analysis _analyzeSpO2(double currentSpO2) {
    final isCritical = currentSpO2 < _spo2CriticalThreshold;
    final isLow = currentSpO2 < _spo2LowThreshold;
    final isAbnormal = isLow || isCritical;

    String severity;
    bool requiresConfirmation;

    if (isCritical) {
      severity = 'critical';
      requiresConfirmation = false; // Auto-flag critical levels
    } else if (isLow) {
      severity = 'low';
      requiresConfirmation = true; // Request confirmation for low levels
    } else {
      severity = 'normal';
      requiresConfirmation = false;
    }

    return SpO2Analysis(
      isAbnormal: isAbnormal,
      severity: severity,
      currentSpO2: currentSpO2,
      requiresConfirmation: requiresConfirmation,
    );
  }

  /// Analyze movement patterns for anxiety indicators
  MovementAnalysis _analyzeMovement(double currentMovement) {
    // Detect sudden spikes in movement (potential tremors/shaking)
    final hasSpikes = _detectMovementSpikes(currentMovement);
    final indicatesAnxiety = _detectAnxietyMovementPatterns();

    return MovementAnalysis(
      hasSpikes: hasSpikes,
      movementIntensity: currentMovement,
      indicatesAnxiety: indicatesAnxiety,
      recentMovementData: List<double>.from(_recentMovementLevels),
    );
  }

  /// Detect sudden movement spikes that could indicate anxiety
  bool _detectMovementSpikes(double currentMovement) {
    if (_recentMovementLevels.length < 10) return false;

    // Calculate recent average movement
    final recentAverage = _recentMovementLevels
            .sublist(math.max(0, _recentMovementLevels.length - 10))
            .reduce((a, b) => a + b) /
        10;

    // Spike if current movement is significantly higher than recent average
    return currentMovement > (recentAverage * 2.0) && currentMovement > 30.0;
  }

  /// Detect movement patterns that indicate anxiety (tremors, restlessness)
  bool _detectAnxietyMovementPatterns() {
    if (_recentMovementLevels.length < 20) return false;

    final recent20 = _recentMovementLevels
        .sublist(math.max(0, _recentMovementLevels.length - 20));

    // Check for sustained elevated movement (restlessness)
    final sustainedHighMovement = recent20.where((m) => m > 40.0).length > 15;

    // Check for oscillating patterns (tremors)
    final hasOscillations = _detectOscillations(recent20);

    return sustainedHighMovement || hasOscillations;
  }

  /// Detect oscillating movement patterns that could indicate tremors
  bool _detectOscillations(List<double> movementData) {
    if (movementData.length < 10) return false;

    int directionChanges = 0;
    for (int i = 2; i < movementData.length; i++) {
      final prev2 = movementData[i - 2];
      final prev1 = movementData[i - 1];
      final current = movementData[i];

      // Check for direction change (peak or valley)
      if ((prev1 > prev2 && prev1 > current) ||
          (prev1 < prev2 && prev1 < current)) {
        directionChanges++;
      }
    }

    // If we have many direction changes, it suggests oscillating movement
    return directionChanges >= (movementData.length * 0.3);
  }

  /// Apply trigger logic based on all analyses
  AnxietyDetectionResult _applyTriggerLogic({
    required HeartRateAnalysis hrAnalysis,
    required SpO2Analysis spo2Analysis,
    required MovementAnalysis movementAnalysis,
    required int abnormalCount,
    required Map<String, bool> abnormalMetrics,
    required DateTime timestamp,
    double? bodyTemperature,
  }) {
    bool triggered = false;
    String reason = 'normal';
    double confidenceLevel = 0.0;
    bool requiresUserConfirmation = false;

    // Critical SpO2 - Always trigger
    if (spo2Analysis.severity == 'critical') {
      triggered = true;
      reason = 'criticalSpO2';
      confidenceLevel = 1.0;
      requiresUserConfirmation = false;
    }
    // Multiple metrics abnormal - High confidence trigger
    else if (abnormalCount >= 2) {
      triggered = true;
      confidenceLevel = 0.85 + (abnormalCount - 2) * 0.1; // 0.85-1.0

      if (hrAnalysis.isAbnormal && movementAnalysis.hasSpikes) {
        reason = 'combinedHRMovement';
      } else if (hrAnalysis.isAbnormal && spo2Analysis.isAbnormal) {
        reason = 'combinedHRSpO2';
      } else if (spo2Analysis.isAbnormal && movementAnalysis.hasSpikes) {
        reason = 'combinedSpO2Movement';
      } else {
        reason = 'multipleMetrics';
      }

      requiresUserConfirmation = false;
    }
    // Single metric abnormal - Request confirmation
    else if (abnormalCount == 1) {
      triggered = true;
      confidenceLevel = 0.6; // Lower confidence for single metric
      requiresUserConfirmation = true;

      if (hrAnalysis.isAbnormal) {
        reason = hrAnalysis.type == 'high' ? 'highHR' : 'lowHR';
      } else if (spo2Analysis.isAbnormal) {
        reason = 'lowSpO2';
      } else if (movementAnalysis.hasSpikes) {
        reason = 'movementSpikes';
      }
    }

    // Adjust confidence based on movement patterns
    if (movementAnalysis.indicatesAnxiety && triggered) {
      confidenceLevel = math.min(1.0, confidenceLevel + 0.1);
    }

    // Collect all metrics for logging
    final metrics = <String, dynamic>{
      'heartRate': hrAnalysis.currentHR,
      'restingHeartRate': hrAnalysis.restingHR,
      'hrPercentageAbove': hrAnalysis.percentageAboveResting,
      'spO2': spo2Analysis.currentSpO2,
      'movement': movementAnalysis.movementIntensity,
      'bodyTemperature': bodyTemperature,
      'sustainedHR': hrAnalysis.sustainedFor30Seconds,
      'movementSpikes': movementAnalysis.hasSpikes,
      'anxietyMovementPattern': movementAnalysis.indicatesAnxiety,
    };

    return AnxietyDetectionResult(
      triggered: triggered,
      reason: reason,
      confidenceLevel: confidenceLevel,
      requiresUserConfirmation: requiresUserConfirmation,
      metrics: metrics,
      abnormalMetrics: abnormalMetrics,
      timestamp: timestamp,
    );
  }

  /// Reset historical data (useful for testing or when changing users)
  void reset() {
    _recentHeartRates.clear();
    _recentSpO2Values.clear();
    _recentMovementLevels.clear();
    _timestamps.clear();
  }

  /// Get current detection status summary
  Map<String, dynamic> getDetectionStatus() {
    return {
      'historicalDataPoints': _recentHeartRates.length,
      'canDetectSustained':
          _recentHeartRates.length >= _sustainedDurationSeconds,
      'recentHRAverage': _recentHeartRates.isNotEmpty
          ? _recentHeartRates.reduce((a, b) => a + b) / _recentHeartRates.length
          : 0.0,
      'recentMovementAverage': _recentMovementLevels.isNotEmpty
          ? _recentMovementLevels.reduce((a, b) => a + b) /
              _recentMovementLevels.length
          : 0.0,
    };
  }
}
