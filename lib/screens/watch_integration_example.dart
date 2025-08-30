import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/native_iot_gateway_service.dart';
import '../services/device_manager.dart';

/// Simple integration example showing how to add native IoT Gateway
/// to the existing watch.dart screen
class WatchScreenWithNativeGateway extends StatefulWidget {
  const WatchScreenWithNativeGateway({Key? key}) : super(key: key);

  @override
  State<WatchScreenWithNativeGateway> createState() =>
      _WatchScreenWithNativeGatewayState();
}

class _WatchScreenWithNativeGatewayState
    extends State<WatchScreenWithNativeGateway> {
  late NativeIoTGatewayService _nativeGateway;
  late DeviceManager _deviceManager;
  bool _useNativeGateway = false; // Toggle between Flutter and Native gateway

  @override
  void initState() {
    super.initState();
    _nativeGateway = NativeIoTGatewayService();
    _deviceManager = Provider.of<DeviceManager>(context, listen: false);
    _initializeNativeGateway();
  }

  Future<void> _initializeNativeGateway() async {
    try {
      await _nativeGateway.initialize();
      debugPrint('✅ Native gateway initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize native gateway: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnxieEase Monitor'),
        actions: [
          // Toggle button to switch between Flutter and Native gateway
          Switch(
            value: _useNativeGateway,
            onChanged: (value) async {
              if (value) {
                // Stop Flutter gateway and start Native gateway
                if (_deviceManager.isGatewayRunning) {
                  await _deviceManager.stopGateway();
                }
                await _startNativeGateway();
              } else {
                // Stop Native gateway and start Flutter gateway
                if (_nativeGateway.isGatewayRunning) {
                  await _nativeGateway.stopGateway();
                }
                await _deviceManager.startGateway();
              }
              setState(() {
                _useNativeGateway = value;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(_useNativeGateway ? 'Native' : 'Flutter'),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Gateway type indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _useNativeGateway ? Colors.green[50] : Colors.blue[50],
            child: Row(
              children: [
                Icon(
                  _useNativeGateway ? Icons.android : Icons.flutter_dash,
                  color: _useNativeGateway ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  _useNativeGateway
                      ? 'Using Native IoT Gateway (Background Independent)'
                      : 'Using Flutter IoT Gateway (App Dependent)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _useNativeGateway
                        ? Colors.green[800]
                        : Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),

          // Content based on gateway type
          Expanded(
            child: _useNativeGateway
                ? _buildNativeGatewayContent()
                : _buildFlutterGatewayContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeGatewayContent() {
    return ChangeNotifierProvider.value(
      value: _nativeGateway,
      child: Consumer<NativeIoTGatewayService>(
        builder: (context, gateway, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              gateway.isGatewayRunning
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: gateway.isGatewayRunning
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Native IoT Gateway',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Status: ${gateway.status}'),
                        Text('Connected: ${gateway.isDeviceConnected}'),
                        if (gateway.deviceAddress.isNotEmpty)
                          Text('Device: ${gateway.deviceAddress}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sensor data - shows REAL-TIME data from native service
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Real-time Sensor Data (from Native Service)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Heart Rate
                        _buildSensorRow(
                          'Heart Rate',
                          '${gateway.heartRate?.toStringAsFixed(0) ?? '--'} bpm',
                          Icons.favorite,
                          Colors.red,
                        ),

                        // SpO2
                        _buildSensorRow(
                          'SpO2',
                          '${gateway.spo2?.toStringAsFixed(1) ?? '--'}%',
                          Icons.air,
                          Colors.blue,
                        ),

                        // Temperature
                        _buildSensorRow(
                          'Body Temperature',
                          '${gateway.bodyTemperature?.toStringAsFixed(1) ?? '--'}°C',
                          Icons.thermostat,
                          Colors.orange,
                        ),

                        // Battery
                        _buildSensorRow(
                          'Battery',
                          '${gateway.batteryLevel?.toStringAsFixed(0) ?? '--'}%',
                          Icons.battery_std,
                          Colors.green,
                        ),

                        const SizedBox(height: 12),

                        // Anxiety detection
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: _getAnxietyColor(gateway.anxietySeverity),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Anxiety: ${gateway.anxietySeverity.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    _getAnxietyColor(gateway.anxietySeverity),
                              ),
                            ),
                          ],
                        ),

                        if (gateway.lastUpdate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last update: ${gateway.lastUpdate!.toLocal().toString().substring(11, 19)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Control buttons
                Row(
                  children: [
                    if (!gateway.isGatewayRunning)
                      ElevatedButton.icon(
                        onPressed: _startNativeGateway,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Native Gateway'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _nativeGateway.stopGateway(),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Gateway'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (gateway.isDeviceConnected)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _nativeGateway.sendDeviceCommand('vibrate'),
                        icon: const Icon(Icons.vibration),
                        label: const Text('Vibrate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Background operation info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Background Operation',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '✅ Native gateway continues running when app is closed\n'
                        '✅ Firebase data upload never stops\n'
                        '✅ Bluetooth connection maintained independently\n'
                        '✅ Real-time updates resume when app reopens',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlutterGatewayContent() {
    return Consumer<DeviceManager>(
      builder: (context, deviceManager, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            deviceManager.isGatewayRunning
                                ? Icons.check_circle
                                : Icons.error,
                            color: deviceManager.isGatewayRunning
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Flutter IoT Gateway',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${deviceManager.status}'),
                      Text('Running: ${deviceManager.isGatewayRunning}'),
                      if (deviceManager.selectedDevice != null)
                        Text('Device: ${deviceManager.selectedDevice!.name}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  if (!deviceManager.isGatewayRunning)
                    ElevatedButton.icon(
                      onPressed: () => deviceManager.startGateway(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Flutter Gateway'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => deviceManager.stopGateway(),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Gateway'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Flutter gateway limitations info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Flutter Gateway Limitations',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ Stops when app is closed or killed\n'
                      '⚠️ No background data collection\n'
                      '⚠️ Requires app to be open for monitoring\n'
                      '⚠️ Firebase uploads pause when app closes',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAnxietyColor(String severity) {
    switch (severity) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }

  Future<void> _startNativeGateway() async {
    if (_deviceManager.selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device selected. Please configure a device first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await _nativeGateway.startGateway(
      deviceAddress: _deviceManager.selectedDevice!.address,
      userId: 'AnxieEase001',
      deviceId: 'AnxieEase001',
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Native IoT Gateway started successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to start native gateway: ${_nativeGateway.lastError}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Note: We don't dispose the native gateway here as it should continue
    // running independently of the UI
    super.dispose();
  }
}
