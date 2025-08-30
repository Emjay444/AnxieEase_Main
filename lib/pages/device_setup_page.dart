import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

/// Device Setup Page
///
/// Provides a seamless first-time device setup experience:
/// - Auto-detects paired Bluetooth devices
/// - One-time configuration
/// - Automatic IoT Gateway startup
/// - Persistent device management
class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  late DeviceManager _deviceManager;
  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> _scannedDevices = [];
  bool _isLoading = true;
  bool _isSettingUp = false;
  bool _isScanning = false;
  bool _showScannedDevices = false;

  @override
  void initState() {
    super.initState();
    _deviceManager = Provider.of<DeviceManager>(context, listen: false);
    _initializeSetup();
  }

  Future<void> _initializeSetup() async {
    setState(() => _isLoading = true);

    try {
      // Initialize device manager
      await _deviceManager.initialize();

      // Check if setup is already complete
      final isSetupComplete = await _deviceManager.isSetupComplete();
      if (isSetupComplete && _deviceManager.selectedDevice != null) {
        // Setup already complete, go back to previous screen
        if (mounted) {
          Navigator.pop(context);
          return;
        }
      }

      // Load paired devices
      await _loadPairedDevices();
    } catch (e) {
      debugPrint('❌ DeviceSetupPage: Error initializing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      debugPrint('🔄 DeviceSetupPage: Loading paired devices...');
      final devices = await _deviceManager.getPairedDevices();
      debugPrint('📱 DeviceSetupPage: Found ${devices.length} paired devices');
      setState(() => _pairedDevices = devices);
    } catch (e) {
      debugPrint('❌ DeviceSetupPage: Error loading paired devices: $e');
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
    });

    try {
      debugPrint('🔍 DeviceSetupPage: Starting device scan...');

      // Try the simple scanning method first
      List<BluetoothDevice> devices =
          await _deviceManager.scanForDevicesSimple();

      // If no devices found, try the original method
      if (devices.isEmpty) {
        debugPrint(
            '🔍 DeviceSetupPage: Simple scan found no devices, trying original method...');
        devices = await _deviceManager.scanForDevices();
      }

      debugPrint(
          '🔍 DeviceSetupPage: Scan complete, found ${devices.length} devices');

      setState(() {
        _scannedDevices = devices;
        _showScannedDevices = true;
        _isScanning = false;
      });

      // Show result to user
      if (mounted) {
        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No devices found. Make sure Bluetooth is enabled and devices are in range.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${devices.length} device(s)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ DeviceSetupPage: Error scanning for devices: $e');
      setState(() => _isScanning = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    setState(() => _isSettingUp = true);

    try {
      final success = await _deviceManager.selectDevice(device);

      if (success) {
        // Auto-start gateway
        await _deviceManager.startGateway();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Device configured: ${device.name}'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back after successful setup
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to configure device'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ DeviceSetupPage: Error selecting device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSettingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing device setup...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Connect Your Health Monitor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'First, pair your device in your phone\'s Bluetooth settings, then select it below.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'How to Connect Your Device',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Turn on your health monitor device\n'
                            '2. Go to your phone\'s Bluetooth settings\n'
                            '3. Tap "Pair new device" or "Add device"\n'
                            '4. Select your health monitor from the list\n'
                            '5. Return to this app and tap "Refresh" below',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tip: After pairing your device, return here and tap "Refresh" to see it in the list below.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Paired Devices
                  const Text(
                    'Paired Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_pairedDevices.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No paired devices found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Follow the steps above to pair your device in Bluetooth settings, then tap "Refresh" to see it here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _pairedDevices.length,
                        itemBuilder: (context, index) {
                          final device = _pairedDevices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.watch,
                                color: Colors.blue,
                                size: 32,
                              ),
                              title: Text(
                                device.name ?? 'Unknown Device',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                device.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: _isSettingUp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.grey,
                                    ),
                              onTap: _isSettingUp
                                  ? null
                                  : () => _selectDevice(device),
                            ),
                          );
                        },
                      ),
                    ),

                  // Refresh Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _isSettingUp
                          ? null
                          : _loadPairedDevices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Paired Devices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
