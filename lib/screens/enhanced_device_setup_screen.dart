import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/device_service.dart';
import '../services/multi_device_manager.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Simplified and user-friendly device setup screen
///
/// Features:
/// - Progressive disclosure of setup steps
/// - Visual feedback and animations
/// - Smart device detection
/// - Guided baseline setup
/// - Multiple device management
class EnhancedDeviceSetupScreen extends StatefulWidget {
  const EnhancedDeviceSetupScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedDeviceSetupScreen> createState() =>
      _EnhancedDeviceSetupScreenState();
}

class _EnhancedDeviceSetupScreenState extends State<EnhancedDeviceSetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _deviceIdController = TextEditingController();
  final DeviceService _deviceService = DeviceService();
  final MultiDeviceManager _multiDeviceManager = MultiDeviceManager();

  // Setup flow state
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Device detection state
  bool _isScanning = false;
  List<String> _detectedDevices = [];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  Future<void> _initializeServices() async {
    await _deviceService.initialize();
    await _multiDeviceManager.loadUserDevices();

    // If user has devices, show device manager instead
    if (_multiDeviceManager.userDevices.isNotEmpty) {
      setState(() {
        _currentStep = 4; // Go to device management step
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceIdController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Auto-detect nearby AnxieEase devices
  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _detectedDevices.clear();
    });

    _pulseController.repeat(reverse: true);

    try {
      // Simulate device scanning (in real implementation, scan Firebase for active devices)
      await Future.delayed(const Duration(seconds: 3));

      // Mock detected devices - in reality, query Firebase for devices with recent data
      _detectedDevices = ['AnxieEase001', 'AnxieEase002', 'AnxieEase003'];

      setState(() {
        _isScanning = false;
      });

      _pulseController.stop();

      if (_detectedDevices.isNotEmpty) {
        _showDetectedDevicesDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No AnxieEase devices detected nearby'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error scanning for devices: $e';
      });
      _pulseController.stop();
    }
  }

  void _showDetectedDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Devices Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select your AnxieEase device:'),
            const SizedBox(height: 16),
            ..._detectedDevices
                .map((deviceId) => ListTile(
                      leading:
                          const Icon(Icons.watch, color: AppTheme.primaryColor),
                      title: Text(deviceId),
                      subtitle: const Text('Ready to connect'),
                      onTap: () {
                        _deviceIdController.text = deviceId;
                        Navigator.pop(context);
                        _connectToDevice();
                      },
                    ))
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice() async {
    if (_deviceIdController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = _deviceIdController.text.trim();
      final success = await _deviceService.linkDevice(deviceId);

      if (success) {
        setState(() {
          _currentStep = 3; // Move to baseline setup
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Device Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomeStep(),
            _buildDeviceScanStep(),
            _buildManualEntryStep(),
            _buildBaselineSetupStep(),
            _buildDeviceManagementStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.watch,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Connect Your AnxieEase Device',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Let\'s get your wearable device connected and personalized for the best anxiety monitoring experience.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceScanStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isScanning ? _pulseAnimation.value : 1.0,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _isScanning
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: _isScanning
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _isScanning ? Icons.radar : Icons.search,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _isScanning ? 'Scanning for Devices...' : 'Find Your Device',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning
                ? 'Looking for AnxieEase devices nearby'
                : 'We\'ll automatically detect your device when it\'s ready',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _scanForDevices,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isScanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Scan for Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 2;
              });
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text('Enter Device ID Manually'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildManualEntryStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          const Icon(
            Icons.keyboard,
            size: 80,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 32),
          const Text(
            'Enter Device ID',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Find the device ID on your AnxieEase device (format: AnxieEaseXXX)',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _deviceIdController,
            decoration: InputDecoration(
              hintText: 'e.g., AnxieEase001',
              prefixIcon: const Icon(Icons.watch),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _connectToDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Connect Device',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBaselineSetupStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Device Connected!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Now let\'s set up your personal heart rate baseline for accurate anxiety detection.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 32),
                SizedBox(height: 12),
                Text(
                  'Your baseline helps us understand your normal heart rate, so we can accurately detect when you\'re experiencing anxiety.',
                  style: TextStyle(color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/baseline-recording');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Set Up Baseline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/health-dashboard');
            },
            child: const Text('Skip for now'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceManagementStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Devices',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Consumer<MultiDeviceManager>(
              builder: (context, multiDeviceManager, child) {
                final devices = multiDeviceManager.userDevices;

                if (devices.isEmpty) {
                  return const Center(
                    child: Text('No devices found'),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isPrimary = device.deviceId ==
                        multiDeviceManager.primaryDevice?.deviceId;
                    final thresholds =
                        multiDeviceManager.getThresholds(device.deviceId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.watch,
                            color:
                                isPrimary ? AppTheme.primaryColor : Colors.grey,
                          ),
                        ),
                        title: Text(device.deviceId),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPrimary)
                              const Text('Primary Device',
                                  style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold)),
                            if (device.baselineHR != null)
                              Text(
                                  'Baseline: ${device.baselineHR!.toStringAsFixed(0)} BPM'),
                            if (thresholds != null)
                              Text(
                                  'Thresholds: ${thresholds.mild.toStringAsFixed(0)}/${thresholds.moderate.toStringAsFixed(0)}/${thresholds.severe.toStringAsFixed(0)} BPM'),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            if (!isPrimary)
                              const PopupMenuItem(
                                value: 'primary',
                                child: Text('Set as Primary'),
                              ),
                            const PopupMenuItem(
                              value: 'baseline',
                              child: Text('Update Baseline'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove Device'),
                            ),
                          ],
                          onSelected: (value) async {
                            switch (value) {
                              case 'primary':
                                await multiDeviceManager
                                    .setPrimaryDevice(device.deviceId);
                                break;
                              case 'baseline':
                                Navigator.pushNamed(
                                    context, '/baseline-recording');
                                break;
                              case 'remove':
                                await multiDeviceManager
                                    .removeDevice(device.deviceId);
                                break;
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Add Another Device',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
