import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(PermissionTestApp());

class PermissionTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Permission Test',
      home: PermissionTestScreen(),
    );
  }
}

class PermissionTestScreen extends StatefulWidget {
  @override
  _PermissionTestScreenState createState() => _PermissionTestScreenState();
}

class _PermissionTestScreenState extends State<PermissionTestScreen> {
  String _permissionStatus = 'Not checked';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request both phone and notification permissions together
    final Map<Permission, PermissionStatus> permissionStatuses = await [
      Permission.phone,
      Permission.notification,
    ].request();

    setState(() {
      _permissionStatus = 'Phone: ${permissionStatuses[Permission.phone]}\n'
          'Notification: ${permissionStatuses[Permission.notification]}';
    });

    print('📞 Phone permission: ${permissionStatuses[Permission.phone]}');
    print(
        '🔔 Notification permission: ${permissionStatuses[Permission.notification]}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Permission Test'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Permission Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              _permissionStatus,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: Text('Request Permissions Again'),
            ),
          ],
        ),
      ),
    );
  }
}
