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
  bool isDeviceWorn = false;
  late NotificationService _notificationService;

  // IoT Sensor Data - Current readings
  double? spo2Value;
  double? bodyTempValue;
  double? ambientTempValue;
  double? heartRateValue;
  double batteryPercentage = 85.0;
  bool isConnected = false;
  bool _hasRealtimeData = false;

  // Connection states: 'disconnected', 'connecting', 'connected', 'no_connection'
  String _connectionState = 'disconnected';

  // Firebase references and listeners
  StreamSubscription? _iotDataSubscription;
  late DatabaseReference _currentDataRef;

  // IoT Sensor Service
  late IoTSensorService _iotSensorService;

  // Monitoring state
  bool _isMonitoringActive = false;

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

    // Get services from Provider
    _notificationService =
        Provider.of<NotificationService>(context, listen: false);
    _iotSensorService = Provider.of<IoTSensorService>(context, listen: false);

    // Listen to IoT Sensor Service changes
    _iotSensorService.addListener(_onIoTSensorChanged);

    // Initialize IoT service
    _initializeIoTService();

    // Heartbeat animation controller (speed adapts to BPM)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _controller.repeat(reverse: true);

    // Initialize Firebase references
    _currentDataRef =
        FirebaseDatabase.instance.ref().child('devices/AnxieEase001/current');

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
              isDeviceWorn =
                  wornParsed; // Always use actual worn state from Firebase
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
              _showSuccess('Monitoring active - Firebase data connected!');
            }

            debugPrint(
                '📊 Wearable: Updated IoT data - HR: $heartRateValue, SpO2: $spo2Value, Battery: $batteryPercentage, Worn: $isDeviceWorn');
          });
          // Update pulse speed based on latest values
          _updateHeartbeatAnimation();
        } catch (e) {
          debugPrint('Error parsing IoT data: $e');
        }
      }
    });

    // Listen to NotificationService changes for heart rate updates
    _notificationService.addListener(_updateUI);
  }

  // Update the heartbeat animation speed based on current BPM and state
  void _updateHeartbeatAnimation() {
    final worn = isDeviceWorn;
    final connected = isConnected;
    final hr = (heartRateValue ?? 0).toDouble();

    if (!connected || !worn || hr <= 0) {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.value = 0.0;
      }
      return;
    }

    // Compute cycle duration: one full beat per heartbeat; clamp for UX
    final bpm = hr.clamp(40, 160);
    final cycleMs = (60000 / bpm).clamp(350, 1200).toInt();
    final halfCycle = Duration(milliseconds: cycleMs ~/ 2);

    if (_controller.duration != halfCycle) {
      _controller.duration = halfCycle;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  /// Initialize IoT Sensor Service
  Future<void> _initializeIoTService() async {
    debugPrint('🔧 Wearable: Initializing IoT Sensor Service...');

    try {
      await _iotSensorService.initialize();
      // Ensure initial animation reflects current state
      _updateHeartbeatAnimation();

      // Update monitoring state
      setState(() {
        _isMonitoringActive = _iotSensorService.isActive;
        isConnected = _iotSensorService.isConnected;
        if (!isConnected) {
          _hasRealtimeData = false;
        }
      });

      debugPrint('✅ Wearable: IoT Sensor Service initialized');
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
    _updateHeartbeatAnimation();
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
    debugPrint('🚀 Wearable: Starting IoT monitoring...');

    try {
      setState(() {
        _hasRealtimeData = false; // reset until first RTDB event arrives
        _connectionState = 'connecting'; // show connecting state immediately
        _isMonitoringActive = true; // set monitoring active immediately
      });
      await _iotSensorService.startSensors();
      debugPrint('🚀 Wearable: IoT monitoring started successfully');

      // Start validation timer to check if Firebase data arrives
      _startFirebaseValidation();
    } catch (e) {
      debugPrint('❌ Wearable: Error starting IoT monitoring: $e');
      setState(() {
        _connectionState = 'disconnected';
      });
      _showError('Failed to start IoT monitoring: $e');
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
        _showWarning(
            'Monitoring started but no Firebase data detected. Check connection.');
      } else if (_hasRealtimeData) {
        // Firebase data flowing - show connected state
        setState(() {
          _connectionState = 'connected';
        });
        _showSuccess('Monitoring active - Firebase data connected!');
      }
    });
  }

  /// Stop IoT sensor monitoring
  Future<void> _stopIoTMonitoring() async {
    debugPrint('🛑 Wearable: Stopping IoT monitoring...');

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

      debugPrint('🛑 Wearable: IoT monitoring stopped successfully');

      _showSuccess('IoT monitoring stopped');
    } catch (e) {
      debugPrint('❌ Wearable: Error stopping IoT monitoring: $e');
      setState(() {
        _connectionState = 'disconnected';
        _isMonitoringActive = false;
      });
      _showError('Failed to stop IoT monitoring: $e');
    }
  }

  // Simulate stress event method removed per user request

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

  // History features removed per request

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

  void _showWarning(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _iotDataSubscription?.cancel();
    _firebaseValidationTimer?.cancel();
    _notificationService.removeListener(_updateUI);
    _iotSensorService.removeListener(_onIoTSensorChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable'),
        centerTitle: true,
      ),
      body: _buildLiveDataTab(),
    );
  }

  /// Build the live data tab with current sensor readings
  Widget _buildLiveDataTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.shade50,
            Colors.white,
            Colors.teal.shade50,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEnhancedTopStatus(),
                  const SizedBox(height: 12),
                  _buildResponsiveHeartDialSection(constraints),
                  const SizedBox(height: 12),
                  _buildEnhancedStatsGrid(context),
                  const SizedBox(height: 12),
                  _buildEnhancedControlsBar(context),
                  const SizedBox(height: 16),
                  _buildEnhancedDeviceStatus(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Ensure the heart dial is sized responsively to avoid vertical overflow
  Widget _buildResponsiveHeartDialSection(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    // Choose a size that fits on small screens but looks great on larger ones
    double size = width * 0.9; // 90% of width
    if (size > 340) size = 340; // slightly smaller max to free vertical space
    if (size < 200) size = 200; // allow a bit smaller on tiny screens

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: _buildEnhancedHeartDial(context),
      ),
    );
  }

  // History tab removed per request

  // Removed legacy _buildTopStatus (superseded by _buildEnhancedTopStatus)

  /// Enhanced top status with modern design and animations
  Widget _buildEnhancedTopStatus() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.teal.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Connection Status
          Expanded(
            child: _buildEnhancedStatusCard(
              icon: _getConnectionIcon(),
              label: _getConnectionLabel(),
              color: _getConnectionColor(),
              isActive: _connectionState != 'disconnected',
            ),
          ),
          const SizedBox(width: 12),
          // Worn Status
          Expanded(
            child: _buildEnhancedStatusCard(
              icon: isDeviceWorn ? Icons.watch : Icons.watch_off,
              label: isDeviceWorn ? 'Worn' : 'Not Worn',
              color: isDeviceWorn ? Colors.blue : Colors.grey,
              isActive: isDeviceWorn,
            ),
          ),
          // Battery card removed (redundant with stats below)
        ],
      ),
    );
  }

  /// Enhanced status card widget
  Widget _buildEnhancedStatusCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [color.withOpacity(0.1), color.withOpacity(0.05)]
              : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isActive ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? color : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.grey[800] : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Battery top card removed as redundant

  /// Enhanced heart rate dial with pulse animation and zone indicators
  Widget _buildEnhancedHeartDial(BuildContext context) {
    final connected = _connectionState == 'connected';
    final worn = isDeviceWorn;
    final hr =
        (connected && worn && _hasRealtimeData) ? (heartRateValue ?? 0) : 0;
    final display =
        (connected && worn && _hasRealtimeData && heartRateValue != null)
            ? heartRateValue!.round().toString()
            : '--';
    final color = (connected && worn && _hasRealtimeData)
        ? _hrColor(hr.toDouble())
        : Colors.grey;
    final normalized = (hr.clamp(40, 160) - 40) / (160 - 40);

    // Heart rate zones based on connection state
    final zone = _connectionState == 'disconnected'
        ? 'Disconnected'
        : _connectionState == 'connecting'
            ? 'Connecting'
            : _connectionState == 'no_connection'
                ? 'No Connection'
                : !_hasRealtimeData
                    ? 'No Data Yet'
                    : !worn
                        ? 'Not Worn'
                        : hr <= 60
                            ? 'Resting'
                            : hr <= 85
                                ? 'Normal'
                                : hr <= 120
                                    ? 'Elevated'
                                    : 'High';

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final size = c.maxWidth * 0.8;
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring with pulse animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pulseScale = 1.0 + (_controller.value * 0.06);
                    return Transform.scale(
                      scale: (connected && worn && _hasRealtimeData && hr > 0)
                          ? pulseScale
                          : 1.0,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: normalized.toDouble()),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                            value: value.isNaN ? 0 : value,
                            strokeWidth: 16,
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Inner content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing heart icon
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final heartScale = 1.0 + (_controller.value * 0.12);
                        return Transform.scale(
                          scale:
                              (connected && worn && _hasRealtimeData && hr > 0)
                                  ? heartScale
                                  : 1.0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: color,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Heart rate value (beats with the heart)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final beatScale = 1.0 + (_controller.value * 0.06);
                        return Transform.scale(
                          scale:
                              (connected && worn && _hasRealtimeData && hr > 0)
                                  ? beatScale
                                  : 1.0,
                          child: Text(
                            display,
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 48,
                                ),
                          ),
                        );
                      },
                    ),
                    // BPM label
                    Text(
                      'BPM',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Heart rate zone
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        zone,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Enhanced stats grid with modern card design
  Widget _buildEnhancedStatsGrid(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width - 32; // account for page padding
    final itemWidth = (width - (12 * 2)) / 3; // two gaps between three columns
    // Height tuned to fit icon, value, label comfortably on small devices
    final mainExtent = (itemWidth * 1.35).clamp(124.0, 160.0);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: mainExtent,
      ),
      children: [
        _buildEnhancedStatCard(
          label: 'SpO2',
          value: (isConnected &&
                  _hasRealtimeData &&
                  isDeviceWorn &&
                  spo2Value != null &&
                  spo2Value! > 0)
              ? '${spo2Value!.round()}%'
              : '--',
          icon: Icons.air,
          color: (isConnected && _hasRealtimeData && isDeviceWorn)
              ? Colors.blue
              : Colors.grey,
          active: (isConnected && _hasRealtimeData && isDeviceWorn),
        ),
        _buildEnhancedStatCard(
          label: 'Body Temp',
          value: (isConnected &&
                  _hasRealtimeData &&
                  isDeviceWorn &&
                  bodyTempValue != null &&
                  bodyTempValue! > 0)
              ? '${bodyTempValue!.toStringAsFixed(1)}°C'
              : '--',
          icon: Icons.thermostat,
          color: (isConnected && _hasRealtimeData && isDeviceWorn)
              ? Colors.orange
              : Colors.grey,
          active: (isConnected && _hasRealtimeData && isDeviceWorn),
        ),
        _buildEnhancedStatCard(
          label: 'Battery',
          value: (isConnected && _hasRealtimeData && isDeviceWorn)
              ? '${batteryPercentage.round()}%'
              : '--',
          icon: Icons.battery_full,
          color: (isConnected && _hasRealtimeData && isDeviceWorn)
              ? Colors.green
              : Colors.grey,
          active: (isConnected && _hasRealtimeData && isDeviceWorn),
        ),
      ],
    );
  }

  /// Enhanced stat card with gradient and animations
  Widget _buildEnhancedStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? [Colors.white, color.withOpacity(0.05)]
              : [Colors.grey[50]!, Colors.grey[100]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container with background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: active
                      ? [color.withOpacity(0.2), color.withOpacity(0.1)]
                      : [
                          Colors.grey.withOpacity(0.2),
                          Colors.grey.withOpacity(0.1)
                        ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: active ? color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            // Value
            Text(
              value,
              style: TextStyle(
                color: active ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.grey[700] : Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Enhanced controls bar with modern button design
  Widget _buildEnhancedControlsBar(BuildContext context) {
    return Row(
      children: [
        // Primary action button (Start/Stop)
        Expanded(
          flex: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isMonitoringActive
                  ? _stopIoTMonitoring
                  : _startIoTMonitoring,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMonitoringActive ? Icons.stop : Icons.play_arrow,
                  size: 20,
                ),
              ),
              label: Text(
                _isMonitoringActive ? 'Stop Monitoring' : 'Start Monitoring',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoringActive ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
                elevation: _isMonitoringActive ? 8 : 4,
                shadowColor: (_isMonitoringActive ? Colors.red : Colors.teal)
                    .withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),
        // Simulator button removed per user request
      ],
    );
  }

  /// Enhanced device status with modern design and real-time indicators
  Widget _buildEnhancedDeviceStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.devices,
                  color: Colors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Device Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEnhancedStatusRow(
            'Device ID',
            _iotSensorService.deviceId,
            Icons.fingerprint,
            Colors.blue,
          ),
          _buildEnhancedStatusRow(
            'Connection',
            isConnected ? 'Connected' : 'Disconnected',
            isConnected ? Icons.wifi : Icons.wifi_off,
            isConnected ? Colors.green : Colors.red,
          ),
          _buildEnhancedStatusRow(
            'Monitoring',
            _isMonitoringActive ? 'Active' : 'Inactive',
            _isMonitoringActive
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            _isMonitoringActive ? Colors.green : Colors.grey,
          ),
          _buildEnhancedStatusRow(
            'Device Worn',
            isDeviceWorn ? 'Yes' : 'No',
            isDeviceWorn ? Icons.check_circle : Icons.cancel,
            isDeviceWorn ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  /// Enhanced status row with icon and color indicators
  Widget _buildEnhancedStatusRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hrColor(double hr) {
    if (!isDeviceWorn) return Colors.grey;
    if (hr >= 120) return Colors.red;
    if (hr >= 100) return Colors.orange;
    if (hr >= 85) return Colors.amber;
    return Colors.green;
  }

  // Removed legacy _buildHeartDial (superseded by _buildEnhancedHeartDial)

  // Removed legacy _buildMiniStatsRow (superseded by _buildEnhancedStatsGrid)

  // Removed legacy _buildMiniStat (replaced by enhanced stat cards)

  // Removed legacy _buildControlsBar (superseded by _buildEnhancedControlsBar)

  // Removed legacy _buildDeviceStatus (superseded by _buildEnhancedDeviceStatus)

  // Removed legacy _buildStatusRow (replaced by _buildEnhancedStatusRow)
}
