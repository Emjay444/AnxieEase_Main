import 'package:flutter/material.dart';
import '../services/device_sharing_service.dart';
import '../services/data_sync_service.dart';
import '../services/supabase_service.dart';

/// Testing screen for device assignment during testing phase
class TestingDeviceAssignmentScreen extends StatefulWidget {
  const TestingDeviceAssignmentScreen({super.key});

  @override
  State<TestingDeviceAssignmentScreen> createState() =>
      _TestingDeviceAssignmentScreenState();
}

class _TestingDeviceAssignmentScreenState
    extends State<TestingDeviceAssignmentScreen> {
  final DeviceSharingService _deviceSharingService = DeviceSharingService();
  final DataSyncService _dataSyncService = DataSyncService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isDeviceAssigned = false;
  bool _isLoading = false;
  String? _currentUserDeviceId;

  @override
  void initState() {
    super.initState();
    _checkDeviceAssignment();
  }

  Future<void> _checkDeviceAssignment() async {
    setState(() => _isLoading = true);

    try {
      final isAssigned =
          await _deviceSharingService.isDeviceAssignedToCurrentUser();
      final deviceId = await _deviceSharingService.getCurrentUserDeviceId();

      setState(() {
        _isDeviceAssigned = isAssigned;
        _currentUserDeviceId = deviceId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error checking device assignment: $e');
    }
  }

  Future<void> _assignDevice() async {
    setState(() => _isLoading = true);

    try {
      final success = await _deviceSharingService.assignDeviceToCurrentUser();

      if (success && _currentUserDeviceId != null) {
        // Start data sync from physical device to virtual device
        _dataSyncService.startSyncForUser(_currentUserDeviceId!);
        await _dataSyncService.syncCurrentData(_currentUserDeviceId!);

        setState(() {
          _isDeviceAssigned = true;
          _isLoading = false;
        });

        _showSuccess(
            'Device assigned successfully! You can now use the AnxieEase device.');
      } else {
        setState(() => _isLoading = false);
        _showError(
            'Device is currently being used by another tester. Please try again later.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error assigning device: $e');
    }
  }

  Future<void> _releaseDevice() async {
    setState(() => _isLoading = true);

    try {
      await _deviceSharingService.releaseDeviceAssignment();
      _dataSyncService.stopSync();

      setState(() {
        _isDeviceAssigned = false;
        _isLoading = false;
      });

      _showSuccess(
          'Device released successfully! Other testers can now use it.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error releasing device: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabaseService.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Device Assignment'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current User',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${user?.email ?? 'Not logged in'}'),
                    Text('User ID: ${user?.id.substring(0, 8) ?? 'N/A'}...'),
                    if (_currentUserDeviceId != null)
                      Text('Virtual Device: $_currentUserDeviceId'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Device Status Card
            Card(
              color: _isDeviceAssigned ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isDeviceAssigned
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _isDeviceAssigned ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Device Status',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDeviceAssigned
                          ? 'AnxieEase device is assigned to you. You can now proceed with testing.'
                          : 'AnxieEase device is not assigned to you. Click "Assign Device" to start testing.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_isDeviceAssigned)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continue Testing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _releaseDevice,
                    icon: const Icon(Icons.logout),
                    label: const Text('Release Device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _assignDevice,
                icon: const Icon(Icons.link),
                label: const Text('Assign Device to Me'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

            const SizedBox(height: 30),

            // Instructions Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Testing Instructions',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '1. Assign the device to yourself before testing'),
                    const Text(
                        '2. Only one person can use the device at a time'),
                    const Text(
                        '3. Release the device when you\'re done testing'),
                    const Text(
                        '4. Your data will be kept separate from other testers'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
