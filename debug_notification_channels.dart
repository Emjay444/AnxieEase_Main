import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationChannelDebugger extends StatefulWidget {
  const NotificationChannelDebugger({super.key});

  @override
  State<NotificationChannelDebugger> createState() =>
      _NotificationChannelDebuggerState();
}

class _NotificationChannelDebuggerState
    extends State<NotificationChannelDebugger> {
  List<NotificationChannel> channels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channelList =
          await AwesomeNotifications().listNotificationChannels();
      setState(() {
        channels = channelList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading channels: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createAnxietyAlertsChannel() async {
    try {
      await AwesomeNotifications().setChannel(
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'Anxiety Alerts',
          channelDescription: 'Critical anxiety level notifications',
          defaultColor: const Color(0xFFFF0000),
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          onlyAlertOnce: false,
          playSound: true,
          criticalAlerts: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Colors.red,
        ),
      );
      debugPrint('✅ Anxiety alerts channel created successfully');
      _loadChannels(); // Refresh the list
    } catch (e) {
      debugPrint('❌ Error creating channel: $e');
    }
  }

  Future<void> _testNotification() async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'anxiety_alerts',
          title: '🔴 Test Severe Alert',
          body: 'This is a test severe anxiety alert notification',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          criticalAlert: true,
        ),
      );
      debugPrint('✅ Test notification sent');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Channels Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _createAnxietyAlertsChannel,
                        child: const Text('Create Channel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _testNotification,
                        child: const Text('Test Notification'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _loadChannels,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Notification Channels (${channels.length}):',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: channels.isEmpty
                        ? const Center(
                            child: Text('No notification channels found'),
                          )
                        : ListView.builder(
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final channel = channels[index];
                              return Card(
                                child: ListTile(
                                  title: Text(channel.channelName ?? 'Unknown'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Key: ${channel.channelKey}'),
                                      Text(
                                          'Description: ${channel.channelDescription ?? 'None'}'),
                                      Text(
                                          'Importance: ${channel.importance?.name ?? 'Unknown'}'),
                                      Text('Enabled: ${channel.enabled}'),
                                    ],
                                  ),
                                  leading: Icon(
                                    Icons.notifications,
                                    color: channel.enabled
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
