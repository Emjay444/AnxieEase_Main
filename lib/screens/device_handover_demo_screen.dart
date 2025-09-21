import 'package:flutter/material.dart';
import '../services/device_sharing_service.dart';
import '../services/supabase_service.dart';

/// Demo screen showing how device handover works between users
class DeviceHandoverDemoScreen extends StatefulWidget {
  const DeviceHandoverDemoScreen({super.key});

  @override
  State<DeviceHandoverDemoScreen> createState() =>
      _DeviceHandoverDemoScreenState();
}

class _DeviceHandoverDemoScreenState extends State<DeviceHandoverDemoScreen> {
  final DeviceSharingService _deviceSharingService = DeviceSharingService();
  final SupabaseService _supabaseService = SupabaseService();

  String? _currentUserDeviceId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = _supabaseService.client.auth.currentUser;
    final deviceId = await _deviceSharingService.getCurrentUserDeviceId();

    setState(() {
      _currentUserId = user?.id.substring(0, 8);
      _currentUserDeviceId = deviceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Handover Demo'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current User Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'You are currently:',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('User ID: $_currentUserId'),
                    Text('Virtual Device: $_currentUserDeviceId'),
                    Text(
                        'Firebase Path: devices/$_currentUserDeviceId/current'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Data Isolation Explanation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Data Isolation Works:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataPathItem(
                        'Physical Device',
                        'AnxieEase001/current',
                        'Source of sensor data',
                        Colors.green),
                    const SizedBox(height: 8),
                    _buildDataPathItem(
                        'User 1 (Previous)',
                        'AnxieEase001_User1abc/current',
                        'Isolated - you cannot access this',
                        Colors.red),
                    const SizedBox(height: 8),
                    _buildDataPathItem(
                        'You (Current)',
                        '$_currentUserDeviceId/current',
                        'Your private data path',
                        Colors.blue),
                    const SizedBox(height: 8),
                    _buildDataPathItem(
                        'User 3 (Next)',
                        'AnxieEase001_User3xyz/current',
                        'Will be created for next user',
                        Colors.orange),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Handover Process
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Device Handover Process:',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProcessStep('1', 'User 1 finishes testing',
                        'Clicks "Release Device"'),
                    _buildProcessStep(
                        '2', 'System cleans up', 'Stops sync to User 1 path'),
                    _buildProcessStep(
                        '3', 'User 1 logs out', 'Local data cleared'),
                    _buildProcessStep(
                        '4', 'User 2 logs in', 'Gets new account session'),
                    _buildProcessStep('5', 'User 2 assigns device',
                        'Creates new virtual device'),
                    _buildProcessStep(
                        '6', 'Fresh data sync starts', 'To User 2 path only'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Privacy Guarantees
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Privacy Guarantees:',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[700],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPrivacyItem(
                        '✅ Different Firebase paths for each user'),
                    _buildPrivacyItem(
                        '✅ Different SharedPreferences keys per user'),
                    _buildPrivacyItem('✅ Different Supabase user accounts'),
                    _buildPrivacyItem('✅ No cross-user data access possible'),
                    _buildPrivacyItem('✅ Clean session start for each user'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Test Button
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Complete'),
                    content: const Text('In a real scenario, you would:\n\n'
                        '1. Click "Release Device"\n'
                        '2. Log out\n'
                        '3. Next user logs in\n'
                        '4. Next user assigns device\n\n'
                        'Each user will only see their own data!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Simulate Handover'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPathItem(
      String label, String path, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'devices/$path',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessStep(String step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(text),
    );
  }
}
