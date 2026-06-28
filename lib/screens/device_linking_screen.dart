import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/wearable_device.dart';
import '../services/device_service.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Read-only "My Device" screen.
///
/// Devices are assigned to patients by an admin or a psychologist with
/// granted admin access -- this screen only ever reads and displays that
/// assignment. It must never write to wearable_devices; there is no
/// link/unlink/assign/release action anywhere here.
class DeviceLinkingScreen extends StatefulWidget {
  const DeviceLinkingScreen({Key? key}) : super(key: key);

  @override
  State<DeviceLinkingScreen> createState() => _DeviceLinkingScreenState();
}

class _DeviceLinkingScreenState extends State<DeviceLinkingScreen>
    with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();

  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();

    _deviceService.addListener(_onDeviceServiceUpdate);
    _loadAssignedDevice();
  }

  void _onDeviceServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAssignedDevice() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _deviceService.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking your assigned device: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _deviceService.removeListener(_onDeviceServiceUpdate);
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = _deviceService.linkedDevice;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Device',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAssignedDevice,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: _isLoading
                ? _buildLoadingView()
                : device != null
                    ? _buildAssignedDeviceView(device)
                    : _buildNoAssignmentView(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 20),
            Text(
              'Checking your assigned device...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// "Last updated" text shown whenever status isn't live.
  String? _getLastUpdatedText() {
    final status = _deviceService.connectionStatus;
    if (status == DeviceConnectionStatus.live) return null;

    final lastReading = _deviceService.lastReadingTime;
    if (lastReading == null) return null;

    final age = DateTime.now().difference(lastReading);
    final label = status == DeviceConnectionStatus.stale
        ? 'Last known reading'
        : 'No recent wearable data';

    if (age.inMinutes < 1) return '$label • just now';
    if (age.inMinutes < 60) return '$label • ${age.inMinutes}m ago';
    return '$label • ${age.inHours}h ago';
  }

  Widget _buildAssignedDeviceView(WearableDevice device) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final status = _deviceService.connectionStatus;
    final isLive = status == DeviceConnectionStatus.live;
    final statusColor = switch (status) {
      DeviceConnectionStatus.live => Colors.green,
      DeviceConnectionStatus.stale => Colors.orange,
      DeviceConnectionStatus.offline => Colors.grey,
    };
    final statusText = switch (status) {
      DeviceConnectionStatus.live => 'Your device is live',
      DeviceConnectionStatus.stale => 'Stale - reconnecting',
      DeviceConnectionStatus.offline => 'No recent wearable data',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          if (_errorMessage != null) _buildErrorMessage(),

          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [statusColor.shade400, statusColor.shade500],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLive ? Icons.check_circle : Icons.watch,
                    color: statusColor.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hello, ${user?.firstName ?? 'User'}! \u{1F44B}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_getLastUpdatedText() != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _getLastUpdatedText()!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices, color: statusColor.shade700, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        device.deviceName,
                        style: TextStyle(
                          color: statusColor.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == DeviceConnectionStatus.offline)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildOfflineMessage(device),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Device details (read-only)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Device ID', device.deviceId),
                _buildDetailRow(
                    'Battery',
                    device.batteryLevel != null
                        ? '${device.batteryLevel!.toStringAsFixed(0)}%'
                        : 'Unknown'),
                _buildDetailRow(
                    'Firmware', device.firmwareVersion ?? 'Unknown'),
                _buildDetailRow(
                    'Baseline HR',
                    device.baselineHR != null
                        ? '${device.baselineHR!.toStringAsFixed(0)} BPM'
                        : 'Not recorded yet'),
                _buildDetailRow(
                    'Last Seen', _formatDateTime(device.lastSeenAt)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Read-only troubleshooting help (not an action flow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Device showing offline? Try this',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildInstructionStep(
                    '1', 'Make sure your AnxieEase wearable is turned on'),
                const SizedBox(height: 10),
                _buildInstructionStep('2',
                    'Make sure it is connected to its usual "AnxieEase" WiFi hotspot'),
                const SizedBox(height: 10),
                _buildInstructionStep('3',
                    'If it still won\'t connect, contact your administrator or psychologist'),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Shown when there's been no recent wearable data at all (>5min old).
  Widget _buildOfflineMessage(WearableDevice device) {
    final lastBattery = device.batteryLevel;
    final lowBatteryWhileOffline =
        lastBattery != null && lastBattery < DeviceService.lowBatteryThreshold;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No recent wearable data. Please check if the device is '
            'charged, powered on, worn, and connected to WiFi.',
            style: TextStyle(
                color: Colors.grey.shade800, fontSize: 12, height: 1.3),
          ),
          if (lowBatteryWhileOffline) ...[
            const SizedBox(height: 8),
            Text(
              'Device may be low battery. Please charge the wearable.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
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
              number,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAssignmentView() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Hello, ${user?.firstName ?? 'User'}! \u{1F44B}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(Icons.watch, size: 80, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 30),
          if (_errorMessage != null) _buildErrorMessage(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No device assigned',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'No device assigned. Please contact your administrator/psychologist.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
