# 🔕 Enhanced Rate Limiting with User Confirmation

## Overview

The enhanced rate limiting system extends notification cooldown periods when users confirm they are **NOT anxious**, reducing false positive notifications and improving user experience.

## How It Works

### 🚦 **Current Rate Limiting (Before Enhancement)**

```
Mild:     5 minutes cooldown
Moderate: 3 minutes cooldown
Severe:   1 minute cooldown
Critical: 30 seconds cooldown
```

### 🎯 **Enhanced Rate Limiting (Based on User Response)**

| **User Response**       | **Mild** | **Moderate** | **Severe** | **Critical** |
| ----------------------- | -------- | ------------ | ---------- | ------------ |
| **"YES"** (Anxious)     | 5 min    | 3 min        | 1 min      | 30 sec       |
| **"NO, I'M OK"**        | 1 HOUR   | 1 HOUR       | 30 MIN     | 5 MIN        |
| **"NOT NOW"** (Dismiss) | 15 min   | 15 min       | 10 min     | 2 min        |

## User Experience Flow

### 1. **Initial Notification**

```
🟠 Moderate Alert
Your heart rate is elevated (95 BPM)
Are you feeling anxious or stressed?

[YES] [NO, I'M OK] [NOT NOW]
```

### 2. **User Response: "NO, I'M OK"**

```
Thanks! We'll reduce moderate alerts for the next 1 hour.
```

### 3. **Extended Quiet Period**

- System will NOT send another moderate alert for 1 hour
- Unless heart rate reaches severe/critical levels
- User can still manually check status in app

### 4. **User Response: "YES"**

```
We're here to help. Let's try some breathing exercises.
```

- Normal cooldown applies (3 minutes for moderate)
- User gets immediate help options
- System remains highly sensitive

### 5. **User Response: "NOT NOW"**

```
Understood. We'll give you 15 minutes before the next moderate alert.
```

- Medium cooldown applies (15 minutes for moderate)
- Balances user comfort with safety
- Assumes user might be busy but not necessarily anxiety-free

## Implementation Details

### **Cloud Functions**

- `handleUserConfirmationResponse`: Records user responses
- `isRateLimitedWithConfirmation`: Checks enhanced rate limits
- `getRateLimitStatus`: Debug function for rate limit status

### **Client-Side Integration**

- `AnxietyConfirmationDialog`: Updated to call Cloud Function
- User gets feedback about extended quiet periods
- Seamless integration with existing notification flow

### **Data Structure**

```typescript
interface RateLimitData {
  lastNotification: number;
  lastUserResponse?: {
    timestamp: number;
    confirmed: boolean; // false = "not anxious"
    severity: string;
  };
}
```

## Benefits

### ✅ **For Users**

- Fewer false positive notifications
- Better sleep (no unnecessary night alerts)
- Maintains trust in the system
- Still protected for real emergencies

### ✅ **For System**

- Learns from user feedback
- Reduces notification fatigue
- Improves accuracy over time
- Maintains safety for critical alerts

## Configuration

### **Cooldown Periods**

```typescript
const RATE_LIMIT_CONFIG = {
  mild: {
    baseCooldown: 5 * 60 * 1000, // 5 minutes
    confirmedCooldown: 60 * 60 * 1000, // 1 hour
    maxCooldown: 2 * 60 * 60 * 1000, // Max 2 hours
  },
  // ... other severities
};
```

### **Safety Limits**

- Maximum cooldown: 2 hours (mild/moderate)
- Maximum cooldown: 1 hour (severe)
- Maximum cooldown: 15 minutes (critical)
- Critical alerts always have shorter cooldowns for safety

## Testing

### **Manual Testing**

1. Trigger mild/moderate anxiety alert
2. Respond "No, I'm OK"
3. Verify 1-hour cooldown is applied
4. Test that severe alerts still work during cooldown

### **Debug Function**

```typescript
// Call from client to check current rate limit status
const status = await functions.httpsCallable("getRateLimitStatus")();
console.log(status.data);
```

## Future Enhancements

- **Machine Learning**: Learn user patterns over time
- **Context Awareness**: Consider time of day, activity, etc.
- **Personalized Cooldowns**: Adjust based on user preferences
- **Smart Escalation**: Gradually increase sensitivity if no user feedback

## Migration Notes

- Existing rate limits continue to work normally
- Enhanced features activate when users start confirming
- No breaking changes to current notification system
- Backward compatible with existing user data
