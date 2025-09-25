import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Widget to test different notification sounds
class NotificationSoundTester extends StatefulWidget {
  const NotificationSoundTester({Key? key}) : super(key: key);

  @override
  _NotificationSoundTesterState createState() => _NotificationSoundTesterState();
}

class _NotificationSoundTesterState extends State<NotificationSoundTester> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Sound Tester'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Different Anxiety Alert Sounds',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Each severity level has its own distinct sound to help you immediately understand the urgency:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Individual severity test buttons
            _buildSeverityButton(
              '🟢 Test Mild Alert',
              'Gentle chime for mild anxiety detection',
              Colors.green,
              () => _testSeverity('mild'),
            ),
            const SizedBox(height: 12),
            
            _buildSeverityButton(
              '🟠 Test Moderate Alert',
              'Clear tone for moderate anxiety levels',
              Colors.orange,
              () => _testSeverity('moderate'),
            ),
            const SizedBox(height: 12),
            
            _buildSeverityButton(
              '🔴 Test Severe Alert',
              'Urgent sound for severe anxiety detection',
              Colors.red,
              () => _testSeverity('severe'),
            ),
            const SizedBox(height: 12),
            
            _buildSeverityButton(
              '🚨 Test Critical Alert',
              'Emergency tone for critical situations',
              Colors.red[900]!,
              () => _testSeverity('critical'),
            ),
            
            const SizedBox(height: 30),
            
            // Test all button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testAllSeverities,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Testing...' : 'Test All Sounds (2s apart)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Important Notes:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text('• Make sure your device volume is turned up'),
                    Text('• Check that Do Not Disturb mode is off'),
                    Text('• Custom sounds require actual MP3 files in assets/audio/'),
                    Text('• Each severity has unique vibration patterns too'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityButton(
    String title, 
    String description, 
    Color color, 
    VoidCallback onPressed
  ) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _testSeverity(String severity) async {
    try {
      setState(() => _isLoading = true);
      
      // Initialize notification service if not already done
      await _notificationService.initialize();
      
      // Test individual severity
      await _notificationService.testSeverityNotification(severity, DateTime.now().millisecond);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$severity notification sent! Check your notification panel.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAllSeverities() async {
    try {
      setState(() => _isLoading = true);
      
      // Initialize notification service if not already done
      await _notificationService.initialize();
      
      // Test all severities with delay
      await _notificationService.testAllSeverityNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All severity notifications sent! Check your notification panel.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}