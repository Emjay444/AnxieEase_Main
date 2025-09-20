import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../services/anxiety_detection_engine.dart';
import '../services/notification_service.dart';

class DeveloperTestScreen extends StatefulWidget {
  const DeveloperTestScreen({Key? key}) : super(key: key);

  @override
  _DeveloperTestScreenState createState() => _DeveloperTestScreenState();
}

class _DeveloperTestScreenState extends State<DeveloperTestScreen> {
  final AnxietyDetectionEngine _engine = AnxietyDetectionEngine();
  final NotificationService _notificationService = NotificationService();

  // Test parameters
  double _currentHR = 75.0;
  double _baselineHR = 70.0;
  double _currentSpO2 = 98.0;
  double _movement = 0.2;
  double? _bodyTemp = 36.5;

  AnxietyDetectionResult? _lastResult;
  List<String> _testLog = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Anxiety Detection Test'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTestControls(),
            const SizedBox(height: 20),
            _buildCurrentResult(),
            const SizedBox(height: 20),
            _buildPresetScenarios(),
            const SizedBox(height: 20),
            _buildTestLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Manual Test Controls',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Heart Rate
            Text('❤️ Current HR: ${_currentHR.toInt()} BPM'),
            Slider(
              value: _currentHR,
              min: 50,
              max: 150,
              divisions: 100,
              onChanged: (value) => setState(() => _currentHR = value),
            ),

            // Baseline HR
            Text('📈 Baseline HR: ${_baselineHR.toInt()} BPM'),
            Slider(
              value: _baselineHR,
              min: 50,
              max: 100,
              divisions: 50,
              onChanged: (value) => setState(() => _baselineHR = value),
            ),

            // SpO2
            Text('🫁 SpO2: ${_currentSpO2.toStringAsFixed(1)}%'),
            Slider(
              value: _currentSpO2,
              min: 85,
              max: 100,
              divisions: 150,
              onChanged: (value) => setState(() => _currentSpO2 = value),
            ),

