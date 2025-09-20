# Multi-Parameter Anxiety Detection System

## Overview

This comprehensive anxiety detection system implements a sophisticated multi-parameter approach to accurately identify anxiety episodes using wearable device data. The system analyzes multiple biometric parameters simultaneously to reduce false positives and provide personalized, confidence-based alerts.

## System Architecture

```
Wearable Device → Firebase RTDB → Multi-Parameter Engine → Confidence-Based Alerts
                                         ↓
                                 Supabase (Permanent Storage)
```

## Parameters Analyzed

### 1. Heart Rate (HR)
- **Personalized Thresholds**: Based on individual resting HR baseline
- **High HR Detection**: 20-30% above resting HR for ≥30 seconds
- **Low HR Detection**: <50 BPM without medical reason
- **Sustained Analysis**: Requires consistent abnormal readings over time

### 2. Blood Oxygen (SpO₂)
- **Low Level**: <94% (requests user confirmation)
- **Critical Level**: <90% (auto-triggers alert)
- **Real-time Monitoring**: Immediate response to dangerous levels

### 3. Movement Analysis
- **Spike Detection**: Sudden increases in movement intensity
- **Pattern Recognition**: Tremors, shaking, restlessness patterns
- **Anxiety Indicators**: Sustained high movement or oscillating patterns

### 4. Body Temperature (Supporting Data)
- **Context Only**: Not used as primary trigger
- **Logged for Analysis**: Supports overall health picture
- **Trend Tracking**: Helps with long-term pattern analysis

## Trigger Rules

### Single Parameter Abnormal
- **Action**: Request user confirmation
- **Confidence Level**: 60%
- **User Experience**: "Are you feeling anxious?" notification

### Multiple Parameters Abnormal
- **Action**: Auto-trigger anxiety alert
- **Confidence Level**: 85%+ 
- **User Experience**: Immediate intervention suggestions

### Critical Conditions
- **SpO₂ <90%**: Immediate medical alert (100% confidence)
- **HR + Movement**: Highest confidence combination (90%+)

## Implementation Details

### AnxietyDetectionEngine Class

```dart
// Core detection method
AnxietyDetectionResult detectAnxiety({
  required double currentHeartRate,
  required double restingHeartRate, 
  required double currentSpO2,
  required double currentMovement,
  double? bodyTemperature,
})
```

### Key Features

1. **Historical Data Analysis**: Maintains 2-minute sliding window
2. **Sustained Detection**: Requires 30-second sustained abnormality for HR
3. **Confidence Scoring**: 0.0-1.0 scale based on multiple factors
4. **Personalized Baselines**: User-specific resting HR thresholds

### Integration with DeviceService

```dart
// Automatically triggered on new health metrics
void _runAnxietyDetection(HealthMetrics metrics) {
  final result = _anxietyDetectionEngine.detectAnxiety(/*...*/);
  if (result.triggered) {
    _handleAnxietyDetectionResult(result, metrics);
  }
}
```

## Cloud Function Integration

The system includes a Firebase Cloud Function that mirrors the client-side logic:

```javascript
// Multi-parameter detection
exports.detectAnxietyMultiParameter = functions.database
    .ref('/devices/{deviceId}/current')
    .onUpdate(async (change, context) => {
      // Analyze all parameters simultaneously
      // Apply same trigger logic as client
      // Send appropriate notifications
    });
```

## Alert Types and Responses

### High Confidence Alerts (85%+)
- **Immediate Notification**: No user confirmation needed
- **Suggested Actions**: Breathing exercises, grounding techniques
- **Escalation**: Option to contact support person

### Medium Confidence Alerts (60-84%)
- **Confirmation Request**: "Are you feeling anxious?"
- **User Feedback**: Improves system learning
- **Graceful Handling**: Non-intrusive approach

### Critical Alerts (100%)
- **Emergency Protocols**: Immediate medical attention
- **Priority Notifications**: Override "Do Not Disturb" settings
- **Safety First**: Always err on side of caution

## User Experience Enhancements

### Personalization
- Individual baseline establishment through 3-5 minute recording
- Adaptive thresholds based on user's normal patterns
- Learning from user feedback over time

### Reduced False Positives
- Multi-parameter approach eliminates single-metric errors
- Sustained detection prevents temporary spikes from triggering
- Confidence scoring provides nuanced responses

### Smart Notifications
- Context-aware timing (respects sleep, meetings)
- Graduated response based on confidence level
- Educational content to help users understand their patterns

## Testing and Validation

Comprehensive test suite covers:
- Individual parameter analysis
- Multi-parameter combinations
- Edge cases and error handling
- Confidence level accuracy
- Historical data management

```dart
// Example test case
test('should trigger without confirmation for multiple abnormal metrics', () {
  // Simulate sustained abnormal HR + low SpO2
  final result = engine.detectAnxiety(
    currentHeartRate: 84.0, // 20% above baseline
    restingHeartRate: 70.0,
    currentSpO2: 92.0, // Below threshold
    currentMovement: 60.0, // High
  );
  
  expect(result.triggered, true);
  expect(result.requiresUserConfirmation, false);
  expect(result.confidenceLevel, greaterThan(0.8));
});
```

## Performance Considerations

### Efficient Processing
- Sliding window approach minimizes memory usage
- Real-time analysis without blocking UI
- Optimized for continuous monitoring

### Data Storage
- Historical data limited to 2 minutes (120 data points)
- Smart storage only on significant changes
- Compressed alert data for long-term analysis

## Future Enhancements

### Machine Learning Integration
- Pattern recognition for individual user anxiety signatures
- Predictive alerts before full anxiety episode
- Continuous improvement based on user feedback

### Advanced Movement Analysis
- Gyroscope data for more precise tremor detection
- Activity context (walking vs. sitting) consideration
- Sleep pattern integration

### Environmental Factors
- Location-based triggers (known anxiety-inducing places)
- Weather and air quality correlation
- Social situation awareness (calendar integration)

## API Reference

### Core Classes

#### AnxietyDetectionResult
```dart
class AnxietyDetectionResult {
  final bool triggered;
  final String reason; // 'highHR', 'lowSpO2', 'combinedHRMovement', etc.
  final double confidenceLevel; // 0.0 to 1.0
  final bool requiresUserConfirmation;
  final Map<String, dynamic> metrics;
  final Map<String, bool> abnormalMetrics;
  final DateTime timestamp;
}
```

#### Key Methods
- `detectAnxiety()`: Main detection method
- `reset()`: Clear historical data
- `getDetectionStatus()`: Current system status

### DeviceService Integration

New methods added to DeviceService:
- `canDetectAnxiety`: Whether system is ready for detection
- `anxietyDetectionStatus`: Current detection engine status

## Deployment Checklist

### Client Side
- [ ] AnxietyDetectionEngine integrated into DeviceService
- [ ] UI components for handling detection results
- [ ] Notification service updated for new alert types
- [ ] User settings for sensitivity preferences

### Server Side
- [ ] Cloud Function deployed with multi-parameter logic
- [ ] Database rules updated for anxiety_alerts collection
- [ ] FCM topics configured for different alert types
- [ ] Analytics setup for detection accuracy tracking

### Testing
- [ ] Unit tests for all detection scenarios
- [ ] Integration tests with real device data
- [ ] User acceptance testing with beta users
- [ ] Performance testing under continuous monitoring

This system provides a robust, personalized, and user-friendly approach to anxiety detection that significantly improves upon simple threshold-based systems.