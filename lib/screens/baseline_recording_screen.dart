import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/device_service.dart';
import '../services/admin_device_management_service.dart';
import '../models/baseline_heart_rate.dart';
import '../theme/app_theme.dart';
import 'health_dashboard_screen.dart';
import '../config/baseline_config.dart';

/// Guided resting heart rate recording screen
///
/// Provides a beautiful 3-5 minute guided session to collect baseline HR.
/// Features countdown timer, real-time HR display, and quality feedback.
class BaselineRecordingScreen extends StatefulWidget {
  const BaselineRecordingScreen({Key? key}) : super(key: key);

  @override
  State<BaselineRecordingScreen> createState() =>
      _BaselineRecordingScreenState();
}

class _BaselineRecordingScreenState extends State<BaselineRecordingScreen>
    with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();

  bool _isRecording = false;
  bool _isComplete = false;
  bool _isFinishing =
      false; // when timer hits 0 or stop pressed while finishing
  int _selectedDuration = BaselineConfig.defaultMinutes; // Fixed to config
  String? _errorMessage;
  BaselineHeartRate? _result;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late AnimationController _chartController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Stream subscriptions
  StreamSubscription<int>? _countdownSubscription;
  StreamSubscription<double>? _heartRateSubscription;

  // Real-time data
  int _remainingSeconds = 0;
  double _currentHeartRate = 0;
  List<double> _heartRateHistory = [];

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

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
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

      if (!_deviceService.hasLinkedDevice) {
        Navigator.pop(context);
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    _chartController.dispose();
    _countdownSubscription?.cancel();
    _heartRateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    // Prevent duplicate listeners if retrying
    await _countdownSubscription?.cancel();
    _countdownSubscription = null;
    await _heartRateSubscription?.cancel();
    _heartRateSubscription = null;

    setState(() {
      _isRecording = true;
      _isComplete = false;
      _errorMessage = null;
      _heartRateHistory.clear();
      _remainingSeconds = _selectedDuration * 60;
    });

    // Start pulse animation
    _pulseController.repeat(reverse: true);
    _progressController.forward();

    try {
      // Ensure streams exist before subscribing
      _deviceService.prepareBaselineStreams();

      // Set up stream subscriptions
      print('BaselineScreen: Setting up stream subscriptions');
      print(
          'BaselineScreen: Countdown stream available: ${_deviceService.countdownStream != null}');
      print(
          'BaselineScreen: HeartRate stream available: ${_deviceService.heartRateStream != null}');

      _countdownSubscription = _deviceService.countdownStream?.listen(
        (seconds) {
          print('BaselineScreen: Countdown received: ${seconds}s');
          setState(() {
            _remainingSeconds = seconds;
          });
        },
      );

      _heartRateSubscription = _deviceService.heartRateStream?.listen(
        (heartRate) {
          print('BaselineScreen: HeartRate received: ${heartRate} BPM');
          setState(() {
            _currentHeartRate = heartRate;
            _heartRateHistory.add(heartRate);

            // Keep only last 30 readings for display
            if (_heartRateHistory.length > 30) {
              _heartRateHistory.removeAt(0);
            }
          });

          // Animate the chart for each new sample
          if (mounted) {
            _chartController.forward(from: 0);
          }
        },
      );

      // Start recording
      final baseline = await _deviceService.recordRestingHeartRate(
        durationMinutes: _selectedDuration,
        notes: 'Recorded via AnxieEase app',
      );

      setState(() {
        _result = baseline;
        _isComplete = true;
        _isRecording = false;
        _isFinishing = false;
      });

      _pulseController.stop();
      if (_result != null) {
        _showCompletionAnimation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRecording = false;
        _isFinishing = false;
      });
      _pulseController.stop();

      // Show error dialog with friendly message
      _showInsufficientDataDialog(_friendlyErrorMessage(e));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      // If auto-finished already, try to show completion using last baseline
      final existing = _deviceService.currentBaseline;
      if (existing != null && mounted) {
        setState(() {
          _result = existing;
          _isComplete = true;
          _isRecording = false;
          _isFinishing = false;
        });
        _showCompletionAnimation();
      }
      return;
    }

    try {
      setState(() {
        _isFinishing = true;
      });

      final baseline = await _deviceService.stopBaselineRecording();

      setState(() {
        _result = baseline;
        _isComplete = baseline != null;
        _isRecording = false;
        _isFinishing = false;
      });

      _pulseController.stop();

      if (baseline != null) {
        _showCompletionAnimation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRecording = false;
        _isFinishing = false;
      });
      _pulseController.stop();

      // Show error dialog with friendly message
      _showInsufficientDataDialog(_friendlyErrorMessage(e));
    }
  }

  void _showCompletionAnimation() {
    // Haptic feedback for completion
    HapticFeedback.mediumImpact();

    // Show success animation
    if (!mounted || _result == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCompletionDialog(),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    if (!_isRecording) return 0.0;
    final totalSeconds = _selectedDuration * 60;
    return 1.0 - (_remainingSeconds / totalSeconds);
  }

  String _friendlyErrorMessage(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('baseline_aborted')) {
      return 'Session ended. Your baseline recording was canceled. You can try again when you’re ready.';
    }
    if (raw.contains('not enough data') || raw.contains('insufficient')) {
      return 'Not enough data to compute your heart rate. Please make sure the device is worn properly and remain still during recording.';
    }
    if (raw.contains('too short')) {
      return 'The session was too short to compute a baseline. Please complete the 5-minute recording.';
    }
    return e.toString();
  }

  String _friendlyErrorTitle(String message) {
    final m = message.toLowerCase();
    if (m.contains('canceled') || m.contains('ended'))
      return 'Session Canceled';
    if (m.contains('not enough data') || m.contains('insufficient'))
      return 'Recording Incomplete';
    if (m.contains('too short')) return 'Recording Too Short';
    return 'Recording Incomplete';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Resting Heart Rate Setup',
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isCheckingAssignment
                  ? _buildCheckingAssignmentView()
                  : !_hasDeviceAssignment
                      ? _buildNoDeviceAssignmentView()
                      : _isComplete
                          ? _buildCompletionView()
                          : _isRecording
                              ? _buildRecordingView()
                              : _buildPreparationView(),
            ),
          ),
        ),
      ),
    );
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
              Icons.watch_off,
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
            'You need to have a wearable device assigned by an administrator to record your baseline heart rate.',
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
    );
  }

  Widget _buildPreparationView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Header
                _buildHeader(),
                const SizedBox(height: 40),

                // Device status
                _buildDeviceStatus(),
                const SizedBox(height: 40),

                // Fixed duration info
                _buildFixedDurationCard(),
                const SizedBox(height: 40),

                // Instructions
                _buildInstructions(),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  _buildErrorMessage(),
                ],
              ],
            ),
          ),
        ),

        // Start button
        _buildStartButton(),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              const SizedBox(height: 40),

              // Heart rate display
              _buildHeartRateDisplay(),
              const SizedBox(height: 40),

              // Timer
              _buildTimer(),
              const SizedBox(height: 40),

              // Heart rate chart
              _buildHeartRateChart(),
            ],
          ),
        ),

        // Stop button
        _buildStopButton(),
      ],
    );
  }

  Widget _buildCompletionView() {
    // Fallback to service baseline in case of race
    _result ??= DeviceService().currentBaseline;
    if (_result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Finalizing your baseline…'),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.withOpacity(0.1),
                Colors.green.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.withOpacity(0.2), width: 2),
          ),
          child: const Icon(
            Icons.check_circle,
            size: 60,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 30),

        // Title
        const Text(
          'Baseline Set Successfully! 🎉',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Result summary
        _buildResultSummary(),
        const SizedBox(height: 40),

        // Guidance based on quality
        if (_result != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'Tips',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _result!.recordingQuality == RecordingQuality.excellent ||
                          _result!.recordingQuality == RecordingQuality.good
                      ? 'Great baseline! You’re all set. Recalibrate weekly or if your routine changes.'
                      : 'Baseline captured, but quality could improve. Consider another 5-minute session when you’re fully at rest.',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Continue button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HealthDashboardScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue to Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Let\'s establish your baseline',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll record your resting heart rate for accurate health monitoring.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    final device = _deviceService.linkedDevice;

    // Show default device info even if no device is formally linked
    final deviceId = device?.deviceId ?? 'AnxieEase001';

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.watch,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              deviceId,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedDurationCard() {
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: BaselineConfig.defaultMinutes));
    final etaTime = TimeOfDay.fromDateTime(eta).format(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.06),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recording Duration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.timer_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${BaselineConfig.defaultMinutes} minutes',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 6),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.10),
                          side: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.20),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-finish • Hands-free • Best accuracy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Est. completion: $etaTime',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A single 5-minute session is recommended for best accuracy.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Sit comfortably and relax\n'
            '• Ensure your device is properly worn\n'
            '• Avoid movement during recording\n'
            '• Breathe normally and stay calm',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: CircularProgressIndicator(
            value: _getProgress(),
            strokeWidth: 8,
            backgroundColor: Colors.grey[200],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        Column(
          children: [
            Text(
              '${(_getProgress() * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const Text(
              'Complete',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeartRateDisplay() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.red.withOpacity(0.1),
              Colors.red.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _currentHeartRate > 0
                  ? _currentHeartRate.toStringAsFixed(0)
                  : '--',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Text(
              'BPM',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Column(
      children: [
        Text(
          _formatTime(_remainingSeconds),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const Text(
          'Remaining',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateChart() {
    if (_heartRateHistory.isEmpty) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Collecting heart rate data...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _chartController,
        builder: (_, __) => CustomPaint(
          size: const Size.fromHeight(48),
          painter: HeartRateChartPainter(
            _heartRateHistory,
            progress: _chartController.value,
          ),
        ),
      ),
    );
  }

  Widget _buildResultSummary() {
    if (_result == null) return const SizedBox.shrink();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Baseline Heart Rate:'),
              Text(
                '${_result!.baselineHR.toStringAsFixed(1)} BPM',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recording Quality:'),
              _buildQualityChip(_result!.recordingQuality),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duration:'),
              Text(
                  '${_result!.recordingDurationMinutes.toStringAsFixed(1)} min'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip(RecordingQuality quality) {
    Color color;
    String text;

    switch (quality) {
      case RecordingQuality.excellent:
        color = Colors.green;
        text = 'Excellent';
        break;
      case RecordingQuality.good:
        color = Colors.green;
        text = 'Good';
        break;
      case RecordingQuality.fair:
        color = Colors.orange;
        text = 'Fair';
        break;
      case RecordingQuality.unstable:
        color = Colors.red;
        text = 'Unstable';
        break;
      case RecordingQuality.insufficientData:
        color = Colors.red;
        text = 'Insufficient Data';
        break;
      case RecordingQuality.tooShort:
        color = Colors.red;
        text = 'Too Short';
        break;
    }

    return Chip(
      label: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
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
          Icon(Icons.error_outline, color: Colors.red[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRecording ? null : _startRecording,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Start Recording',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            (_remainingSeconds <= 0 || _isFinishing) ? null : _stopRecording,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_remainingSeconds <= 0 || _isFinishing) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Finishing…',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              const Icon(Icons.stop, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Stop Recording',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Baseline Recorded!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your resting heart rate: ${_result?.baselineHR.toStringAsFixed(1)} BPM',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Continue',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showInsufficientDataDialog(String errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _friendlyErrorTitle(errorMessage),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          // Cancel button: abort any ongoing recording and return to preparation UI
          OutlinedButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop(); // Close dialog
              await _deviceService.abortBaselineRecording();
              if (!mounted) return;
              setState(() {
                _errorMessage = null;
                _isRecording = false;
                _isFinishing = false;
                _isComplete = false;
                _heartRateHistory.clear();
                _remainingSeconds = 0;
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          // Try Again button: just dismiss the dialog and keep user on the selection UI
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop(); // Close dialog
              await _deviceService.abortBaselineRecording();
              if (!mounted) return;
              setState(() {
                _errorMessage = null;
                _isRecording = false;
                _isFinishing = false;
                _isComplete = false;
                _heartRateHistory.clear();
                _remainingSeconds = 0;
              });
              // Immediately retry recording
              await Future.delayed(const Duration(milliseconds: 150));
              if (mounted) {
                _startRecording();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_isRecording || _isFinishing) {
      final shouldLeave = await _showLeaveSessionDialog();
      if (shouldLeave == true) {
        try {
          await _deviceService.abortBaselineRecording();
        } catch (_) {}
        _pulseController.stop();
        await _countdownSubscription?.cancel();
        await _heartRateSubscription?.cancel();
        _countdownSubscription = null;
        _heartRateSubscription = null;
        return true; // allow pop
      }
      return false; // stay on page
    }
    return true; // not recording; allow pop
  }

  Future<bool?> _showLeaveSessionDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End session?'),
        content: const Text(
            'Leaving now will end the test session and discard current progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text('Continue Session'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('End Session',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for heart rate chart
class HeartRateChartPainter extends CustomPainter {
  final List<double> heartRateData;
  final double progress; // 0..1 for animated reveal

  HeartRateChartPainter(this.heartRateData, {this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (heartRateData.isEmpty) return;

    // Gradient stroke
    final gradient = LinearGradient(
      colors: [Colors.redAccent, Colors.red],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    final rect = Offset.zero & size;

    final strokePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Glow effect under the line
    final glowPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    final maxHR = heartRateData.reduce((a, b) => a > b ? a : b);
    final minHR = heartRateData.reduce((a, b) => a < b ? a : b);
    final hrRange = maxHR - minHR;

    final visibleCount = (heartRateData.length * progress)
        .clamp(0, heartRateData.length)
        .toInt();
    final count =
        visibleCount > 1 ? visibleCount : (heartRateData.isNotEmpty ? 1 : 0);

    // Smooth with simple Catmull-Rom-like segments
    Offset? prevPoint;
    for (int i = 0; i < count; i++) {
      final x = (i / (heartRateData.length - 1)) * size.width;
      final normalizedHR =
          hrRange > 0 ? (heartRateData[i] - minHR) / hrRange : 0.5;
      final y = size.height - (normalizedHR * size.height);

      final point = Offset(x, y);
      if (prevPoint == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        // Quadratic bezier to smooth the line
        final control = Offset((prevPoint.dx + point.dx) / 2, prevPoint.dy);
        path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
      }
      prevPoint = point;
    }

    // Draw glow then main stroke
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
