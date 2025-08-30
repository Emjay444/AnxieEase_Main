import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/notification_service.dart';
import 'services/device_manager.dart';
import 'services/native_bluetooth_service.dart';
import 'pages/device_setup_page.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  _WatchScreenState createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late DatabaseReference _iotDataRef;
  bool isDeviceWorn = false;
  late NotificationService _notificationService;

  // IoT Sensor Data
  double? spo2Value;
  double? bodyTempValue;
  double? ambientTempValue;
  double? heartRateValue; // Heart rate from IoT data
  double batteryPercentage = 85.0; // Default fallback
  bool isConnected = false;

  // Firebase listeners
  StreamSubscription? _iotDataSubscription;

  // Device Manager
  late DeviceManager _deviceManager;

  // Setup completion state
  bool _isSetupComplete =
      true; // Temporarily set to true for testing background toggle
  bool _isCheckingSetup = true;

  // Enhanced monitoring state
  bool _isEnhancedMonitoringActive = false;

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

    // Get the NotificationService from Provider
    _notificationService =
        Provider.of<NotificationService>(context, listen: false);

    // Get the DeviceManager from Provider and listen to changes
    _deviceManager = Provider.of<DeviceManager>(context, listen: false);
    // Listen to DeviceManager changes to update UI when gateway status changes
    _deviceManager.addListener(_onDeviceManagerChanged);

    // Initialize and check for existing native service
    _initializeAndCheckService();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    // Reference to IoT Gateway data (this contains the real-time sensor data)
    _iotDataRef =
        FirebaseDatabase.instance.ref().child('devices/AnxieEase001/current');

    // Listen to IoT Gateway data for real-time sensor values
    _iotDataSubscription = _iotDataRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            // Extract data directly from the root level (new Firebase structure)
            // Extract sensor data (update only if present)
            final spo2Parsed = _asDouble(data['spo2']);
            if (spo2Parsed != null) spo2Value = spo2Parsed;

            final bodyTempParsed = _asDouble(data['bodyTemp']);
            if (bodyTempParsed != null) bodyTempValue = bodyTempParsed;

            final ambientTempParsed = _asDouble(data['ambientTemp']);
            if (ambientTempParsed != null) ambientTempValue = ambientTempParsed;

            final hrParsed = _asDouble(data['heartRate']);
            if (hrParsed != null) heartRateValue = hrParsed;

            // Extract device status and battery data (preserve last known if missing)
            final battParsed = _asDouble(data['battPerc']);
            if (battParsed != null) {
              batteryPercentage = battParsed;
            }

            final wornParsed = _asBool(data['worn']);
            if (wornParsed != null) {
              isDeviceWorn = wornParsed;
            }

            // For backwards compatibility, also check old structure
            if (data.containsKey('sensors')) {
              final sensors = data['sensors'] as Map<dynamic, dynamic>?;
              if (sensors != null) {
                spo2Value = spo2Value ?? _asDouble(sensors['spo2']);
                bodyTempValue =
                    bodyTempValue ?? _asDouble(sensors['bodyTemperature']);
                ambientTempValue = ambientTempValue ??
                    _asDouble(sensors['ambientTemperature']);
                heartRateValue =
                    heartRateValue ?? _asDouble(sensors['heartRate']);
              }
            }

            if (data.containsKey('device')) {
              final device = data['device'] as Map<dynamic, dynamic>?;
              if (device != null) {
                // Fallbacks only if root-level fields were missing in this snapshot
                if (battParsed == null) {
                  final devBatt = _asDouble(device['batterySmoothed']);
                  if (devBatt != null) batteryPercentage = devBatt;
                }

                if (wornParsed == null) {
                  final devWorn = _asBool(device['worn']);
                  if (devWorn != null) isDeviceWorn = devWorn;
                }

                final connParsed = device['isConnected'];
                if (connParsed is bool) {
                  isConnected = connParsed;
                }

                // Check if device is disconnected and bring back setup if needed
                if (!isConnected && _isSetupComplete) {
                  _handleDeviceDisconnection();
                }
              }
            }

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

    // Check if device setup is complete
    _checkSetupStatus();
  }

  /// Initialize and check for existing native service
  Future<void> _initializeAndCheckService() async {
    debugPrint('🔍 Watch: Checking for existing native service...');

    // Check if native service is already running
    final isNativeRunning = await NativeBluetoothService.isServiceRunning();
    debugPrint('🔍 Watch: Native service running: $isNativeRunning');

    if (isNativeRunning) {
      debugPrint(
          '✅ Watch: Native service detected - setting automatic monitoring active');
      setState(() {
        _isEnhancedMonitoringActive = true;
      });
      debugPrint(
          '✅ Watch: Automatic background monitoring is active from existing service');
    } else {
      debugPrint(
          '🔄 Watch: No native service detected - checking Flutter gateway...');

      // If no native service, check if Flutter gateway should start automatic monitoring
      if (_deviceManager.isGatewayRunning && !_isEnhancedMonitoringActive) {
        debugPrint(
            '🔄 Watch: Flutter gateway running - triggering automatic background monitoring...');
        // Use a small delay to ensure everything is initialized
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted &&
              _deviceManager.isGatewayRunning &&
              !_isEnhancedMonitoringActive) {
            _startEnhancedMonitoringInternal();
          }
        });
      }
    }
  }

  void _updateUI() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild when heart rate changes
      });
    }
  }

  /// Start IoT Gateway using Device Manager (Manual mode only)
  Future<void> _startIoTGateway() async {
    debugPrint('🚀 Watch: Starting IoT Gateway (manual mode)...');

    // If automatic monitoring is active, don't allow manual control
    if (_isEnhancedMonitoringActive) {
      _showError(
          'Cannot start manually - automatic background monitoring is active');
      return;
    }

    final success = await _deviceManager.startGateway();
    if (!success) {
      _showError('Failed to start IoT Gateway');
    } else {
      debugPrint('🚀 Watch: IoT Gateway started successfully (manual mode)');
      // Don't auto-start background monitoring in manual mode
    }
  }

  /// Stop IoT Gateway using Device Manager
  Future<void> _stopIoTGateway() async {
    debugPrint('🛑 Watch: Stopping IoT Gateway...');
    await _deviceManager.stopGateway();
    debugPrint('🛑 Watch: IoT Gateway stopped, UI should update');
  }

  /// Start background monitoring service (automatically called)
  Future<void> _startEnhancedMonitoringInternal() async {
    debugPrint('🛡️ Watch: _startEnhancedMonitoringInternal() called');
    debugPrint(
        '🛡️ Watch: Gateway running: ${_deviceManager.isGatewayRunning}');
    debugPrint(
        '🛡️ Watch: Selected device: ${_deviceManager.selectedDevice?.address}');

    // First, check if native service is already running
    final isNativeRunning = await NativeBluetoothService.isServiceRunning();
    debugPrint('🛡️ Watch: Native service already running: $isNativeRunning');

    if (isNativeRunning) {
      debugPrint('🛡️ Native Bluetooth service already running');
      setState(() {
        _isEnhancedMonitoringActive = true;
      });
      debugPrint(
          '✅ Watch: Background monitoring confirmed active (no restart needed)');
      return;
    }

    if (!_deviceManager.isGatewayRunning) {
      debugPrint(
          '⚠️ Watch: Gateway not running, skipping background monitoring');
      return;
    }

    try {
      debugPrint('🛡️ Watch: Starting background monitoring service...');

      // Stop Flutter IoT Gateway to prevent Bluetooth connection conflict
      debugPrint(
          '🛑 Watch: Stopping Flutter IoT Gateway to prevent conflicts...');
      await _deviceManager.stopGateway();
      debugPrint('✅ Watch: Flutter IoT Gateway stopped');

      // Add a small delay to ensure connection is fully released
      await Future.delayed(Duration(milliseconds: 500));
      debugPrint('⏱️ Watch: Connection release delay completed');

      // Use NativeBluetoothService directly
      final success = await NativeBluetoothService.startMonitoring(
        deviceAddress: _deviceManager.selectedDevice?.address ?? '',
        userId: 'AnxieEase001',
      );

      debugPrint(
          '🛡️ Watch: NativeBluetoothService.startMonitoring returned: $success');

      if (success) {
        setState(() {
          _isEnhancedMonitoringActive = true;
        });

        debugPrint('✅ Watch: Background monitoring started automatically');
      } else {
        debugPrint('❌ Watch: Background monitoring service failed to start');

        // If native service failed, restart Flutter IoT Gateway
        debugPrint('🔄 Watch: Restarting Flutter IoT Gateway after failure...');
        await _restartFlutterGateway();
      }
    } catch (e) {
      debugPrint('❌ Error starting background monitoring: $e');

      // If error occurs, restart Flutter IoT Gateway
      debugPrint('🔄 Watch: Restarting Flutter IoT Gateway after error...');
      await _restartFlutterGateway();
    }
  }

  /// Helper method to restart Flutter IoT Gateway
  Future<void> _restartFlutterGateway() async {
    try {
      final success = await _deviceManager.startGateway();
      if (success) {
        debugPrint('✅ Watch: Flutter IoT Gateway restarted successfully');
      } else {
        debugPrint('❌ Watch: Failed to restart Flutter IoT Gateway');
      }
    } catch (e) {
      debugPrint('❌ Error restarting Flutter IoT Gateway: $e');
    }
  }

  /// Stop background monitoring service
  Future<void> _stopEnhancedMonitoring() async {
    try {
      debugPrint('🛡️ Watch: Stopping background monitoring service...');

      // Use NativeBluetoothService directly
      final success = await NativeBluetoothService.stopMonitoring();

      if (success) {
        setState(() {
          _isEnhancedMonitoringActive = false;
        });

        debugPrint('✅ Watch: Background monitoring service stopped');

        // Restart Flutter IoT Gateway if device is available
        if (_deviceManager.selectedDevice != null) {
          debugPrint('🔄 Watch: Restarting Flutter IoT Gateway...');
          await _startIoTGateway();
          debugPrint('✅ Watch: Flutter IoT Gateway restarted');
        }

        _showSuccess(
            'Background monitoring stopped. Flutter IoT Gateway resumed.');
      } else {
        _showError('Failed to stop background monitoring service');
      }
    } catch (e) {
      debugPrint('❌ Error stopping enhanced monitoring: $e');
      _showError('Error: ${e.toString()}');
    }
  }

  /// Handle DeviceManager state changes
  void _onDeviceManagerChanged() {
    if (mounted) {
      debugPrint('🔄 Watch: DeviceManager state changed - rebuilding UI');
      debugPrint(
          '🔄 Watch: Gateway running: ${_deviceManager.isGatewayRunning}');
      debugPrint('🔄 Watch: Status: ${_deviceManager.status}');
      debugPrint(
          '🔄 Watch: Enhanced monitoring active: $_isEnhancedMonitoringActive');

      // Auto-start background monitoring when gateway becomes active (and not already active)
      if (_deviceManager.isGatewayRunning && !_isEnhancedMonitoringActive) {
        debugPrint(
            '🔄 Watch: Gateway just started - triggering automatic background monitoring...');
        // Use a small delay to ensure gateway is fully initialized
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted &&
              _deviceManager.isGatewayRunning &&
              !_isEnhancedMonitoringActive) {
            _startEnhancedMonitoringInternal();
          }
        });
      }

      setState(() {
        // This will trigger a rebuild when DeviceManager state changes
      });
    }
  }

  /// Check if device setup is complete
  Future<void> _checkSetupStatus() async {
    try {
      final isComplete = await _deviceManager.isSetupComplete();
      final hasDevice = _deviceManager.selectedDevice != null;

      setState(() {
        _isSetupComplete = isComplete && hasDevice;
        _isCheckingSetup = false;
      });

      debugPrint(
          '🔧 Watch: Setup status - Complete: $_isSetupComplete, Has Device: $hasDevice');
    } catch (e) {
      debugPrint('❌ Watch: Error checking setup status: $e');
      setState(() {
        _isSetupComplete = false;
        _isCheckingSetup = false;
      });
    }
  }

  /// Handle device disconnection - bring back setup view
  void _handleDeviceDisconnection() {
    setState(() {
      _isSetupComplete = false;
    });

    debugPrint('🔌 Watch: Device disconnected, showing setup view');

    // Show notification to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Device disconnected. Please reconnect your health monitor.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _notificationService.removeListener(_updateUI);
    // Remove DeviceManager listener
    _deviceManager.removeListener(_onDeviceManagerChanged);
    // Clean up Firebase listeners
    _iotDataSubscription?.cancel();
    // Note: We don't dispose the IoT Gateway here to keep it running
    // The gateway will continue running even when this widget is disposed
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh setup status when dependencies change (e.g., returning from setup page)
    if (!_isCheckingSetup) {
      _checkSetupStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔄 Watch build: Setup complete: $_isSetupComplete, Enhanced monitoring: $_isEnhancedMonitoringActive');

    // Get heart rate from IoT data (real-time from wearable)
    double heartRate =
        heartRateValue ?? _notificationService.currentHeartRate.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Health Monitor',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green, width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_done,
                                      color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'IoT',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        _controller.reset();
                        _controller.forward();
                        // Force refresh IoT data
                        _iotDataRef.keepSynced(true);
                        debugPrint('🔄 Watch: Refreshing IoT data connection');
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: _isCheckingSetup
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _isSetupComplete
                        ? _buildDeviceDataView(heartRate)
                        : _buildSetupView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the setup view for new users
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Setup Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.watch,
              size: 60,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          const Text(
            'Setup Your Health Monitor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Connect your IoT health monitoring device to start tracking your vital signs and receive real-time health insights.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Setup Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceSetupPage(),
                  ),
                );
                // Check setup status after returning
                await _checkSetupStatus();
              },
              icon: const Icon(Icons.settings, size: 24),
              label: const Text(
                'Setup Device',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the device data view for users with setup complete
  Widget _buildDeviceDataView(double heartRate) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // IoT Gateway Controls (Background - not center of attention)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _deviceManager.isGatewayRunning
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: _deviceManager.isGatewayRunning
                        ? Colors.green
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IoT Gateway',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _deviceManager.isGatewayRunning
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        Text(
                          _deviceManager.status,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_deviceManager.isGatewayRunning &&
                      !_isEnhancedMonitoringActive)
                    ElevatedButton(
                      onPressed: _deviceManager.isAutoConnecting
                          ? null
                          : _startIoTGateway,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _deviceManager.isAutoConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Start',
                              style: TextStyle(fontSize: 12),
                            ),
                    )
                  else if (_isEnhancedMonitoringActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: const Text(
                        'Auto Mode',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    )
                  else if (_deviceManager.isGatewayRunning)
                    ElevatedButton(
                      onPressed: () async {
                        // Stop automatic monitoring first, then stop gateway
                        if (_isEnhancedMonitoringActive) {
                          await _stopEnhancedMonitoring();
                        }
                        await _stopIoTGateway();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Stop',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Enhanced Background Monitoring Controls (Automatic)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEnhancedMonitoringActive
                    ? Colors.blue[50]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isEnhancedMonitoringActive
                        ? Colors.blue[200]!
                        : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEnhancedMonitoringActive
                        ? Icons.shield
                        : Icons.shield_outlined,
                    color:
                        _isEnhancedMonitoringActive ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Monitoring',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isEnhancedMonitoringActive
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        Text(
                          _isEnhancedMonitoringActive
                              ? 'Automatic service active - continues when app closed'
                              : 'Automatically activates when device connects',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isEnhancedMonitoringActive
                          ? Colors.blue
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isEnhancedMonitoringActive ? 'ACTIVE' : 'AUTO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Heart Rate Card (Larger and centered) - USER CENTER OF ATTENTION
            SizedBox(
              height: 220,
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.88,
                  child: _buildStatCard(
                    title: 'Heart Rate',
                    value: heartRate.toStringAsFixed(0),
                    unit: 'BPM',
                    icon: Icons.favorite,
                    color: const Color(0xFFFF5252),
                    progress: (heartRate / 100).clamp(0.0, 1.0),
                    range: '60-100',
                    isLarge: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Second row with Device Status and Battery
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Device Status',
                      value: isDeviceWorn ? 'Worn' : 'Not Worn',
                      unit: '',
                      icon: Icons.watch,
                      color: const Color(0xFF9C27B0),
                      progress: isDeviceWorn ? 1.0 : 0.0,
                      range: isConnected ? 'Connected' : 'Offline',
                      isLarge: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Battery',
                      value: batteryPercentage.toStringAsFixed(0),
                      unit: '%',
                      icon: Icons.battery_charging_full,
                      color: batteryPercentage > 20
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF5252),
                      progress: batteryPercentage / 100,
                      range: '0-100',
                      isLarge: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Third row with SpO2 and Body Temperature
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'SpO₂',
                      value: spo2Value?.toStringAsFixed(1) ?? '--',
                      unit: '%',
                      icon: Icons.health_and_safety,
                      color: const Color(0xFF2196F3),
                      progress: spo2Value != null
                          ? (spo2Value! / 100).clamp(0.0, 1.0)
                          : 0.0,
                      range: '95-100',
                      isLarge: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Body Temp',
                      value: bodyTempValue?.toStringAsFixed(1) ?? '--',
                      unit: '°C',
                      icon: Icons.thermostat,
                      color: const Color(0xFFFF9800),
                      progress: bodyTempValue != null
                          ? ((bodyTempValue! - 35) / 5).clamp(0.0, 1.0)
                          : 0.0,
                      range: '35-40',
                      isLarge: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Fourth row with Ambient Temperature and Connection Status
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Ambient Temp',
                      value: ambientTempValue?.toStringAsFixed(1) ?? '--',
                      unit: '°C',
                      icon: Icons.device_thermostat,
                      color: const Color(0xFF607D8B),
                      progress: ambientTempValue != null
                          ? ((ambientTempValue! - 15) / 25).clamp(0.0, 1.0)
                          : 0.0,
                      range: '15-40',
                      isLarge: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'IoT Status',
                      value: isConnected ? 'Active' : 'Inactive',
                      unit: '',
                      icon: Icons.cloud_done,
                      color: isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF9E9E9E),
                      progress: isConnected ? 1.0 : 0.0,
                      range: 'Gateway',
                      isLarge: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required double progress,
    required String range,
    bool isLarge = false,
  }) {
    // Determine if this is a status card with long value text
    bool isStatusValue = title == 'Device Status' || title == 'IoT Status';

    // Choose font size based on value length and card type
    double valueFontSize =
        isLarge ? 46 : (isStatusValue ? 22 : 30); // Reduced from 26 to 22

    return FadeTransition(
      opacity: _animation,
      child: LayoutBuilder(builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(isLarge ? 20 : 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icon and range
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isLarge ? 10 : 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isLarge ? 30 : 22,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      range,
                      style: TextStyle(
                        color: color,
                        fontSize: isLarge ? 13 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Spacing
              SizedBox(height: isLarge ? 20 : 12),

              // Title
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF2C3E50),
                  fontSize: isLarge ? 18 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Spacing
              SizedBox(height: isLarge ? 8 : 5),

              // Value and unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: valueFontSize, // Use calculated font size
                        fontWeight: isStatusValue
                            ? FontWeight.w600
                            : FontWeight.bold, // Lighter weight for status
                        height: 0.9,
                        letterSpacing: isStatusValue
                            ? -0.5
                            : 0, // Tighter letter spacing for status
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: isLarge ? 16 : 12,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),

              // Spacing - smaller to fit everything
              SizedBox(height: isLarge ? 14 : 10),

              // Progress bar
              Stack(
                children: [
                  Container(
                    height: isLarge ? 8 : 5,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: isLarge ? 8 : 5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