            // Movement
            Text('🏃 Movement: ${_movement.toStringAsFixed(2)}'),
            Slider(
              value: _movement,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (value) => setState(() => _movement = value),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _runDetection,
                    child: const Text('🔍 Run Detection'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _simulateSustainedHR,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    child: const Text('⏱️ Simulate 30s HR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _testNotificationOnly,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('🔔 Test Notification System'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentResult() {
    if (_lastResult == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('🔄 Run a detection test to see results'),
        ),
      );
    }

    final result = _lastResult!;
    return Card(
      color: result.triggered ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.triggered ? Icons.warning : Icons.check_circle,
                  color: result.triggered ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  result.triggered ? '🚨 ANXIETY DETECTED' : '✅ Normal State',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                '📈 Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%'),
            Text('💭 Reason: ${result.reason}'),
            Text(
                '❓ Needs Confirmation: ${result.requiresUserConfirmation ? "Yes" : "No"}'),
            Text(
                '⏰ Timestamp: ${result.timestamp.toString().substring(11, 19)}'),
            if (result.abnormalMetrics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  '⚠️ Abnormal Metrics: ${result.abnormalMetrics.entries.where((e) => e.value).map((e) => e.key).join(", ")}'),
            ],
            const SizedBox(height: 12),
            _getActionRecommendation(result),
          ],
        ),
      ),
    );
  }

  Widget _getActionRecommendation(AnxietyDetectionResult result) {
    String action;
    Color color;

    if (!result.triggered) {
      action = '📊 Continue normal monitoring';
      color = Colors.green;
    } else if (result.confidenceLevel >= 0.8) {
      action = '🚨 Send immediate alert + notification';
      color = Colors.red;
    } else if (result.confidenceLevel >= 0.6) {
      action = '❓ Request user confirmation before alerting';
      color = Colors.orange;
    } else {
      action = '👀 Enhanced monitoring, no alert yet';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(action,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPresetScenarios() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎭 Preset Test Scenarios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton(
                    '😌 Normal State', _setNormalState, Colors.green),
                _buildPresetButton(
                    '😰 Mild Anxiety', _setMildAnxiety, Colors.yellow.shade700),
                _buildPresetButton(
                    '😱 High Anxiety', _setHighAnxiety, Colors.orange),
                _buildPresetButton(
                    '🚨 Critical SpO2', _setCriticalSpO2, Colors.red),
                _buildPresetButton(
                    '💔 Panic Attack', _setPanicAttack, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Widget _buildTestLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📝 Test Log',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _testLog.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _testLog.isEmpty
                      ? 'No test results yet...'
                      : _testLog.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runDetection() {
    final result = _engine.detectAnxiety(
      currentHeartRate: _currentHR,
      restingHeartRate: _baselineHR,
      currentSpO2: _currentSpO2,
      currentMovement: _movement,
      bodyTemperature: _bodyTemp,
    );

    setState(() {
      _lastResult = result;
      _addToLog(
          'HR: ${_currentHR.toInt()}, SpO2: ${_currentSpO2.toStringAsFixed(1)}%, '
          'Movement: ${_movement.toStringAsFixed(2)} → '
          '${result.triggered ? "DETECTED" : "Normal"} '
          '(${(result.confidenceLevel * 100).toStringAsFixed(1)}%)');
    });

    // If detection triggered, test the notification system
    if (result.triggered) {
      _testNotificationSystem(result);
    }
  }

  void _simulateSustainedHR() async {
    _addToLog('🔄 Simulating 30-second sustained HR elevation...');

    // Simulate 30+ sustained readings with real-time delays
    for (int i = 0; i < 35; i++) {
      final result = _engine.detectAnxiety(
        currentHeartRate: _currentHR,
        restingHeartRate: _baselineHR,
        currentSpO2: _currentSpO2,
        currentMovement: _movement,
        bodyTemperature: _bodyTemp,
      );

      if (i % 10 == 0) {
        _addToLog('  ${i}s: Sustained HR ${_currentHR.toInt()} BPM');
      }

      // Small delay to simulate real-time detection
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Final detection after sustained period
    final result = _engine.detectAnxiety(
      currentHeartRate: _currentHR,
      restingHeartRate: _baselineHR,
      currentSpO2: _currentSpO2,
      currentMovement: _movement,
      bodyTemperature: _bodyTemp,
    );

    setState(() {
      _lastResult = result;
      _addToLog(
          '✅ After 30s sustained: ${result.triggered ? "DETECTED" : "Not detected"} '
          '(${(result.confidenceLevel * 100).toStringAsFixed(1)}%)');
    });

    // Test notification system if anxiety was detected
    if (result.triggered) {
      _addToLog(
          '🔔 Anxiety detected after sustained period - sending notification...');
      _testNotificationSystem(result);
    } else {
      _addToLog('✅ No anxiety detected after sustained period');
    }
  }

  void _testNotificationSystem(AnxietyDetectionResult result) async {
    try {
      // Test the actual notification system with real notifications
      _addToLog('📱 Testing notification system...');

      if (result.confidenceLevel >= 0.8) {
        _addToLog('🚨 Sending immediate emergency notification');
        await _sendTestNotification(
            'Anxiety Alert - High Confidence',
            'High anxiety detected (${(result.confidenceLevel * 100).toStringAsFixed(1)}%): ${result.reason}',
            'severe');
      } else if (result.confidenceLevel >= 0.6) {
        _addToLog('⚠️ Sending confirmation request notification');
        await _sendTestNotification(
            'Anxiety Detection - Confirmation Needed',
            'Possible anxiety detected (${(result.confidenceLevel * 100).toStringAsFixed(1)}%): ${result.reason}',
            'moderate');
      } else {
        _addToLog('👀 Silent monitoring, no notification sent');
      }
    } catch (e) {
      _addToLog('❌ Notification test error: $e');
    }
  }

  Future<void> _sendTestNotification(
      String title, String body, String severity) async {
    try {
      // Send local notification via AwesomeNotifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'anxiety_alerts',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: severity == 'severe'
              ? NotificationCategory.Alarm
              : NotificationCategory.Reminder,
          wakeUpScreen: severity == 'severe',
          criticalAlert: severity == 'severe',
        ),
      );

      // Also save to database so it appears in notifications page and triggers UI refresh
      await _notificationService.addNotification(
        title: title,
        message: body,
        type: 'alert', // ensure visible in default filters
        relatedScreen: 'anxiety_detection',
      );

      _addToLog('✅ Real notification sent and saved to database!');
    } catch (e) {
      _addToLog('❌ Failed to send notification: $e');
    }
  }

  // Preset scenarios
  void _setNormalState() {
    setState(() {
      _currentHR = 72;
      _baselineHR = 70;
      _currentSpO2 = 98.0;
      _movement = 0.2;
    });
    _runDetection();
  }

  void _setMildAnxiety() {
    setState(() {
      _currentHR = 88; // ~25% above baseline
      _baselineHR = 70;
      _currentSpO2 = 96.0;
      _movement = 0.4;
    });
    _simulateSustainedHR();
  }

  void _setHighAnxiety() {
    setState(() {
      _currentHR = 98; // ~40% above baseline
      _baselineHR = 70;
      _currentSpO2 = 95.0;
      _movement = 0.7;
    });
    _simulateSustainedHR();
  }

  void _setCriticalSpO2() {
    setState(() {
      _currentHR = 85;
      _baselineHR = 70;
      _currentSpO2 = 89.0; // Critical level
      _movement = 0.6;
    });
    _runDetection();
  }

  void _testNotificationOnly() async {
    _addToLog('🔔 Testing notification system directly...');

    try {
      // Test different notification types
      await _sendTestNotification(
          'Test Anxiety Alert',
          'This is a test notification to verify the anxiety alert system is working properly.',
          'severe');

      _addToLog('✅ Test notification sent! Check your device notifications.');
    } catch (e) {
      _addToLog('❌ Failed to send test notification: $e');
    }
  }

  void _setPanicAttack() {
    setState(() {
      _currentHR = 115; // Very high
      _baselineHR = 70;
      _currentSpO2 = 92.0; // Low
      _movement = 0.9; // High movement
    });
    _simulateSustainedHR();
  }

  void _addToLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _testLog.add('[$timestamp] $message');

    // Keep only last 50 entries
    if (_testLog.length > 50) {
      _testLog.removeAt(0);
    }
  }
}
