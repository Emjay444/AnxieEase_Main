import 'package:flutter/material.dart';
import '../services/unified_device_service.dart';

class UnifiedDeviceStatusWidget extends StatefulWidget {
  final String deviceId;
  final String? userId;

  const UnifiedDeviceStatusWidget({
    Key? key,
    required this.deviceId,
    this.userId,
  }) : super(key: key);

  @override
  _UnifiedDeviceStatusWidgetState createState() =>
      _UnifiedDeviceStatusWidgetState();
}

class _UnifiedDeviceStatusWidgetState extends State<UnifiedDeviceStatusWidget> {
  final UnifiedDeviceService _deviceService = UnifiedDeviceService();
  String _assignmentStatus = 'Loading...';
  bool _isSessionActive = false;
  Map<String, dynamic>? _currentSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    // Initialize the device service
    _deviceService.initialize(widget.deviceId, widget.userId);

    // Load initial status
    await _refreshStatus();

    // Set up periodic status updates
    _startStatusUpdates();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await _deviceService.getAssignmentStatus();
      final sessionActive = await _deviceService.isSessionActive();
      final session = await _deviceService.getCurrentSession();

      if (mounted) {
        setState(() {
          _assignmentStatus = status;
          _isSessionActive = sessionActive;
          _currentSession = session;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _assignmentStatus = 'Error loading status';
          _isLoading = false;
        });
      }
    }
  }

  void _startStatusUpdates() {
    // Refresh status every 30 seconds
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _refreshStatus();
        _startStatusUpdates();
      }
    });
  }

  Future<void> _startSession() async {
    if (widget.userId == null) {
      _showMessage('User ID required to start session');
      return;
    }

    try {
      await _deviceService.createDeviceSession();
      await _deviceService.updateDeviceStatus('active');
      await _refreshStatus();
      _showMessage('Session started successfully');
    } catch (error) {
      _showMessage('Failed to start session: $error');
    }
  }

  Future<void> _endSession() async {
    try {
      await _deviceService.endDeviceSession();
      await _deviceService.updateDeviceStatus('available');
      await _refreshStatus();
      _showMessage('Session ended successfully');
    } catch (error) {
      _showMessage('Failed to end session: $error');
    }
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      await _deviceService.sendEmergencyAlert(
        alertType: 'panic_button',
        sensorData: {
          'heartRate': 120, // Would be actual sensor data
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _showMessage('Emergency alert sent!');
    } catch (error) {
      _showMessage('Failed to send emergency alert: $error');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _deviceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.watch,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device: ${widget.deviceId}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _isLoading ? 'Loading...' : _assignmentStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  CircularProgressIndicator()
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSessionActive ? Colors.green : Colors.grey,
                    ),
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Session Info
            if (_currentSession != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Session',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16),
                        SizedBox(width: 4),
                        Text(
                            'User: ${_currentSession!['userId'] ?? 'Unknown'}'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16),
                        SizedBox(width: 4),
                        Text(
                            'Status: ${_currentSession!['status'] ?? 'Unknown'}'),
                      ],
                    ),
                    if (_currentSession!['startTime'] != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16),
                          SizedBox(width: 4),
                          Text(
                              'Started: ${DateTime.fromMillisecondsSinceEpoch(_currentSession!['startTime']).toString().substring(0, 16)}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                if (!_isSessionActive && widget.userId != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startSession,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Start Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_isSessionActive) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _endSession,
                      icon: Icon(Icons.stop),
                      label: Text('End Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendEmergencyAlert,
                      icon: Icon(Icons.emergency),
                      label: Text('Emergency'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            SizedBox(height: 8),

            // Refresh Button
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _refreshStatus,
                icon: Icon(Icons.refresh),
                label: Text('Refresh Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
