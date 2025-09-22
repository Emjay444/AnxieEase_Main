import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/notification_service.dart';
import 'services/iot_sensor_service.dart';
import 'services/device_service.dart';
import 'providers/auth_provider.dart';
import 'services/supabase_service.dart';

/// Real-time health metrics dashboard integrated as wearable screen
///
/// Displays live HR, baseline HR, temperature, SpO2, and movement data
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
  late NotificationService _notificationService;
  late IoTSensorService _iotSensorService;
  late DeviceService _deviceService;

  // Health metrics data
  double? spo2Value;
  double? bodyTempValue;
  double? ambientTempValue;
  double? heartRateValue;
  double? baselineHR;
  double batteryPercentage = 85.0;
  bool isDeviceWorn = false;
  bool isConnected = false;
  bool _hasRealtimeData = false;
  bool _isMonitoringActive = false;
  bool _isDeviceSetup = false;

  // Connection states
  String _connectionState = 'disconnected';

  // Firebase references and listeners
  StreamSubscription? _iotDataSubscription;
  late DatabaseReference _currentDataRef;

  // Firebase validation timer
  Timer? _firebaseValidationTimer;

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
      _notificationService =
          Provider.of<NotificationService>(context, listen: false);
      _iotSensorService = Provider.of<IoTSensorService>(context, listen: false);
      _deviceService = DeviceService();

      // Check if device is setup (you can modify this logic based on your app's requirements)
      await _checkDeviceSetup();

      // Listen to IoT Sensor Service changes
      _iotSensorService.addListener(_onIoTSensorChanged);

      // Initialize IoT service
      await _initializeIoTService();

      // Initialize Firebase references
      final deviceId = _deviceService.linkedDevice?.deviceId ?? 'AnxieEase001';
      _currentDataRef =
          FirebaseDatabase.instance.ref().child('devices/$deviceId/current');

      // Listen to real-time current data updates
      _iotDataSubscription = _currentDataRef.onValue.listen((event) {
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
              if (ambientTempParsed != null)
                ambientTempValue = ambientTempParsed;

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

              // Mark that we have received live data
              final wasFirstData = !_hasRealtimeData;
              _hasRealtimeData = (hrParsed != null) ||
                  (spo2Parsed != null) ||
                  (bodyTempParsed != null) ||
                  (battParsed != null);

              // If this is the first data and monitoring is active, show success and update connection state
              if (wasFirstData && _hasRealtimeData && _isMonitoringActive) {
                _firebaseValidationTimer?.cancel();
                _connectionState = 'connected';
              }

              // If not worn, clear vitals to avoid misleading UI
              if (!isDeviceWorn) {
                heartRateValue = null;
                spo2Value = null;
              }
            });
            // Update pulse speed based on latest values
            _updatePulseAnimation();
          } catch (e) {
            debugPrint('Error parsing IoT data: $e');
          }
        }
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

  /// Check if device is properly setup
  Future<void> _checkDeviceSetup() async {
    try {
      // Check if user has any linked devices in Supabase
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
      // Fallback to IoT service check if database query fails
      _isDeviceSetup = _iotSensorService.deviceId.isNotEmpty &&
          _iotSensorService.deviceId != 'Unknown';
      debugPrint('Device setup check fallback: $_isDeviceSetup (error: $e)');
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

      // Update monitoring state - but don't auto-start for real device
      setState(() {
        _isMonitoringActive = false; // Will be true when real device connects
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

  void _onIoTSensorChanged() {
    if (mounted) {
      setState(() {
        _isMonitoringActive = _iotSensorService.isActive;
        isConnected = _iotSensorService.isConnected;
        if (!isConnected) {
          _hasRealtimeData = false;
        }

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
    // Ensure animation reflects any state changes
    _updatePulseAnimation();
  }

  /// Start monitoring (for real device - no mock data generation)
  Future<void> _startIoTMonitoring() async {
    try {
      setState(() {
        _hasRealtimeData = false;
        _connectionState = 'connecting';
        _isMonitoringActive = true;
      });

      // Note: Real device should write directly to Firebase
      // We just set the service as active but don't generate mock data
      await _iotSensorService
          .startSensors(); // This will not generate mock data anymore

      // Start validation timer to check if real device data arrives
      _startFirebaseValidation();

      debugPrint(
          '📱 WatchScreen: Monitoring started - waiting for real device data at /devices/AnxieEase001/current');
    } catch (e) {
      setState(() {
        _connectionState = 'disconnected';
      });
      _showError('Failed to start monitoring: $e');
    }
  }

  /// Start Firebase data validation after monitoring begins
  void _startFirebaseValidation() {
    // Cancel any existing timer
    _firebaseValidationTimer?.cancel();

    // Wait 3 seconds to see if Firebase data arrives
    _firebaseValidationTimer = Timer(const Duration(seconds: 3), () {
      if (!_hasRealtimeData && _isMonitoringActive) {
        // No Firebase data received - show no connection state
        setState(() {
          _connectionState = 'no_connection';
        });
      } else if (_hasRealtimeData) {
        // Firebase data flowing - show connected state
        setState(() {
          _connectionState = 'connected';
        });
      }
    });
  }

  /// Stop IoT sensor monitoring
  Future<void> _stopIoTMonitoring() async {
    try {
      // Cancel any pending validation
      _firebaseValidationTimer?.cancel();

      await _iotSensorService.stopSensors();

      // Reset connection state when stopping
      setState(() {
        _connectionState = 'disconnected';
        _hasRealtimeData = false;
        _isMonitoringActive = false;
      });
    } catch (e) {
      setState(() {
        _connectionState = 'disconnected';
        _isMonitoringActive = false;
      });
      _showError('Failed to stop IoT monitoring: $e');
    }
  }

  // Connection status helper methods
  IconData _getConnectionIcon() {
    switch (_connectionState) {
      case 'connected':
        return Icons.wifi;
      case 'connecting':
        return Icons.wifi_tethering;
      case 'no_connection':
        return Icons.wifi_off;
      default: // 'disconnected'
        return Icons.wifi_off;
    }
  }

  String _getConnectionLabel() {
    switch (_connectionState) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting';
      case 'no_connection':
        return 'No Connection';
      default: // 'disconnected'
        return 'Disconnected';
    }
  }

  Color _getConnectionColor() {
    switch (_connectionState) {
      case 'connected':
        return Colors.green;
      case 'connecting':
        return Colors.orange;
      case 'no_connection':
        return Colors.red;
      default: // 'disconnected'
        return Colors.grey;
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
    _pulseController.dispose();
    _fadeController.dispose();
    _refreshTimer?.cancel();
    _iotDataSubscription?.cancel();
    _firebaseValidationTimer?.cancel();
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
        'Health Dashboard',
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
            'Initializing health dashboard...',
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
            // Device status card
            _buildDeviceStatusCard(),
            const SizedBox(height: 24),

            // Main metrics grid
            _buildMainMetricsGrid(),
            const SizedBox(height: 24),

            // Heart rate section
            _buildHeartRateSection(),
            const SizedBox(height: 24),

            // Control buttons
            _buildControlButtons(),
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
                Icons.watch,
                size: 80,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Device Setup Required',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect your wearable device to start tracking your health metrics in real-time.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Steps:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSetupStep(1, 'Turn on your wearable device'),
                  _buildSetupStep(2, 'Enable Bluetooth on your phone'),
                  _buildSetupStep(3, 'Tap "Setup Device" to connect'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to device setup or pairing screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device setup not implemented yet'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Setup Device',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isDeviceSetup = true; // Temporary skip for testing
                });
              },
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Battery',
                  '${batteryPercentage.toStringAsFixed(0)}%',
                  Icons.battery_full,
                ),
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

  Widget _buildMainMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2; // Account for gap
        final cardHeight =
            cardWidth * 1.0; // Square aspect ratio for more space

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: cardWidth / cardHeight,
          children: [
            _buildMetricCard(
              title: 'Heart Rate',
              value: heartRateValue?.toStringAsFixed(0) ?? '--',
              unit: 'BPM',
              icon: Icons.favorite,
              color: Colors.red,
              isAnimated: heartRateValue != null && heartRateValue! > 0,
            ),
            _buildMetricCard(
              title: 'Baseline HR',
              value: baselineHR?.toStringAsFixed(0) ?? '70',
              unit: 'BPM',
              icon: Icons.trending_flat,
              color: const Color(0xFF3AA772),
            ),
            _buildMetricCard(
              title: 'SpO₂',
              value: spo2Value?.toStringAsFixed(0) ?? '--',
              unit: '%',
              icon: Icons.air,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Temperature',
              value: bodyTempValue?.toStringAsFixed(1) ?? '--',
              unit: '°C',
              icon: Icons.thermostat,
              color: Colors.orange,
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

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _isMonitoringActive ? _stopIoTMonitoring : _startIoTMonitoring,
            icon: Icon(
              _isMonitoringActive ? Icons.stop : Icons.play_arrow,
            ),
            label: Text(
              _isMonitoringActive ? 'Stop Monitoring' : 'Start Monitoring',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isMonitoringActive ? Colors.red : const Color(0xFF3AA772),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
