# Firebase Data Management Strategy for Wearable Device Data

## Problem

- Wearable device sending data every 10 seconds
- Firebase storage filling up quickly
- Potential high billing costs
- Need efficient data retention policy

## Solutions

### 1. Firebase Database Rules with TTL (Time To Live)

Configure Firebase Realtime Database rules to automatically delete old data:

```json
{
  "rules": {
    "health_metrics": {
      "$userId": {
        "$deviceId": {
          "current": {
            ".write": "auth != null && auth.uid == $userId",
            ".read": "auth != null && auth.uid == $userId"
          },
          "history": {
            "$timestamp": {
              ".write": "auth != null && auth.uid == $userId",
              ".read": "auth != null && auth.uid == $userId",
              // Auto-delete data older than 24 hours (86400 seconds)
              ".validate": "now - parseInt($timestamp) < 86400000"
            }
          }
        }
      }
    }
  }
}
```

### 2. Cloud Functions for Data Cleanup

Use Firebase Cloud Functions to automatically clean up old data:

```javascript
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Clean up data older than 24 hours every hour
exports.cleanupOldHealthData = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (context) => {
    const db = admin.database();
    const now = Date.now();
    const cutoff = now - 24 * 60 * 60 * 1000; // 24 hours ago

    try {
      const healthMetricsRef = db.ref("health_metrics");
      const snapshot = await healthMetricsRef.once("value");

      const deletions = [];

      snapshot.forEach((userSnapshot) => {
        userSnapshot.forEach((deviceSnapshot) => {
          const historyRef = deviceSnapshot.child("history");
          historyRef.forEach((timestampSnapshot) => {
            const timestamp = parseInt(timestampSnapshot.key);
            if (timestamp < cutoff) {
              deletions.push(timestampSnapshot.ref.remove());
            }
          });
        });
      });

      await Promise.all(deletions);
      console.log(`Cleaned up ${deletions.length} old health data entries`);
    } catch (error) {
      console.error("Error cleaning up old data:", error);
    }
  });
```

### 3. Data Aggregation Strategy

Instead of storing every 10-second reading, aggregate data:

```javascript
// Store only:
// - Current/latest reading (overwrites previous)
// - Hourly aggregates (min, max, avg)
// - Daily summaries
// - Alert events only

const aggregateHealthData = (readings) => {
  return {
    timestamp: Date.now(),
    heartRate: {
      current: readings[readings.length - 1].heartRate,
      avg: readings.reduce((sum, r) => sum + r.heartRate, 0) / readings.length,
      min: Math.min(...readings.map((r) => r.heartRate)),
      max: Math.max(...readings.map((r) => r.heartRate)),
    },
    // Only store if significant change or alert condition
    storeCondition:
      hasSignificantChange(readings) || isAlertCondition(readings),
  };
};
```

### 4. Optimized Data Structure

```json
{
  "health_metrics": {
    "userId123": {
      "deviceABC": {
        "current": {
          "heartRate": 75,
          "timestamp": 1695123456789,
          "batteryLevel": 85
        },
        "hourly_summary": {
          "2023091912": {
            "heartRate": { "min": 65, "max": 85, "avg": 74 },
            "dataPoints": 360
          }
        },
        "alerts": {
          "1695123456789": {
            "type": "high_hr",
            "value": 120,
            "threshold": 100
          }
        }
      }
    }
  }
}
```

## Recommended Implementation Priority

1. **Immediate**: Update Firebase rules with TTL
2. **Short-term**: Implement data aggregation in your app
3. **Medium-term**: Deploy Cloud Functions for cleanup
4. **Long-term**: Implement smart storage (alerts only)

## Cost Estimation

- Current: ~8,640 writes/day per device (every 10s)
- Optimized: ~24-48 writes/day per device (hourly + alerts)
- **Savings: ~99% reduction in Firebase operations**
