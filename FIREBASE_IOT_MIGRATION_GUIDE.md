# 🔧 Firebase IoT Migration Guide

## ✅ ISSUE IDENTIFIED

Your Firebase database still contains **old Bluetooth data structure** with fields like:

- `deviceAddress: "08:A6:F7:B0:CA:7E"`
- `source: "native_gateway"`
- `isDeviceWorn: false`
- `Metrics` structure from Bluetooth

## 🚀 SOLUTION: Complete Firebase Migration

### Step 1: Manual Firebase Console Cleanup

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your AnxieEase project**
3. **Navigate to Realtime Database**
4. **Delete the old structure**:
   - Find `devices/AnxieEase001`
   - Delete the entire node (contains old Bluetooth data)

### Step 2: Import New IoT Structure

**Copy and import this JSON into your Firebase Realtime Database:**

```json
{
  "devices": {
    "AnxieEase001": {
      "metadata": {
        "deviceId": "AnxieEase001",
        "deviceType": "simulated_health_monitor",
        "userId": "user_001",
        "status": "initialized",
        "isSimulated": true,
        "architecture": "pure_iot_firebase",
        "version": "2.0.0"
      },
      "current": {
        "heartRate": 72,
        "spo2": 98,
        "bodyTemp": 36.5,
        "ambientTemp": 23.0,
        "battPerc": 85,
        "worn": true,
        "deviceId": "AnxieEase001",
        "userId": "user_001",
        "severityLevel": "mild",
        "source": "iot_simulation",
        "connectionStatus": "ready"
      }
    }
  },
  "users": {
    "user_001": {
      "userId": "user_001",
      "deviceId": "AnxieEase001",
      "preferences": {
        "dataFrequency": 2000,
        "stressDetection": true,
        "historicalDataRetention": 30
      }
    }
  }
}
```

### Step 3: Update Database Rules

1. **Go to Database Rules in Firebase Console**
2. **Replace the rules with the IoT-optimized version** (use `database_rules_iot.json`):

```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": "auth != null",
        ".write": "auth != null",
        "metadata": {
          ".indexOn": ["status", "deviceType", "isSimulated"]
        },
        "current": {
          ".indexOn": ["timestamp", "severityLevel", "connectionStatus"]
        },
        "history": {
          ".indexOn": ["timestamp", "sessionId"]
        },
        "alerts": {
          ".indexOn": ["timestamp", "type", "severity"]
        }
      }
    },
    "users": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        ".write": "auth != null && auth.uid == $userId",
        ".indexOn": ["lastActivity", "deviceId"]
      }
    }
  }
}
```

## 📊 NEW vs OLD Structure Comparison

### ❌ OLD (Bluetooth Structure)

```json
{
  "Metrics": {
    "ambientTemperature": 37.93,
    "batteryLevel": 100,
    "bodyTemperature": 0,
    "deviceAddress": "08:A6:F7:B0:CA:7E",
    "heartRate": 0,
    "isDeviceWorn": false,
    "source": "native_gateway",
    "spo2": 98.92,
    "userId": "AnxieEase001"
  }
}
```

### ✅ NEW (IoT Structure)

```json
{
  "current": {
    "heartRate": 72,
    "spo2": 98,
    "bodyTemp": 36.5,
    "ambientTemp": 23.0,
    "battPerc": 85,
    "worn": true,
    "severityLevel": "mild",
    "source": "iot_simulation",
    "connectionStatus": "connected"
  }
}
```

## 🔄 Automatic Cleanup (Already Implemented)

Your app's `IoTSensorService` now includes **automatic cleanup** that will:

1. **Remove old Bluetooth fields** when the service initializes:

   - `deviceAddress`
   - `isDeviceWorn` → now `worn`
   - `isStressDetected` → now `severityLevel` (mild/moderate/severe)
   - `Metrics` structure
   - `WifiSSID`

2. **Set up proper IoT structure** with clean field names and your severity system

## ✅ Verification Steps

After migration, your Firebase should show:

1. **Clean IoT structure** with `source: "iot_simulation"`
2. **No Bluetooth references** (no `deviceAddress`, `native_gateway`)
3. **Proper field names** (`worn` instead of `isDeviceWorn`)
4. **Your severity levels** (`mild`, `moderate`, `severe` instead of `isStressDetected`)
5. **Real-time data updates** from the IoT simulation service

### 🎯 Severity Level Mapping

Your IoT service will automatically calculate severity based on sensor data:

- **`mild`**: Normal values (HR < 100, SpO2 > 95%)
- **`moderate`**: Elevated values (HR 100-120, SpO2 92-95%, temp > 37.2°C)
- **`severe`**: Critical values (HR > 120, SpO2 < 92%, stress mode active)

## 🚀 Next Steps

1. **Clear Firebase data** using the console
2. **Import the new IoT structure**
3. **Run your app** - the IoTSensorService will automatically populate with simulated data
4. **Watch the Firebase console** - you should see real-time IoT data flowing in

---

## 💡 Result

Your Firebase will be fully converted from **Bluetooth+Kotlin architecture** to **pure IoT simulation** with proper data structure, field names, and real-time updates!
