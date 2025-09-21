import 'package:flutter/material.dart';
import '../services/admin_device_management_service.dart';
import '../services/data_sync_service.dart';
import '../services/device_service.dart';

/// Screen that checks admin-assigned device status
class AdminAssignedDeviceScreen extends StatefulWidget {
  const AdminAssignedDeviceScreen({super.key});

  @override
  State<AdminAssignedDeviceScreen> createState() =>
      _AdminAssignedDeviceScreenState();
}

class _AdminAssignedDeviceScreenState extends State<AdminAssignedDeviceScreen> {
  final AdminDeviceManagementService _adminDeviceService =
      AdminDeviceManagementService();
  final DataSyncService _dataSyncService = DataSyncService();
  final DeviceService _deviceService = DeviceService();

  DeviceAssignmentStatus? _assignmentStatus;
  Map<String, dynamic>? _assignmentInfo;
  bool _isLoading = false;
  bool _isStartingSession = false;

  @override
  void initState() {
    super.initState();
    _checkAssignment();
  }

  Future<void> _checkAssignment() async {
    setState(() => _isLoading = true);

    try {
      final status = await _adminDeviceService.checkDeviceAssignment();
      final info = await _adminDeviceService.getCurrentAssignmentInfo();

      setState(() {
        _assignmentStatus = status;
        _assignmentInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error checking assignment: $e');
    }
  }

  Future<void> _startTestingSession() async {
    setState(() => _isStartingSession = true);

    try {
      // Get virtual device ID
      final virtualDeviceId = await _adminDeviceService.getVirtualDeviceId();

      // Start data sync
      _dataSyncService.startSyncForUser(virtualDeviceId);
      await _dataSyncService.syncCurrentData(virtualDeviceId);

      // Update session status to active
      await _adminDeviceService.updateSessionStatus('in_progress',
          notes: 'Testing session started from mobile app');

      // Link virtual device in device service
      await _deviceService.linkDevice(virtualDeviceId);

      setState(() => _isStartingSession = false);

      _showSuccess(
          'Testing session started! You can now proceed with testing.');

      // Navigate back to main app
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _isStartingSession = false);
      _showError('Error starting session: $e');
    }
  }

  Future<void> _endTestingSession() async {
    setState(() => _isStartingSession = true);

    try {
      // Stop data sync
      _dataSyncService.stopSync();

      // Unlink device
      await _deviceService.unlinkDevice();

      // Update session status to completed
      await _adminDeviceService.updateSessionStatus('completed',
          notes: 'Testing session completed from mobile app');

      setState(() => _isStartingSession = false);

      _showSuccess('Testing session ended. Thank you for your participation!');

      // Refresh assignment status
      _checkAssignment();
    } catch (e) {
      setState(() => _isStartingSession = false);
      _showError('Error ending session: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Assignment'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAssignment,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Assignment Status Card
                  Card(
                    color: _getStatusColor(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getStatusIcon(),
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Device Assignment Status',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _assignmentStatus?.displayMessage ?? 'Checking...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Assignment Details (if assigned)
                  if (_assignmentInfo != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assignment Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Device', 'AnxieEase001'),
                            _buildDetailRow(
                                'Assigned By',
                                _assignmentInfo!['assigned_by_admin']
                                        ?['full_name'] ??
                                    'Admin'),
                            _buildDetailRow(
                                'Assigned At',
                                _formatDateTime(
                                    _assignmentInfo!['assigned_at'])),
                            if (_assignmentInfo!['expires_at'] != null)
                              _buildDetailRow(
                                  'Expires At',
                                  _formatDateTime(
                                      _assignmentInfo!['expires_at'])),
                            if (_assignmentInfo!['admin_notes'] != null)
                              _buildDetailRow(
                                  'Notes', _assignmentInfo!['admin_notes']),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Buttons
                  if (_assignmentStatus?.canUseDevice == true) ...[
                    if (_assignmentStatus?.isActive == true)
                      ElevatedButton.icon(
                        onPressed:
                            _isStartingSession ? null : _endTestingSession,
                        icon: _isStartingSession
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.stop),
                        label: Text(_isStartingSession
                            ? 'Ending...'
                            : 'End Testing Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed:
                            _isStartingSession ? null : _startTestingSession,
                        icon: _isStartingSession
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isStartingSession
                            ? 'Starting...'
                            : 'Start Testing Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                  ] else ...[
                    Card(
                      color: Colors.amber[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.info,
                                color: Colors.amber[700], size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Device Not Available',
                              style: TextStyle(
                                color: Colors.amber[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please contact your study administrator to assign the AnxieEase device to your account.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Contact Admin Button
                  OutlinedButton.icon(
                    onPressed: () {
                      // You can implement contact functionality here
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Contact Administrator'),
                          content: const Text(
                            'If you need device assignment or have issues, please contact your study administrator through the provided channels.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.contact_support),
                    label: const Text('Contact Administrator'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_assignmentStatus?.canUseDevice == true) {
      return _assignmentStatus?.isActive == true ? Colors.green : Colors.teal;
    }
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (_assignmentStatus?.canUseDevice == true) {
      return _assignmentStatus?.isActive == true
          ? Icons.play_circle
          : Icons.check_circle;
    }
    return Icons.schedule;
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}
