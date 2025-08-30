# Native IoT Gateway Architecture - Implementation Guide

## Overview

This implementation restructures the AnxieEase app to use a **Native Android IoT Gateway Service** instead of the Flutter-based gateway. The native service ensures continuous operation even when the app is closed/killed.

## Architecture

### 1. **Native IoT Gateway Service** (`BluetoothIoTGatewayService.kt`)

- **Full IoT Gateway functionality** in native Android (Kotlin)
- **Persistent Bluetooth connection** with automatic reconnection
- **Firebase integration** for real-time data upload
- **Anxiety detection** with configurable thresholds
- **Foreground service** with persistent notification
- **Independent operation** - continues when app is closed

### 2. **Flutter UI Layer** (`NativeIoTGatewayService.dart`)

- **EventChannel** for receiving real-time data from native service
- **MethodChannel** for sending commands to native service
- **UI-only responsibilities** - no gateway logic
- **Real-time updates** without duplicating backend logic

### 3. **Enhanced MainActivity** (`MainActivity.kt`)

- **Dual channel setup** - EventChannel + MethodChannel
- **Service lifecycle management**
- **Command forwarding** between Flutter and native service

## Key Components

### Native Service Features

```kotlin
class BluetoothIoTGatewayService : Service() {
    // ✅ Persistent Bluetooth connection
    // ✅ Firebase Realtime Database integration
    // ✅ Anxiety detection algorithm
    // ✅ Real-time data streaming to Flutter
    // ✅ Command processing from Flutter
    // ✅ Automatic reconnection logic
    // ✅ Background operation independence
}
```

### Flutter Service Wrapper

```dart
class NativeIoTGatewayService extends ChangeNotifier {
    // ✅ Real-time sensor data streaming
    // ✅ Gateway control (start/stop/reconnect)
    // ✅ Device command sending
    // ✅ Status monitoring
    // ✅ Error handling
}
```

## Implementation Benefits

### 1. **True Background Operation**

- Gateway continues running when app is killed
- Firebase data upload never stops
- Bluetooth connection maintained independently
- System-level service with restart capabilities

### 2. **Single Source of Truth**

- Only one Bluetooth connection (in native service)
- No conflicts between Flutter and native connections
- Centralized data processing and upload
- Consistent Firebase data structure

### 3. **Optimal Resource Usage**

- Native code for performance-critical operations
- Flutter only for UI rendering
- Efficient memory management
- Reduced battery consumption

### 4. **Scalable Architecture**

- Easy to add new device commands
- Expandable anxiety detection algorithms
- Multiple Flutter apps can connect to same service
- Modular component design

## Usage Instructions

### 1. **Starting the Native Gateway**

```dart
final nativeGateway = NativeIoTGatewayService();
await nativeGateway.initialize();

final success = await nativeGateway.startGateway(
  deviceAddress: "XX:XX:XX:XX:XX:XX",
  userId: "user123",
  deviceId: "device001",
);
```

### 2. **Receiving Real-time Data**

```dart
// Listen to sensor data updates
nativeGateway.addListener(() {
  if (nativeGateway.heartRate != null) {
    print('Heart Rate: ${nativeGateway.heartRate} bpm');
  }

  if (nativeGateway.anxietySeverity != 'normal') {
    print('Anxiety Alert: ${nativeGateway.anxietySeverity}');
  }
});
```

### 3. **Sending Device Commands**

```dart
// Send vibration command to device
await nativeGateway.sendDeviceCommand('vibrate');

// Reconnect device
await nativeGateway.reconnectDevice();
```

### 4. **UI Integration**

```dart
// Use the provided WatchScreenNative for a complete UI
class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WatchScreenNative(), // Complete native gateway UI
    );
  }
}
```

## Data Flow

```
IoT Device (Bluetooth) → Native Service → Firebase
                            ↓
                        EventChannel
                            ↓
                        Flutter UI
```

### Real-time Updates

1. **IoT Device** sends sensor data via Bluetooth
2. **Native Service** parses and processes data
3. **Firebase** receives structured data upload
4. **EventChannel** streams data to Flutter
5. **Flutter UI** updates in real-time

### Command Flow

```
Flutter UI → MethodChannel → Native Service → IoT Device
```

## Firebase Integration

### Data Structure

```json
{
  "devices": {
    "AnxieEase001": {
      "current": {
        "sensors": {
          "heartRate": 85,
          "spo2": 98.5,
          "bodyTemperature": 36.7,
          "batteryLevel": 85,
          "isDeviceWorn": true,
          "timestamp": 1640995200000
        },
        "device": {
          "isConnected": true,
          "lastUpdate": 1640995200000
        }
      },
      "Metrics": {
        /* Historical data */
      },
      "alerts": {
        /* Anxiety alerts */
      }
    }
  }
}
```

## Testing & Deployment

### 1. **Build & Install**

```bash
cd AnxieEase_Main
flutter build apk --debug
flutter install
```

### 2. **Test Background Operation**

1. Start the native gateway from Flutter
2. Close the Flutter app completely
3. Verify service continues running (persistent notification)
4. Check Firebase for continued data uploads
5. Reopen app to verify real-time data streaming

### 3. **Verify Firebase Data**

- Monitor Firebase Realtime Database console
- Confirm continuous data uploads when app is closed
- Validate data structure and frequency

## Troubleshooting

### Common Issues

1. **Service not starting**

   - Check Android permissions
   - Verify Firebase configuration
   - Check device pairing status

2. **No data streaming to Flutter**

   - Verify EventChannel setup
   - Check service connection status
   - Confirm Bluetooth connectivity

3. **Firebase upload failures**
   - Validate service-account-key.json
   - Check internet connectivity
   - Verify Firebase project configuration

### Debug Logs

```bash
# Monitor service logs
adb logcat | grep "BluetoothIoTGateway"

# Monitor Flutter logs
flutter logs
```

## Migration from Flutter Gateway

To migrate from the existing Flutter-based IoT Gateway:

1. **Replace DeviceManager calls** with NativeIoTGatewayService
2. **Update watch.dart** to use WatchScreenNative
3. **Remove old IoT Gateway services** (keep for backup initially)
4. **Test thoroughly** before removing old code

This architecture provides a robust, scalable foundation for continuous IoT monitoring with true background operation capabilities.
