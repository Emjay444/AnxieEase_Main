import 'package:flutter/material.dart';
import 'dart:async';
import '../services/device_service.dart';
import '../services/admin_device_management_service.dart';
import '../models/health_metrics.dart';
import '../theme/app_theme.dart';
import '../config/baseline_config.dart';

/// Real-time health metrics dashboard
///
/// Displays live HR, baseline HR, temperature, SpO2, and movement data
/// with beautiful modern UI components and real-time updates.
class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen>
    with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _refreshTimer;
  bool _isInitialized = false;
  String? _errorMessage;

  // Device assignment checking
  bool _isCheckingAssignment = true;
  bool _hasDeviceAssignment = false;
  String? _assignmentError;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkDeviceAssignment();
  }

  Future<void> _checkDeviceAssignment() async {
    try {
      setState(() {
        _isCheckingAssignment = true;
        _assignmentError = null;
      });

      final adminDeviceService = AdminDeviceManagementService();
      final assignmentStatus = await adminDeviceService.checkDeviceAssignment();

      setState(() {
        _hasDeviceAssignment = assignmentStatus.isAssigned &&
            (assignmentStatus.status == 'assigned' ||
                assignmentStatus.status == 'active');
        _isCheckingAssignment = false;
      });

      if (_hasDeviceAssignment) {
        await _initializeService();
        _startPeriodicRefresh();
      }
    } catch (e) {
      setState(() {
        _hasDeviceAssignment = false;
        _isCheckingAssignment = false;
        _assignmentError = 'Failed to check device assignment: $e';
      });
    }
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
      await _deviceService.initialize();

      // Listen to device service changes
      _deviceService.addListener(_onDeviceServiceUpdate);

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

  void _onDeviceServiceUpdate() {
    if (mounted) {
      setState(() {});
      _updatePulseAnimation();
    }
  }

  void _updatePulseAnimation() {
    final metrics = _deviceService.currentMetrics;
    if (metrics != null &&
        metrics.heartRate != null &&
        metrics.heartRate! > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _refreshTimer?.cancel();
    _deviceService.removeListener(_onDeviceServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isCheckingAssignment
            ? _buildCheckingAssignmentView()
            : !_hasDeviceAssignment
                ? _buildNoDeviceAssignmentView()
                : _isInitialized
                    ? _buildDashboard()
                    : _buildLoadingView(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final device = _deviceService.linkedDevice;

    return AppBar(
      title: const Text(
        'Your Wearable',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      actions: [
        if (device != null)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        color: device.isActive ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.deviceId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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

    if (!_deviceService.hasLinkedDevice) {
      return _buildNoDeviceView();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly recalibration suggestion
            _buildRecalibrationBanner(),
            const SizedBox(height: 12),
            // Device status card
            _buildDeviceStatusCard(),
            const SizedBox(height: 20),

            // Main metrics grid
            _buildMainMetricsGrid(),
            const SizedBox(height: 20),

            // Heart rate section
            _buildHeartRateSection(),
            const SizedBox(height: 20),

            // Additional metrics
            _buildAdditionalMetrics(),
            const SizedBox(height: 20),

            // Health status summary
            _buildHealthStatusSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecalibrationBanner() {
    final device = _deviceService.linkedDevice;
    final metrics = _deviceService.currentMetrics;
    if (device == null || device.baselineHR == null)
      return const SizedBox.shrink();

    bool show = false;
    String message =
        'It’s been a week since your last baseline. Recalibrate for best accuracy.';

    // Suggest if baseline older than weeklyRefreshDays
    if (device.baselineUpdatedAt == null) {
      show = true;
    } else {
      final days = DateTime.now().difference(device.baselineUpdatedAt!).inDays;
      if (days >= BaselineConfig.weeklyRefreshDays) show = true;
    }

    // Also suggest if current resting HR while worn seems to drift > threshold
    if (!show &&
        metrics != null &&
        metrics.isWorn &&
        metrics.heartRate != null) {
      final drift = (metrics.heartRate! - device.baselineHR!).abs();
      if (drift >= BaselineConfig.driftThresholdBpm &&
          (metrics.movementLevel ?? 0) <=
              BaselineConfig.restfulMovementThreshold) {
        show = true;
        message =
            'Your resting HR changed by ≥${BaselineConfig.driftThresholdBpm} BPM. Consider recalibrating.';
      }
    }

    if (!show) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.refresh, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/baseline-recording');
            },
            child: const Text('Recalibrate'),
          )
        ],
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

  Widget _buildNoDeviceView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.watch_off,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Device Connected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please link a wearable device to view your health metrics.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text(
                'Link Device',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    final device = _deviceService.linkedDevice!;
    final metrics = _deviceService.currentMetrics;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.watch,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getConnectionStatusColor(metrics),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getConnectionStatusText(metrics),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Battery',
                  '${metrics?.batteryLevel?.toStringAsFixed(0) ?? '--'}%',
                  Icons.battery_full,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Worn',
                  metrics?.isWorn == true ? 'Yes' : 'No',
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
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMainMetricsGrid() {
    final metrics = _deviceService.currentMetrics;
    final device = _deviceService.linkedDevice;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          title: 'Heart Rate',
          value: metrics?.heartRate?.toStringAsFixed(0) ?? '--',
          unit: 'BPM',
          icon: Icons.favorite,
          color: Colors.red,
          isAnimated: metrics?.heartRate != null && metrics!.heartRate! > 0,
        ),
        _buildMetricCard(
          title: 'Baseline HR',
          value: device?.baselineHR?.toStringAsFixed(0) ?? '--',
          unit: 'BPM',
          icon: Icons.trending_flat,
          color: AppTheme.primaryColor,
        ),
        _buildMetricCard(
          title: 'SpO₂',
          value: metrics?.spo2?.toStringAsFixed(0) ?? '--',
          unit: '%',
          icon: Icons.air,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'Temperature',
          value: metrics?.bodyTemperature?.toStringAsFixed(1) ?? '--',
          unit: '°C',
          icon: Icons.thermostat,
          color: Colors.orange,
        ),
      ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
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
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
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
    final metrics = _deviceService.currentMetrics;
    final device = _deviceService.linkedDevice;

    if (metrics?.heartRate == null || device?.baselineHR == null) {
      return const SizedBox.shrink();
    }

    final hrStatus = metrics!.heartRateStatus;
    final difference = metrics.heartRate! - device!.baselineHR!;

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
              const Icon(Icons.analytics, color: AppTheme.primaryColor),
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
                      color: _getHeartRateStatusColor(hrStatus),
                    ),
                  ),
                ],
              ),
              _buildHeartRateStatusChip(hrStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalMetrics() {
    final metrics = _deviceService.currentMetrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryMetricCard(
                title: 'Movement',
                value: '${metrics?.movementLevel?.toStringAsFixed(0) ?? '--'}%',
                icon: Icons.directions_run,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryMetricCard(
                title: 'Ambient Temp',
                value:
                    '${metrics?.ambientTemperature?.toStringAsFixed(1) ?? '--'}°C',
                icon: Icons.wb_sunny,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusSummary() {
    final metrics = _deviceService.currentMetrics;

    if (metrics == null) return const SizedBox.shrink();

    final status = metrics.overallStatus;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getHealthStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getHealthStatusColor(status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getHealthStatusColor(status).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getHealthStatusIcon(status),
              color: _getHealthStatusColor(status),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHealthStatusText(status),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getHealthStatusColor(status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateStatusChip(HeartRateStatus status) {
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
        _getHeartRateStatusText(status),
        style: TextStyle(
          color: _getHeartRateStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    // Add a slight delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {});
    }
  }

  Color _getConnectionStatusColor(HealthMetrics? metrics) {
    if (metrics == null) return Colors.grey;
    if (!metrics.isConnected) return Colors.red;
    if (!metrics.isWorn) return Colors.orange;
    return Colors.green;
  }

  String _getConnectionStatusText(HealthMetrics? metrics) {
    if (metrics == null) return 'Unknown';
    if (!metrics.isConnected) return 'Disconnected';
    if (!metrics.isWorn) return 'Not Worn';
    return 'Active';
  }

  Color _getHeartRateStatusColor(HeartRateStatus status) {
    switch (status) {
      case HeartRateStatus.normal:
        return Colors.green;
      case HeartRateStatus.elevated:
        return Colors.orange;
      case HeartRateStatus.high:
      case HeartRateStatus.veryHigh:
        return Colors.red;
      case HeartRateStatus.low:
      case HeartRateStatus.veryLow:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getHeartRateStatusText(HeartRateStatus status) {
    switch (status) {
      case HeartRateStatus.normal:
        return 'Normal';
      case HeartRateStatus.elevated:
        return 'Elevated';
      case HeartRateStatus.high:
        return 'High';
      case HeartRateStatus.veryHigh:
        return 'Very High';
      case HeartRateStatus.low:
        return 'Low';
      case HeartRateStatus.veryLow:
        return 'Very Low';
      default:
        return 'Unknown';
    }
  }

  Color _getHealthStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Colors.green;
      case HealthStatus.good:
        return Colors.lightGreen;
      case HealthStatus.caution:
        return Colors.orange;
      case HealthStatus.alert:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getHealthStatusIcon(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Icons.favorite;
      case HealthStatus.good:
        return Icons.thumb_up;
      case HealthStatus.caution:
        return Icons.warning;
      case HealthStatus.alert:
        return Icons.priority_high;
      default:
        return Icons.help_outline;
    }
  }

  String _getHealthStatusText(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.caution:
        return 'Monitor';
      case HealthStatus.alert:
        return 'Alert';
      default:
        return 'Unknown';
    }
  }

  Widget _buildCheckingAssignmentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'Checking Device Assignment...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we verify your device access.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceAssignmentView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dashboard_outlined,
                size: 64,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Device Assigned',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You need to have a wearable device assigned by an administrator to access your wearable dashboard.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_assignmentError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _assignmentError!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _checkDeviceAssignment(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Check Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
