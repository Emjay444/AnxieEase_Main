# AnxieEase - Real-time Notifications

## Overview

AnxieEase includes a real-time notification system that monitors Firebase data for anxiety detection levels and sends appropriate notifications based on severity.

## Firebase Data Structure

The system monitors the following Firebase path:

```
/devices/AnxieEase001/Metrics/anxietyDetected
```

Expected data structure:

```json
{
  "heartRate": 180,
  "severity": "moderate",
  "temperature": 38,
  "timestamp": "10:20pm"
}
```

## Severity Levels

The system recognizes three severity levels:

- **Mild**: Green notification for slight elevations
- **Moderate**: Orange notification for noticeable symptoms
- **Severe**: Red notification for urgent high-risk situations

## Implementation Details

### Dependencies

The system uses the following packages:

```yaml
firebase_database: ^11.3.6
awesome_notifications: ^0.9.3
flutter_local_notifications: ^16.3.3
provider: ^6.1.2
timezone: ^0.9.4
```

### Key Components

1. **SeverityNotifier Class** (`lib/services/severity_notifier.dart`)

   - Primary notification service using awesome_notifications
   - Monitors Firebase data
   - Sends notifications based on severity levels
   - Provides current severity state to the UI

2. **NotificationFallback Class** (`lib/services/notification_fallback.dart`)

   - Fallback notification service using flutter_local_notifications
   - Used automatically if awesome_notifications fails to initialize
   - Provides the same functionality as SeverityNotifier

3. **Notification Channels**
   - `alerts_channel`: Used for severity-based notifications
   - `basic_channel`: Used for test notifications

### Usage

To use the notification system in your own screens:

1. Make sure to initialize Firebase and set up the notification providers in your `main.dart`:

```dart
// Initialize Firebase
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

// Try to initialize awesome_notifications
bool useAwesomeNotifications = true;
try {
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'alerts_channel',
        channelName: 'Alerts',
        channelDescription: 'Notification alerts for severity levels',
        defaultColor: Colors.redAccent,
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
} catch (e) {
  debugPrint('Error initializing AwesomeNotifications: $e');
  useAwesomeNotifications = false;
}

// Create the appropriate notifier based on what's available
final notifier = useAwesomeNotifications
    ? SeverityNotifier()
    : NotificationFallback();

// Initialize the fallback service if needed
if (!useAwesomeNotifications) {
  final fallback = notifier as NotificationFallback;
  await fallback.initialize();
}

// Wrap your app with the provider
runApp(
  ChangeNotifierProvider(
    create: (context) => notifier,
    child: const MyApp(),
  ),
);
```

2. Start the appropriate listener in your main screen:

```dart
@override
void initState() {
  super.initState();

  // Determine which notification service we're using
  final usingSeverityNotifier = Provider.of<ChangeNotifier>(context, listen: false)
      is SeverityNotifier;

  // Initialize the appropriate listener
  if (usingSeverityNotifier) {
    Provider.of<SeverityNotifier>(context, listen: false).initializeListener();
  } else {
    final ref = FirebaseDatabase.instance
        .ref('devices/AnxieEase001/Metrics/anxietyDetected');
    Provider.of<NotificationFallback>(context, listen: false)
        .initializeListener(ref);
  }
}
```

3. Access the current severity in your UI:

```dart
// Determine which notification service we're using
final usingSeverityNotifier = Provider.of<ChangeNotifier>(context, listen: false)
    is SeverityNotifier;

// Get the severity depending on which service we're using
String severity;
if (usingSeverityNotifier) {
  severity = Provider.of<SeverityNotifier>(context).currentSeverity;
} else {
  severity = Provider.of<NotificationFallback>(context).currentSeverity;
}
```

## Testing the Notification System

To test the notification system:

1. Open `lib/main.dart`
2. Uncomment the line: `// notification_test.main();`
3. Comment out the regular app startup code
4. Run the app

The test app provides a simple interface to see the current severity level from Firebase and allows you to manually trigger notifications. It will automatically switch to the fallback implementation if there are any issues with awesome_notifications.
