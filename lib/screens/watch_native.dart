// Enhanced Watch Screen that communicates with Native IoT Gateway Service
// This replaces the Flutter-based IoT Gateway with a native Android service

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/native_iot_gateway_service.dart';
import '../services/device_manager.dart';

class WatchScreenNative extends StatefulWidget {
  const WatchScreenNative({Key? key}) : super(key: key);

  @override
  State<WatchScreenNative> createState() => _WatchScreenNativeState();
}

class _WatchScreenNativeState extends State<WatchScreenNative> {
  late NativeIoTGatewayService _nativeGateway;
  late DeviceManager _deviceManager;

  @override
  void initState() {
    super.initState();
    _nativeGateway = NativeIoTGatewayService();
    _deviceManager = Provider.of<DeviceManager>(context, listen: false);

    // Initialize the native gateway service
    _initializeNativeGateway();
  }

  Future<void> _initializeNativeGateway() async {
    try {
      await _nativeGateway.initialize();
      debugPrint('✅ WatchScreenNative: Native gateway initialized');
    } catch (e) {
      debugPrint(
          '❌ WatchScreenNative: Failed to initialize native gateway: $e');
      _showError('Failed to initialize native gateway: $e');
    }
  }

  /// Start the native IoT Gateway
  Future<void> _startNativeGateway() async {
    if (_deviceManager.selectedDevice == null) {
      _showError('No device selected. Please configure a device first.');
      return;
    }

    debugPrint('🚀 WatchScreenNative: Starting native IoT Gateway...');

    try {
      final success = await _nativeGateway.startGateway(
        deviceAddress: _deviceManager.selectedDevice!.address,
        userId: 'AnxieEase001', // This could be dynamic based on logged-in user
        deviceId: 'AnxieEase001',
      );

      if (success) {
        debugPrint('✅ WatchScreenNative: Native gateway started successfully');
        _showSuccess('Native IoT Gateway started successfully');
      } else {
        debugPrint('❌ WatchScreenNative: Failed to start native gateway');
        _showError(
            'Failed to start native gateway: ${_nativeGateway.lastError}');
      }
    } catch (e) {
      debugPrint('❌ WatchScreenNative: Error starting native gateway: $e');
      _showError('Error starting native gateway: $e');
    }
  }

  /// Stop the native IoT Gateway
  Future<void> _stopNativeGateway() async {
    debugPrint('🛑 WatchScreenNative: Stopping native IoT Gateway...');

    try {
      final success = await _nativeGateway.stopGateway();

      if (success) {
        debugPrint('✅ WatchScreenNative: Native gateway stopped successfully');
        _showSuccess('Native IoT Gateway stopped');
      } else {
        debugPrint('❌ WatchScreenNative: Failed to stop native gateway');
        _showError(
            'Failed to stop native gateway: ${_nativeGateway.lastError}');
      }
    } catch (e) {
      debugPrint('❌ WatchScreenNative: Error stopping native gateway: $e');
      _showError('Error stopping native gateway: $e');
    }
  }

  /// Reconnect to the device
  Future<void> _reconnectDevice() async {
    debugPrint('🔄 WatchScreenNative: Reconnecting device...');

    try {
      final success = await _nativeGateway.reconnectDevice();

      if (success) {
        debugPrint('✅ WatchScreenNative: Device reconnection initiated');
        _showSuccess('Device reconnection initiated');
      } else {
        debugPrint('❌ WatchScreenNative: Failed to reconnect device');
        _showError('Failed to reconnect device: ${_nativeGateway.lastError}');
      }
    } catch (e) {
      debugPrint('❌ WatchScreenNative: Error reconnecting device: $e');
      _showError('Error reconnecting device: $e');
    }
  }

