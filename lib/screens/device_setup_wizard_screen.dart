import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/device_service.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'baseline_recording_screen.dart';

/// Comprehensive device setup wizard that guides users through the entire process
///
/// Steps:
/// 1. WiFi Hotspot Setup Instructions
/// 2. Device Connection Verification
/// 3. Device ID Linking
/// 4. Success/Baseline Setup
class DeviceSetupWizardScreen extends StatefulWidget {
  const DeviceSetupWizardScreen({Key? key}) : super(key: key);

  @override
  State<DeviceSetupWizardScreen> createState() =>
      _DeviceSetupWizardScreenState();
}

class _DeviceSetupWizardScreenState extends State<DeviceSetupWizardScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _deviceIdController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DeviceService _deviceService = DeviceService();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Step completion status
  List<bool> _stepCompleted = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _initializeService() async {
    try {
      await _deviceService.initialize();

      // Check if user already has a linked device
      if (_deviceService.hasLinkedDevice) {
        _showAlreadyLinkedDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize device service: $e';
      });
    }
  }

  void _showAlreadyLinkedDialog() {
    final device = _deviceService.linkedDevice!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Device Already Linked'),
        content: Text(
          'You already have a device linked: ${device.deviceId}\n\n'
          'Would you like to continue with this device or set up a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Keep Current'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Continue with setup wizard to replace device
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child:
                const Text('Setup New', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceIdController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _stepCompleted[_currentStep] = true;
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _testDeviceConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = _deviceIdController.text.trim();

      // Import Firebase Database directly for testing
      final database = FirebaseDatabase.instance;
      final deviceRef = database.ref('devices/$deviceId');
      final snapshot = await deviceRef.once();

      if (snapshot.snapshot.exists) {
        // Check if device has current data
        final currentRef = deviceRef.child('current');
        final currentSnapshot = await currentRef.once();

        if (currentSnapshot.snapshot.exists) {
          final data =
              Map<String, dynamic>.from(currentSnapshot.snapshot.value as Map);

          // Check if data is recent (within last 60 seconds for setup)
          final timestamp = data['timestamp'] as int?;
          if (timestamp != null) {
            final dataTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final timeDifference = DateTime.now().difference(dataTime);

            if (timeDifference.inSeconds > 60) {
              throw Exception(
                  'Device found but data is stale (${timeDifference.inMinutes} minutes old).\n\n'
                  'Please ensure:\n'
                  '• Device is ON and connected to WiFi\n'
                  '• Hotspot is active and named "AnxieEase"\n'
                  '• Device is connected and sending data');
            }
          }

          setState(() {
            _stepCompleted[2] = true;
          });
          _nextStep();
        } else {
          throw Exception('Device found but not sending data.\n\n'
              'Please check:\n'
              '• Device is connected to "AnxieEase" hotspot\n'
              '• Hotspot password is "11112222"\n'
              '• Device is connected and sending data');
        }
      } else {
        throw Exception('Device not found in system.\n\n'
            'Please verify:\n'
            '• Device ID is correct (format: AnxieEaseXXX)\n'
            '• Device is turned ON\n'
            '• Device is connected to your AnxieEase hotspot\n'
            '• Wait 30 seconds after connecting to hotspot');
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

  Future<void> _linkDevice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = _deviceIdController.text.trim();
      final success = await _deviceService.linkDevice(deviceId);

      if (success && mounted) {
        setState(() {
          _stepCompleted[3] = true;
        });

        // Show success and navigate to baseline recording
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Device $deviceId linked successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const BaselineRecordingScreen(),
            ),
          );
        }
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Device Setup Wizard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable swipe
                  children: [
                    _buildWelcomeStep(user?.firstName ?? 'User'),
                    _buildWiFiSetupStep(),
                    _buildDeviceTestStep(),
                    _buildLinkingStep(),
                  ],
                ),
              ),

              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.primaryColor,
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = _stepCompleted[index];
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomeStep(String firstName) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
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
            ),
            child: const Icon(
              Icons.watch,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome, $firstName! 👋',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s set up your AnxieEase wearable device in a few simple steps.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildFeatureList(),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {'icon': Icons.wifi, 'text': 'Connect device to WiFi'},
      {'icon': Icons.link, 'text': 'Link device to your account'},
      {'icon': Icons.favorite, 'text': 'Set up health monitoring'},
      {'icon': Icons.dashboard, 'text': 'Start tracking wellness'},
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                feature['text'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWiFiSetupStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.blue.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.wifi,
              size: 60,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'WiFi Hotspot Setup',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Follow these steps to connect your device:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          _buildWiFiInstructions(),
        ],
      ),
    );
  }

  Widget _buildWiFiInstructions() {
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
        children: [
          _buildWiFiStep(
            '1',
            'Turn ON your AnxieEase wearable device',
            Icons.power_settings_new,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildWiFiStep(
            '2',
            'Go to Settings > Mobile Hotspot on your phone',
            Icons.phone_android,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildWiFiStep(
            '3',
            'Set hotspot name to "AnxieEase"',
            Icons.wifi_tethering,
            Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildWiFiStep(
            '4',
            'Set password to "11112222"',
            Icons.lock,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildWiFiStep(
            '5',
            'Turn on Mobile Hotspot',
            Icons.wifi,
            Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildWiFiStep(
            '6',
            'Wait for device to connect and send data',
            Icons.bluetooth_connected,
            Colors.indigo,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates,
                    color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Keep your phone hotspot on during the setup process!',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiStep(
      String number, String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: color),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTestStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.search,
              size: 60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Find Your Device',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter your Device ID to test the connection:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          _buildDeviceIdForm(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkingStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Ready to Link!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your device is connected and ready to be linked to your account.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
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
              children: [
                Row(
                  children: [
                    const Icon(Icons.devices, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'Device ID: ${_deviceIdController.text}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Device connected to WiFi'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Data streaming to Firebase'),
                  ],
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceIdForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device ID',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _deviceIdController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'AnxieEase001',
              prefixIcon:
                  const Icon(Icons.qr_code, color: AppTheme.primaryColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your device ID';
              }

              final deviceId = value.trim();
              if (!RegExp(r'^AnxieEase[A-Z0-9]{3}$', caseSensitive: false)
                  .hasMatch(deviceId)) {
                return 'Invalid format. Use: AnxieEaseXXX (e.g., AnxieEase001)';
              }

              return null;
            },
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Find the Device ID on the sticker on the back of your device',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
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
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getNextButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getNextButtonText(),
                      style: const TextStyle(
                        fontSize: 16,
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

  VoidCallback? _getNextButtonAction() {
    switch (_currentStep) {
      case 0:
        return _nextStep;
      case 1:
        return _nextStep;
      case 2:
        return _testDeviceConnection;
      case 3:
        return _linkDevice;
      default:
        return null;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Get Started';
      case 1:
        return 'WiFi Setup Done';
      case 2:
        return 'Test Connection';
      case 3:
        return 'Link Device';
      default:
        return 'Next';
    }
  }
}
