import 'package:flutter/material.dart';
import '../services/unified_device_service.dart';
import 'dart:async';

class SensorDataMonitorWidget extends StatefulWidget {
  final String deviceId;

  const SensorDataMonitorWidget({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  @override
  _SensorDataMonitorWidgetState createState() =>
      _SensorDataMonitorWidgetState();
}

class _SensorDataMonitorWidgetState extends State<SensorDataMonitorWidget> {
  final UnifiedDeviceService _deviceService = UnifiedDeviceService();
  StreamSubscription? _sensorDataSubscription;
  Map<String, dynamic>? _latestSensorData;
  List<Map<String, dynamic>> _sensorHistory = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    // Listen to sensor data stream
    _sensorDataSubscription =
        _deviceService.listenToSensorData(widget.deviceId).listen(
      (data) {
        if (mounted) {
          setState(() {
            _latestSensorData = data;
            _addToHistory(data);
          });
        }
      },
      onError: (error) {
        if (mounted) {
          _showMessage('Sensor data error: $error');
        }
      },
    );
  }

  void _stopListening() {
    _sensorDataSubscription?.cancel();
    setState(() {
      _isListening = false;
    });
  }

  void _addToHistory(Map<String, dynamic> data) {
    _sensorHistory.insert(0, {
      ...data,
      'receivedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Keep only last 20 readings
    if (_sensorHistory.length > 20) {
      _sensorHistory = _sensorHistory.take(20).toList();
    }
  }

  void _simulateSensorData() async {
    try {
      final testData = {
        'heartRate': 75 +
            (DateTime.now().millisecond % 30), // Simulate varying heart rate
        'temperature': 36.5 +
            (DateTime.now().millisecond % 100) / 1000, // Simulate temperature
        'accelerometer': {
          'x': (DateTime.now().millisecond % 200 - 100) / 100.0,
          'y': (DateTime.now().millisecond % 200 - 100) / 100.0,
          'z': (DateTime.now().millisecond % 200 - 100) / 100.0,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _deviceService.sendSensorData(testData);
      _showMessage('Test sensor data sent');
    } catch (error) {
      _showMessage('Failed to send test data: $error');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildSensorValue(String label, dynamic value,
      {Color? color, String? unit}) {
    String displayValue;
    if (value is double) {
      displayValue = value.toStringAsFixed(1);
    } else if (value is Map) {
      displayValue = 'Complex';
    } else {
      displayValue = value?.toString() ?? 'N/A';
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? Theme.of(context).primaryColor).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color ?? Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                displayValue,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color ?? Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (unit != null) ...[
                SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: (color ?? Theme.of(context).primaryColor)
                            .withOpacity(0.7),
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccelerometerData(Map<String, dynamic> accelData) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accelerometer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('X: ${(accelData['x'] ?? 0.0).toStringAsFixed(2)}'),
              ),
              Expanded(
                child: Text('Y: ${(accelData['y'] ?? 0.0).toStringAsFixed(2)}'),
              ),
              Expanded(
                child: Text('Z: ${(accelData['z'] ?? 0.0).toStringAsFixed(2)}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
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
                  Icons.sensors,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensor Data Monitor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Device: ${widget.deviceId}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                    label: Text(
                        _isListening ? 'Stop Monitoring' : 'Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _simulateSensorData,
                  icon: Icon(Icons.science),
                  label: Text('Test Data'),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Latest Sensor Data
            if (_latestSensorData != null) ...[
              Text(
                'Latest Reading',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: [
                  if (_latestSensorData!['heartRate'] != null)
                    _buildSensorValue(
                      'Heart Rate',
                      _latestSensorData!['heartRate'],
                      color: Colors.red,
                      unit: 'bpm',
                    ),
                  if (_latestSensorData!['temperature'] != null)
                    _buildSensorValue(
                      'Temperature',
                      _latestSensorData!['temperature'],
                      color: Colors.orange,
                      unit: '°C',
                    ),
                ],
              ),
              if (_latestSensorData!['accelerometer'] != null) ...[
                SizedBox(height: 8),
                _buildAccelerometerData(_latestSensorData!['accelerometer']),
              ],
              SizedBox(height: 8),
              Text(
                'Last updated: ${DateTime.fromMillisecondsSinceEpoch(_latestSensorData!['timestamp'] ?? DateTime.now().millisecondsSinceEpoch).toString().substring(11, 19)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.sensors_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No sensor data received',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isListening
                            ? 'Waiting for data...'
                            : 'Start monitoring to see sensor data',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Sensor History
            if (_sensorHistory.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Recent History (${_sensorHistory.length} readings)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: ListView.builder(
                  itemCount: _sensorHistory.length,
                  itemBuilder: (context, index) {
                    final reading = _sensorHistory[index];
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                        reading['receivedAt']);

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.timeline, size: 16),
                        title: Text(
                          'HR: ${reading['heartRate'] ?? 'N/A'} | Temp: ${reading['temperature']?.toStringAsFixed(1) ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        subtitle: Text(
                          timestamp.toString().substring(11, 19),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