  /// Send vibration command to device
  Future<void> _sendVibrationCommand() async {
    debugPrint('📳 WatchScreenNative: Sending vibration command...');

    try {
      final success = await _nativeGateway.sendDeviceCommand('vibrate');

      if (success) {
        debugPrint('✅ WatchScreenNative: Vibration command sent');
        _showSuccess('Vibration command sent to device');
      } else {
        debugPrint('❌ WatchScreenNative: Failed to send vibration command');
        _showError('Failed to send vibration command');
      }
    } catch (e) {
      debugPrint('❌ WatchScreenNative: Error sending vibration command: $e');
      _showError('Error sending vibration command: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native IoT Gateway Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ChangeNotifierProvider.value(
        value: _nativeGateway,
        child: Consumer<NativeIoTGatewayService>(
          builder: (context, gateway, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gateway Status Section
                  _buildGatewayStatusCard(gateway),
                  const SizedBox(height: 16),

                  // Device Connection Section
                  _buildDeviceConnectionCard(gateway),
                  const SizedBox(height: 16),

                  // Sensor Data Section
                  _buildSensorDataCard(gateway),
                  const SizedBox(height: 16),

                  // Anxiety Detection Section
                  _buildAnxietyDetectionCard(gateway),
                  const SizedBox(height: 16),

                  // Control Actions Section
                  _buildControlActionsCard(gateway),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGatewayStatusCard(NativeIoTGatewayService gateway) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  gateway.isGatewayRunning ? Icons.check_circle : Icons.error,
                  color: gateway.isGatewayRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Native IoT Gateway',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${gateway.status}',
              style: const TextStyle(fontSize: 14),
            ),
            if (gateway.lastError != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${gateway.lastError}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!gateway.isGatewayRunning)
                  ElevatedButton.icon(
                    onPressed: _startNativeGateway,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Gateway'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopNativeGateway,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Gateway'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceConnectionCard(NativeIoTGatewayService gateway) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  gateway.isDeviceConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: gateway.isDeviceConnected ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Device Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (gateway.deviceAddress.isNotEmpty) ...[
              Text(
                'Device: ${gateway.deviceAddress}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              gateway.isDeviceConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                fontSize: 14,
                color: gateway.isDeviceConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (gateway.isGatewayRunning && !gateway.isDeviceConnected) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _reconnectDevice,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDataCard(NativeIoTGatewayService gateway) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Real-time Sensor Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sensor readings grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSensorTile(
                  'Heart Rate',
                  gateway.heartRate?.toStringAsFixed(0) ?? '--',
                  'bpm',
                  Icons.favorite,
                  Colors.red,
                ),
                _buildSensorTile(
                  'SpO2',
                  gateway.spo2?.toStringAsFixed(1) ?? '--',
                  '%',
                  Icons.air,
                  Colors.blue,
                ),
                _buildSensorTile(
                  'Body Temp',
                  gateway.bodyTemperature?.toStringAsFixed(1) ?? '--',
                  '°C',
                  Icons.thermostat,
                  Colors.orange,
                ),
                _buildSensorTile(
                  'Battery',
                  gateway.batteryLevel?.toStringAsFixed(0) ?? '--',
                  '%',
                  Icons.battery_std,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  gateway.isDeviceWorn ? Icons.watch : Icons.watch_off,
                  color: gateway.isDeviceWorn ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  gateway.isDeviceWorn ? 'Device is worn' : 'Device not worn',
                  style: TextStyle(
                    color: gateway.isDeviceWorn ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            if (gateway.lastUpdate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last update: ${gateway.lastUpdate!.toLocal().toString().substring(11, 19)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTile(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnxietyDetectionCard(NativeIoTGatewayService gateway) {
    Color severityColor;
    IconData severityIcon;

    switch (gateway.anxietySeverity) {
      case 'severe':
        severityColor = Colors.red;
        severityIcon = Icons.warning;
        break;
      case 'moderate':
        severityColor = Colors.orange;
        severityIcon = Icons.error_outline;
        break;
      case 'mild':
        severityColor = Colors.yellow[700]!;
        severityIcon = Icons.info_outline;
        break;
      default:
        severityColor = Colors.green;
        severityIcon = Icons.check_circle_outline;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Anxiety Detection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(severityIcon, color: severityColor),
                const SizedBox(width: 8),
                Text(
                  'Current Level: ${gateway.anxietySeverity.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: severityColor,
                  ),
                ),
              ],
            ),
            if (gateway.anxietyConfidence > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(gateway.anxietyConfidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (gateway.lastAlertTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last alert: ${gateway.lastAlertTime!.toLocal().toString().substring(11, 19)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlActionsCard(NativeIoTGatewayService gateway) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.control_camera, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Device Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      gateway.isDeviceConnected ? _sendVibrationCommand : null,
                  icon: const Icon(Icons.vibration),
                  label: const Text('Vibrate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: gateway.isGatewayRunning ? _reconnectDevice : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Note: The native IoT Gateway continues running even when this app is closed.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Note: We do NOT dispose the native gateway here as it should continue
    // running independently of the UI
    super.dispose();
  }
}
