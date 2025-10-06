import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/iot_sensor_service.dart';
import 'services/device_service.dart';
import 'services/admin_device_management_service.dart';
import 'providers/auth_provider.dart';
import 'services/supabase_service.dart';

/// Real-time health metrics dashboard integrated as wearable screen
///
/// Health monitoring screen with IoT sensor integration.
///
/// Displays live HR, baseline HR, temperature, and movement data
/// with beautiful modern UI components and real-time updates.
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  _WatchScreenState createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _refreshTimer;
  bool _isInitialized = false;
  String? _errorMessage;

  // Legacy IoT service integration
  late IoTSensorService _iotSensorService;
  late DeviceService _deviceService;

  // Health metrics data - initially null until Firebase data arrives
  double? bodyTempValue;
  double? ambientTempValue;
  double? heartRateValue;
  double? baselineHR;
  double? batteryPercentage; // Start as null until data arrives
  bool isDeviceWorn = false;
  bool isConnected = false; // Start disconnected
  bool _hasRealtimeData = false;
  bool _isDeviceSetup = false;

  // Firebase references and listeners
  StreamSubscription? _iotDataSubscription;
  late DatabaseReference _currentDataRef;

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
    _initializeAnimations();
    _initializeService();
    _startPeriodicRefresh();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  Future<void> _initializeService() async {
    try {
      // Get services from Provider
      _iotSensorService = Provider.of<IoTSensorService>(context, listen: false);
      _deviceService = DeviceService();

      // Check if device is setup (you can modify this logic based on your app's requirements)
      await _checkDeviceSetup();

      // Initialize the device service to load baseline data
      await _deviceService.initialize();

      // Load baseline data and update UI
      await _loadBaselineData();

      // Listen to IoT Sensor Service changes
      _iotSensorService.addListener(_onIoTSensorChanged);

      // Initialize IoT service
      await _initializeIoTService();

      // Initialize Firebase references
      final deviceId = _deviceService.linkedDevice?.deviceId ?? 'AnxieEase001';
      _currentDataRef =
          FirebaseDatabase.instance.ref().child('devices/$deviceId/current');

      debugPrint(
          '📱 WatchScreen: Initialized Firebase reference for device: $deviceId');
      debugPrint('📱 WatchScreen: Firebase path: devices/$deviceId/current');

      // Test Firebase connection by doing a one-time read
      _testFirebaseConnection();

      // Listen to real-time current data updates - SIMPLIFIED VERSION
      _iotDataSubscription = _currentDataRef.onValue.listen((event) {
        if (event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            debugPrint('📱 WatchScreen: Raw Firebase data: $data');

            setState(() {
              // Simply extract and display all data without any suppression logic
              heartRateValue = _asDouble(data['heartRate']) ?? 0.0;
              bodyTempValue = _asDouble(data['bodyTemp']) ?? 0.0;
              ambientTempValue = _asDouble(data['ambientTemp']) ?? 0.0;
              batteryPercentage = _asDouble(data['battPerc']) ?? 0.0;
              isDeviceWorn = _asBool(data['worn']) ?? false;

              // Always show as connected if we receive any data
              isConnected = true;
              _hasRealtimeData = true;

              debugPrint(
                  '📱 WatchScreen: HR: $heartRateValue, Temp: $bodyTempValue, Battery: $batteryPercentage%, Worn: $isDeviceWorn');
            });

            // Update pulse animation
            _updatePulseAnimation();
          } catch (e) {
            debugPrint('❌ WatchScreen: Error parsing Firebase data: $e');
          }
        } else {
          debugPrint('📱 WatchScreen: Firebase snapshot value is null');
        }
      }, onError: (error) {
        debugPrint('❌ WatchScreen: Firebase listener error: $error');
      });

      setState(() {
        _isInitialized = true;
      });

      // Start pulse animation if heart rate is available
      _updatePulseAnimation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  void _updatePulseAnimation() {
    if (heartRateValue != null && heartRateValue! > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      debugPrint('🔥 WatchScreen: Testing Firebase connection...');
      final snapshot = await _currentDataRef.get();

      if (snapshot.exists) {
        debugPrint('🔥 WatchScreen: Firebase connection successful!');
        debugPrint('🔥 WatchScreen: Data exists: ${snapshot.value}');
      } else {
        debugPrint('🔥 WatchScreen: Firebase connected but no data at path');
      }
    } catch (e) {
      debugPrint('❌ WatchScreen: Firebase connection test failed: $e');
    }
  }

  /// Check if device is properly setup
  Future<void> _checkDeviceSetup() async {
    try {
      // First check if admin has assigned a device to this user
      final adminDeviceService = AdminDeviceManagementService();
      final assignmentStatus = await adminDeviceService.checkDeviceAssignment();

      if (assignmentStatus.canUseDevice) {
        _isDeviceSetup = true;

        // Check device freshness - get device info to check last_seen_at
        final deviceInfo = await adminDeviceService.getCurrentAssignmentInfo();
        if (deviceInfo != null) {
          final lastSeenStr = deviceInfo['last_seen_at'] as String?;
          final batteryLevel = deviceInfo['battery_level'] as num?;

          if (lastSeenStr != null) {
            final lastSeen = DateTime.parse(lastSeenStr).toLocal();
            final minutesSinceLastSeen =
                DateTime.now().difference(lastSeen).inMinutes;

            // If device hasn't been seen in over 5 minutes, mark as disconnected
            if (minutesSinceLastSeen > 5) {
              setState(() {
                isConnected = false;
                _hasRealtimeData = false;
              });
              debugPrint(
                  'Device setup check: Device stale - last seen $minutesSinceLastSeen minutes ago');
            } else {
              debugPrint('Device setup check: Device recently active');
            }
          } else {
            // No last_seen_at data, assume disconnected
            setState(() {
              isConnected = false;
              _hasRealtimeData = false;
            });
            debugPrint(
                'Device setup check: No last seen data - assuming disconnected');
          }

          // Update battery from actual device data
          if (batteryLevel != null) {
            setState(() {
              batteryPercentage = batteryLevel.toDouble();
            });
          }
        }

        debugPrint('Device setup check: Admin assigned device available');
        return;
      }

      // Fallback: Check if user has any linked devices in Supabase
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        final supabaseService = SupabaseService();
        final response = await supabaseService.client
            .from('wearable_devices')
            .select('device_id')
            .eq('user_id', user.id)
            .eq('is_active', true);

        // Device is setup if user has at least one active device
        _isDeviceSetup = response.isNotEmpty;
        debugPrint(
            'Device setup check: ${_isDeviceSetup ? "Device linked" : "No device linked"}');
      } else {
        _isDeviceSetup = false;
        debugPrint('Device setup check: No user authenticated');
      }
    } catch (e) {
      // No device available
      _isDeviceSetup = false;
      debugPrint('Device setup check: No assigned device (error: $e)');
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI
      }
    });
  }

  /// Initialize IoT Sensor Service (for real device monitoring)
  Future<void> _initializeIoTService() async {
    try {
      await _iotSensorService.initialize();
      // Ensure initial animation reflects current state
      _updatePulseAnimation();

      // Update connection state - start as disconnected
      setState(() {
        isConnected = false; // Will be true when real device data arrives
        if (!isConnected) {
          _hasRealtimeData = false;
        }
      });

      debugPrint(
          '📱 WatchScreen: IoT service initialized - waiting for real device data');
    } catch (e) {
      debugPrint('❌ Wearable: Error initializing IoT service: $e');
    }
  }

  /// Load baseline heart rate data from the device service
  Future<void> _loadBaselineData() async {
    try {
      // Get the current baseline from device service
      final baseline = _deviceService.currentBaseline;

      if (baseline != null) {
        setState(() {
          baselineHR = baseline.baselineHR;
        });
        debugPrint(
            '📊 WatchScreen: Loaded baseline HR: ${baseline.baselineHR.toStringAsFixed(1)} BPM');
      } else {
        debugPrint(
            '📊 WatchScreen: No baseline data found - using default value');
        setState(() {
          baselineHR = 70.0; // Default baseline
        });
      }
    } catch (e) {
      debugPrint('📊 WatchScreen: Error loading baseline data: $e');
      setState(() {
        baselineHR = 70.0; // Fallback to default
      });
    }
  }

  /// Refresh baseline data (call this when returning from baseline recording)
  Future<void> refreshBaselineData() async {
    debugPrint('📊 WatchScreen: Refreshing baseline data...');
    await _deviceService.initialize(); // Re-initialize to load latest baseline
    await _loadBaselineData(); // Update UI with new baseline
  }

  void _onIoTSensorChanged() {
    if (mounted) {
      setState(() {
        // Only update connection status from IoT service if we don't have Firebase data
        if (!_hasRealtimeData) {
          isConnected = _iotSensorService.isConnected;
          if (!isConnected) {
            _hasRealtimeData = false;
          }
        }

        // Update current values from service
        if (_iotSensorService.isActive) {
          heartRateValue = _iotSensorService.heartRate;
          bodyTempValue = _iotSensorService.bodyTemperature;
          ambientTempValue = _iotSensorService.ambientTemperature;
          batteryPercentage = _iotSensorService.batteryLevel;
          isDeviceWorn = _iotSensorService.isDeviceWorn;
        }
      });
    }
    // Ensure animation reflects any state changes
    _updatePulseAnimation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _refreshTimer?.cancel();
    _iotDataSubscription?.cancel();

    _iotSensorService.removeListener(_onIoTSensorChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isInitialized ? _buildDashboard() : _buildLoadingView(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Your Wearable',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF3AA772),
      elevation: 0,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (_isDeviceSetup &&
                      _iotSensorService.deviceId.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      _iotSensorService.deviceId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3AA772)),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing your wearable...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (!_isDeviceSetup) {
      return _buildDeviceSetupView();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF3AA772),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Low battery warning banner
            if (isConnected &&
                batteryPercentage != null &&
                batteryPercentage! <= 10 &&
                batteryPercentage! > 0)
              _buildLowBatteryWarning(),

            // Device status card
            _buildDeviceStatusCard(),
            const SizedBox(height: 24),

            // Main metrics grid
            _buildMainMetricsGrid(),
            const SizedBox(height: 24),

            // Heart rate section
            _buildHeartRateSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializeService();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSetupView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Admin Device Assignment Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact an administrator to assign a wearable device to your account. Once assigned, you can start monitoring your health metrics.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Device Setup Information Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Device Setup Requirements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'When your device is assigned, ensure:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSetupStep('1', 'Device is turned ON'),
                    _buildSetupStep(
                        '2', 'Connected to "AnxieEase" WiFi hotspot'),
                    _buildSetupStep('3', 'WiFi password: "11112222"'),
                    _buildSetupStep(
                        '4', 'Device is sending data to the system'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupStep(String stepNumber, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3AA772),
            const Color(0xFF3AA772).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3AA772).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.watch,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AnxieEase001',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getConnectionStatusColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getConnectionStatusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    // Removed 'Last seen' per request
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBatteryStatusItem(),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Worn',
                  isDeviceWorn ? 'Yes' : 'No',
                  Icons.accessibility,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryStatusItem() {
    final battery = batteryPercentage ?? 0;
    final isDisconnected = !isConnected;
    final isLowBattery = battery <= 10;
    final isCriticalBattery = battery <= 5;
    // Treat disconnected or stale as offline for battery display
    final isBatteryOffline =
        isDisconnected || batteryPercentage == null || battery <= 0;

    // Choose appropriate icon and color
    IconData batteryIcon;
    Color iconColor;
    Color textColor;

    if (isBatteryOffline) {
      batteryIcon = Icons.battery_unknown;
      iconColor = Colors.grey;
      textColor = Colors.grey;
    } else if (batteryPercentage == null) {
      // Connected but no battery data yet
      batteryIcon = Icons.battery_std;
      iconColor = Colors.white.withOpacity(0.7);
      textColor = Colors.white.withOpacity(0.7);
    } else if (isCriticalBattery) {
      batteryIcon = Icons.battery_alert;
      iconColor = Colors.red;
      textColor = Colors.red;
    } else if (isLowBattery) {
      batteryIcon = Icons.battery_2_bar;
      iconColor = Colors.orange;
      textColor = Colors.orange;
    } else if (battery < 25) {
      batteryIcon = Icons.battery_3_bar;
      iconColor = Colors.yellow;
      textColor = Colors.white;
    } else if (battery < 50) {
      batteryIcon = Icons.battery_4_bar;
      iconColor = Colors.white;
      textColor = Colors.white;
    } else {
      batteryIcon = Icons.battery_full;
      iconColor = Colors.green;
      textColor = Colors.white;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(batteryIcon, color: iconColor, size: 28),
            // Add warning indicator for low battery
            if (batteryPercentage != null && isLowBattery && !isBatteryOffline)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCriticalBattery ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isBatteryOffline
              ? '--'
              : batteryPercentage == null
                  ? '--'
                  : '${battery.toStringAsFixed(0)}%',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Battery',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            if (batteryPercentage != null &&
                isLowBattery &&
                !isBatteryOffline) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.warning,
                color: isCriticalBattery ? Colors.red : Colors.orange,
                size: 14,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLowBatteryWarning() {
    final battery = batteryPercentage ?? 0;
    final isCritical = battery <= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? Icons.battery_alert : Icons.battery_2_bar,
            color: isCritical ? Colors.red : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? 'Critical Battery!' : 'Low Battery Warning',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCritical ? Colors.red[700] : Colors.orange[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCritical
                      ? 'Device battery at ${battery.toStringAsFixed(0)}%. Please charge immediately!'
                      : 'Device battery at ${battery.toStringAsFixed(0)}%. Consider charging soon.',
                  style: TextStyle(
                    color: isCritical ? Colors.red[600] : Colors.orange[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.warning,
            color: isCritical ? Colors.red : Colors.orange,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMainMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // For 3 cards, use a more flexible layout
        return Column(
          children: [
            // First row: Heart Rate and Baseline HR (2 cards)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Heart Rate',
                    value: heartRateValue?.toStringAsFixed(0) ?? '--',
                    unit: 'BPM',
                    icon: Icons.favorite,
                    color: Colors.red,
                    isAnimated: heartRateValue != null && heartRateValue! > 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Baseline HR',
                    value: baselineHR?.toStringAsFixed(0) ?? '70',
                    unit: 'BPM',
                    icon: Icons.trending_flat,
                    color: _deviceService.hasBaseline
                        ? const Color(0xFF3AA772)
                        : Colors.grey[600]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Second row: Temperature (centered, single card)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Temperature',
                    value: bodyTempValue?.toStringAsFixed(1) ?? '--',
                    unit: '°C',
                    icon: Icons.thermostat,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    bool isAnimated = false,
  }) {
    Widget cardContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isAnimated) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildHeartRateSection() {
    if (heartRateValue == null || baselineHR == null) {
      return const SizedBox.shrink();
    }

    final difference = heartRateValue! - (baselineHR ?? 70);
    final status = _getHeartRateStatus(heartRateValue!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF3AA772)),
              const SizedBox(width: 8),
              const Text(
                'Heart Rate Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current vs Baseline'),
                  Text(
                    '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(0)} BPM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getHeartRateStatusColor(status),
                    ),
                  ),
                ],
              ),
              _buildHeartRateStatusChip(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getHeartRateStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getHeartRateStatusColor(status).withOpacity(0.3),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getHeartRateStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {});
    }
  }

  Color _getConnectionStatusColor() {
    if (!isConnected) return Colors.red;

    if (!isDeviceWorn) return Colors.orange;
    return Colors.green;
  }

  String _getConnectionStatusText() {
    if (!isConnected) return 'Disconnected';

    if (!isDeviceWorn) return 'Not Worn';
    return 'Active';
  }

  // Last seen formatter removed because the label was removed from UI

  String _getHeartRateStatus(double hr) {
    if (hr >= 120) return 'Very High';
    if (hr >= 100) return 'High';
    if (hr >= 85) return 'Elevated';
    if (hr >= 60) return 'Normal';
    if (hr >= 40) return 'Low';
    return 'Very Low';
  }

  Color _getHeartRateStatusColor(String status) {
    switch (status) {
      case 'Normal':
        return Colors.green;
      case 'Elevated':
        return Colors.orange;
      case 'High':
      case 'Very High':
        return Colors.red;
      case 'Low':
      case 'Very Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
