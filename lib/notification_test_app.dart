import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize awesome_notifications
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Basic notification tests',
        defaultColor: Colors.blue,
        importance: NotificationImportance.High,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: 'alerts_channel',
        channelName: 'Alerts',
        channelDescription: 'Notification alerts for severity levels',
        defaultColor: Colors.red,
        importance: NotificationImportance.High,
        ledColor: Colors.white,
      ),
    ],
  );

  // Check permissions
  final isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // Initialize the notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => notificationService,
      child: const TestApp(),
    ),
  );
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _sendTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'basic_channel',
        title: 'Test Notification',
        body: 'This is a test notification',
        notificationLayout: NotificationLayout.Default,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the severity
    String severity = Provider.of<NotificationService>(context).currentSeverity;

    Color statusColor;
    String statusText;

    switch (severity.toLowerCase()) {
      case 'mild':
        statusColor = Colors.green;
        statusText = '🟢 MILD';
        break;
      case 'moderate':
        statusColor = Colors.orange;
        statusText = '🟠 MODERATE';
        break;
      case 'severe':
        statusColor = Colors.red;
        statusText = '🔴 SEVERE';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnxieEase Monitor'),
        backgroundColor: statusColor.withOpacity(0.7),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Current Anxiety Level:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                statusText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _sendTestNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Send Test Notification',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final isAllowed =
                    await AwesomeNotifications().isNotificationAllowed();
                if (!isAllowed) {
                  await AwesomeNotifications()
                      .requestPermissionToSendNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Notification permission requested')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Notifications already allowed')),
                  );
                }
              },
              child: const Text('Check Notification Permissions'),
            ),
          ],
        ),
      ),
    );
  }
}
