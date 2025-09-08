import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/notification_service.dart';
import 'services/iot_sensor_service.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  _WatchScreenState createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late DatabaseReference _iotDataRef;
  bool isDeviceWorn = false;
  late NotificationService _notificationService;

  // IoT Sensor Data
  double? spo2Value;
  double? bodyTempValue;
  double? ambientTempValue;
  double? heartRateValue;
  double batteryPercentage = 85.0;
  bool isConnected = false;

  // Firebase listeners
  StreamSubscription? _iotDataSubscription;

  // IoT Sensor Service
  late IoTSensorService _iotSensorService;

  // Monitoring state
  bool _isMonitoringActive = false;

  // Safe converters to avoid type issues and preserve last-known values
  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool? _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Get services from Provider
    _notificationService =
        Provider.of<NotificationService>(context, listen: false);
    _iotSensorService = Provider.of<IoTSensorService>(context, listen: false);

    // Listen to IoT Sensor Service changes
    _iotSensorService.addListener(_onIoTSensorChanged);

    // Initialize IoT service
    _initializeIoTService();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();

    // Reference to IoT Gateway data
    _iotDataRef =
        FirebaseDatabase.instance.ref().child('devices/AnxieEase001/current');

    // Listen to IoT data stream for real-time sensor values
    _iotDataSubscription = _iotDataRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            // Extract sensor data
            final spo2Parsed = _asDouble(data['spo2']);
            if (spo2Parsed != null) spo2Value = spo2Parsed;

            final bodyTempParsed = _asDouble(data['bodyTemp']);
            if (bodyTempParsed != null) bodyTempValue = bodyTempParsed;

            final ambientTempParsed = _asDouble(data['ambientTemp']);
            if (ambientTempParsed != null) ambientTempValue = ambientTempParsed;

            final hrParsed = _asDouble(data['heartRate']);
            if (hrParsed != null) heartRateValue = hrParsed;

            // Extract device status and battery data
            final battParsed = _asDouble(data['battPerc']);
            if (battParsed != null) {
              batteryPercentage = battParsed;
            }

            final wornParsed = _asBool(data['worn']);
            if (wornParsed != null) {
              isDeviceWorn = wornParsed;
            }

            // Update connection status
            isConnected = _iotSensorService.isConnected;

            debugPrint(
                '📊 Watch: Updated IoT data - HR: $heartRateValue, SpO2: $spo2Value, Battery: $batteryPercentage, Worn: $isDeviceWorn');
          });
        } catch (e) {
          debugPrint('Error parsing IoT data: $e');
        }
      }
    });

    // Listen to NotificationService changes for heart rate updates
    _notificationService.addListener(_updateUI);
  }

  /// Initialize IoT Sensor Service
  Future<void> _initializeIoTService() async {
    debugPrint('🔧 Watch: Initializing IoT Sensor Service...');

    try {
      await _iotSensorService.initialize();

      // Update monitoring state
      setState(() {
        _isMonitoringActive = _iotSensorService.isActive;
        isConnected = _iotSensorService.isConnected;
      });

      debugPrint('✅ Watch: IoT Sensor Service initialized');
    } catch (e) {
      debugPrint('❌ Watch: Error initializing IoT service: $e');
    }
  }

  void _onIoTSensorChanged() {
    if (mounted) {
      setState(() {
        _isMonitoringActive = _iotSensorService.isActive;
        isConnected = _iotSensorService.isConnected;

        // Update current values from service
        if (_iotSensorService.isActive) {
          heartRateValue = _iotSensorService.heartRate;
          spo2Value = _iotSensorService.spo2;
          bodyTempValue = _iotSensorService.bodyTemperature;
          ambientTempValue = _iotSensorService.ambientTemperature;
          batteryPercentage = _iotSensorService.batteryLevel;
          isDeviceWorn = _iotSensorService.isDeviceWorn;
        }
      });
    }
  }

  void _updateUI() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild when heart rate changes
      });
    }
  }

  /// Start IoT sensor monitoring
  Future<void> _startIoTMonitoring() async {
    debugPrint('🚀 Watch: Starting IoT monitoring...');

    try {
      await _iotSensorService.startSensors();
      debugPrint('🚀 Watch: IoT monitoring started successfully');

      _showSuccess('IoT monitoring started successfully');
    } catch (e) {
      debugPrint('❌ Watch: Error starting IoT monitoring: $e');
      _showError('Failed to start IoT monitoring: $e');
    }
  }

  /// Stop IoT sensor monitoring
  Future<void> _stopIoTMonitoring() async {
    debugPrint('🛑 Watch: Stopping IoT monitoring...');

    try {
      await _iotSensorService.stopSensors();
      debugPrint('🛑 Watch: IoT monitoring stopped successfully');

      _showSuccess('IoT monitoring stopped');
    } catch (e) {
      debugPrint('❌ Watch: Error stopping IoT monitoring: $e');
      _showError('Failed to stop IoT monitoring: $e');
    }
  }

  /// Simulate stress event for testing
  Future<void> _simulateStressEvent() async {
    debugPrint('⚠️ Watch: Simulating stress event...');

    try {
      await _iotSensorService.simulateStressEvent();
      _showSuccess('Stress event simulated - watch for elevated readings');
    } catch (e) {
      debugPrint('❌ Watch: Error simulating stress event: $e');
      _showError('Failed to simulate stress event: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _iotDataSubscription?.cancel();
    _notificationService.removeListener(_updateUI);
    _iotSensorService.removeListener(_onIoTSensorChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTopStatus(),
              const SizedBox(height: 16),
              Expanded(child: _buildHeartDial(context)),
              const SizedBox(height: 12),
              _buildMiniStatsRow(),
              const SizedBox(height: 16),
              _buildControlsBar(context),
              const SizedBox(height: 12),
              _buildDeviceStatus(),
            ],
          ),
        ),
      ),
    );
  }

  // Classic top status row with connection and worn indicators
  Widget _buildTopStatus() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isConnected ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isDeviceWorn ? Colors.blue : Colors.grey).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(isDeviceWorn ? Icons.watch : Icons.watch_off,
                  color: isDeviceWorn ? Colors.blue : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(isDeviceWorn ? 'Worn' : 'Not Worn',
                  style: TextStyle(
                    color: isDeviceWorn ? Colors.blue[800] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Icon(Icons.battery_full,
                color: batteryPercentage >= 20 ? Colors.green : Colors.red,
                size: 18),
            const SizedBox(width: 6),
            Text('${batteryPercentage.round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Color _hrColor(double hr) {
    if (!isDeviceWorn) return Colors.grey;
    if (hr >= 120) return Colors.red;
    if (hr >= 100) return Colors.orange;
    if (hr >= 85) return Colors.amber;
    return Colors.green;
  }

  Widget _buildHeartDial(BuildContext context) {
    final hr = heartRateValue ?? 0;
    final display = heartRateValue?.round().toString() ?? '--';
    final color = _hrColor(hr);
    final normalized = (hr.clamp(40, 160) - 40) / (160 - 40);

    return LayoutBuilder(
      builder: (ctx, c) {
        final size = c.maxWidth * 0.72;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: normalized.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value.isNaN ? 0 : value,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 700),
                scale: hr > 100 ? 1.05 : 1.0,
                curve: Curves.easeInOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: color, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      display,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('BPM',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            label: 'SpO2',
            value: spo2Value != null ? '${spo2Value!.round()}%' : '--',
            icon: Icons.air,
            color: Colors.blue,
            active: isDeviceWorn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniStat(
            label: 'Body Temp',
            value: bodyTempValue != null && bodyTempValue! > 0
                ? '${bodyTempValue!.toStringAsFixed(1)}°C'
                : '--',
            icon: Icons.thermostat,
            color: Colors.orange,
            active: isDeviceWorn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniStat(
            label: 'Battery',
            value: '${batteryPercentage.round()}%',
            icon: Icons.battery_full,
            color: Colors.green,
            active: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? color : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.black87 : Colors.grey,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: active ? color : Colors.grey,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _isMonitoringActive ? _stopIoTMonitoring : _startIoTMonitoring,
            icon: Icon(_isMonitoringActive ? Icons.stop : Icons.play_arrow),
            label: Text(_isMonitoringActive ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoringActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_isMonitoringActive)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _simulateStressEvent,
              icon: const Icon(Icons.warning_amber),
              label: const Text('Simulate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Device ID', _iotSensorService.deviceId),
            _buildStatusRow(
                'Connection', isConnected ? 'Connected' : 'Disconnected'),
            _buildStatusRow(
                'Monitoring', _isMonitoringActive ? 'Active' : 'Inactive'),
            _buildStatusRow('Device Worn', isDeviceWorn ? 'Yes' : 'No'),
            _buildStatusRow('Data Source', 'IoT Simulation'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
