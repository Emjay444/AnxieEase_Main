# Notification Types Documentation

## Database Schema

The `notifications` table only supports **2 types**:

- `alert` - Anxiety alerts, logs, warnings, system messages
- `reminder` - Wellness reminders, breathing reminders, scheduled reminders

## Type Mapping (in supabase_service.dart)

### Mapped to `alert`:

- `anxiety_log` → `alert` (when user dismisses anxiety detection)
- `anxiety_alert` → `alert` (anxiety detection confirmed)
- `log` → `alert` (manual symptom logs)
- `warning` → `alert` (warnings)
- `info` → `alert` (informational messages)
- `system` → `alert` (system notifications)
- `appointment_request` → `alert` (appointment notifications)
- `appointment_expiration` → `alert` (expired appointments)

### Mapped to `reminder`:

- `wellness_reminder` → `reminder` (wellness check-ins)
- `breathing_reminder` → `reminder` (breathing exercises)
- `reminder` → `reminder` (generic reminders)

## UI Filters (notifications_screen.dart)

### Available Filters:

1. **All** - Shows all notifications
2. **Alert** - Shows anxiety detections and logs (type='alert')
   - Excludes wellness content via keyword filtering
3. **Reminder** - Shows wellness and breathing reminders (type='reminder')

### Status Filters (Alert only):

When "Alert" filter is selected, additional status filters appear:

- **All** - All alerts
- **Unanswered** - Alerts not responded to
- **Answered** - Alerts with user responses (YES/NO/NOT NOW)

## Database vs App Type Mismatch

⚠️ **Important**: The original recommended_schema.sql has CHECK constraint for types:

```sql
type IN ('appointment', 'reminder', 'wellness', 'system', 'emergency', 'medication')
```

But the app actually uses:

```sql
type IN ('alert', 'reminder')
```

**The app's simplified 2-type system is the working implementation.**

## Examples

### Anxiety Detection Confirmed:

```dart
type: 'anxiety_alert' → Stored as: 'alert' → Shows in: Alert filter
```

### User Dismisses Detection:

```dart
type: 'anxiety_log' → Stored as: 'alert' → Shows in: Alert filter
```

### Wellness Reminder:

```dart
type: 'wellness_reminder' → Stored as: 'reminder' → Shows in: Reminder filter
```

### Manual Symptom Log:

```dart
type: 'log' → Stored as: 'alert' → Shows in: Alert filter
```

## Recent Fixes

1. **Wellness reminders in Alert filter**: Fixed by adding content-based keyword filtering
2. **Logs filter removed**: Since 'log' type maps to 'alert', the separate Logs filter was non-functional
3. **Critical severity mapping**: 'critical' mapped to 'severe' for database compatibility
