# AnxieEase Anxiety Alert Detection Test Cases

## Overview
This document contains comprehensive test cases for the AnxieEase anxiety detection system, specifically focusing on the real-time sustained anxiety detection functionality.

### System Specifications
- **Detection Function**: `realTimeSustainedAnxietyDetection`
- **Baseline**: 73.2 BPM (established user baseline)
- **Sustained Duration Required**: 30+ seconds continuous elevation
- **Threshold Type**: Fixed BPM additions (not percentage-based)

### Severity Thresholds
| Severity | Threshold | BPM Range | Confidence | Icon | Color |
|----------|-----------|-----------|------------|------|-------|
| Elevated | +10 BPM | 83.2 BPM | - | - | - |
| Mild | +15 BPM | 88.2+ BPM | 60% | 🟢 | Green (#4CAF50) |
| Moderate | +25 BPM | 98.2+ BPM | 70% | 🟡 | Yellow (#FFFF00) |
| Severe | +35 BPM | 108.2+ BPM | 85% | 🟠 | Orange (#FFA500) |
| Critical | +45 BPM | 118.2+ BPM | 95% | 🚨 | Red (#FF0000) |

---

## Test Cases

**AE-Alert-001** | Alert Detection Module | Trigger Mild Anxiety Alert (+15 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with established baseline 73.2 BPM  
2. Simulate sustained HR increase to 88.2 BPM (73.2 + 15 = mild threshold) for 30+ seconds  
3. Wait for Firebase realtime sustained detection trigger  
4. Observe notification: "🟢 Mild Alert - 60% Confidence - I noticed a slight increase in your heart rate to 88 BPM (20% above your baseline) for 35s. Are you experiencing any anxiety or is this just normal activity?"  
**Expected:** Mild alert triggered with GREEN icon (not yellow), 60% confidence level, baseline context showing percentage increase, confirmation dialog appears requiring user response.

---

**AE-Alert-002** | Alert Detection Module | Trigger Moderate Anxiety Alert (+25 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with baseline 73.2 BPM  
2. Simulate sustained HR increase to 98.2 BPM (73.2 + 25 = moderate threshold) for 30+ seconds  
3. Wait for Firebase realtime sustained detection trigger  
4. Observe notification: "🟡 Moderate Alert - 70% Confidence - Your heart rate increased to 98 BPM (34% above your baseline) for 35s. How are you feeling? Is everything alright?"  
**Expected:** Moderate alert with YELLOW icon, 70% confidence level, percentage calculation, confirmation dialog with check-in question requiring user response.

---

**AE-Alert-003** | Alert Detection Module | Trigger Severe Anxiety Alert (+35 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with baseline 73.2 BPM  
2. Simulate sustained HR increase to 108.2 BPM (73.2 + 35 = severe threshold) for 30+ seconds  
3. Wait for Firebase realtime sustained detection trigger  
4. Observe notification: "🟠 Severe Alert - 85% Confidence - Hi there! I noticed your heart rate was elevated to 108 BPM (48% above your baseline) for 35s. Are you experiencing any anxiety or stress right now?"  
**Expected:** Severe alert with ORANGE icon, 85% confidence level, percentage calculation, confirmation dialog with anxiety check-in requiring user response.

---

**AE-Alert-004** | Alert Detection Module | Trigger Critical Emergency Alert (+45 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with baseline 73.2 BPM  
2. Simulate sustained HR increase to 118.2 BPM (73.2 + 45 = critical threshold) for 30+ seconds  
3. Wait for Firebase realtime sustained detection trigger  
4. Observe notification: "🚨 Critical Alert - 95% Confidence - URGENT: Your heart rate has been critically elevated at 118 BPM (61% above your baseline) for 35s. This indicates a severe anxiety episode. Please seek immediate support if needed."  
**Expected:** Critical alert with RED emergency icon, 95% confidence level, NO confirmation dialog required (auto-confirmed as anxiety), immediate support recommendation and direct help modal opens.

---

**AE-Alert-005** | Alert Detection Module | No alert for insufficient HR elevation (+10 BPM elevated range)  
**Steps:**  
1. Wear device with baseline 73.2 BPM  
2. Simulate sustained HR increase to 83.2 BPM (73.2 + 10 = elevated but below mild threshold) for 30+ seconds  
3. Wait for sustained detection system processing  
4. Verify no anxiety alert notification is sent  
**Expected:** No anxiety alert triggered. HR in "elevated" range (+10 BPM) but below +15 BPM mild threshold. System requires minimum +15 BPM above baseline for anxiety detection.

---

**AE-Alert-006** | Alert Detection Module | No repeated alert for same severity level  
**Steps:**  
1. Trigger mild anxiety alert (88.2 BPM sustained for 30+ seconds)  
2. Maintain HR at 89-92 BPM (still mild range 88.2-98.1 BPM) for additional 30+ seconds  
3. Wait for additional sustained detection cycles  
4. Verify no duplicate notifications sent  
**Expected:** No duplicate alerts. System uses rate limiting and only triggers when severity level changes, not for same severity. Mild range notifications suppressed to prevent spam.

---

**AE-Alert-007** | Alert Detection Module | No alert for insufficient duration (HR elevation under 30 seconds)  
**Steps:**  
1. Wear device with baseline 73.2 BPM  
2. Simulate HR increase to 98.2 BPM (moderate threshold) for only 25 seconds  
3. Return HR to baseline before 30-second minimum threshold  
4. Wait and verify no anxiety alert notification is sent  
**Expected:** No anxiety alert triggered. System requires minimum 30+ seconds sustained elevation. Brief HR spikes under 30 seconds are ignored to prevent false positives from temporary activities like climbing stairs, quick movements, etc.

---

**AE-Alert-008** | Device Connection Module | Trigger device disconnection alert  
**Steps:**  
1. Wear device and establish connection (AnxieEase001 shows "Connected" with green status)  
2. Simulate device disconnection (power off device or move out of Bluetooth range)  
3. Wait for connection timeout detection (typically 30-60 seconds)  
4. Observe device status change and connection alert  
**Expected:** Device status changes from "Connected" to "Disconnected" with red status indicator. App shows connection lost warning but may not send push notification for disconnection events (depends on system design for device alerts vs anxiety alerts).

---

**AE-Alert-009** | Background Processing Module | Receive push notification when app is backgrounded  
**Steps:**  
1. Ensure app is running and device connected with valid FCM token  
2. Minimize AnxieEase app (press home button to background)  
3. Trigger sustained anxiety condition (HR increase to 98.2 BPM moderate level for 30+ seconds)  
4. Check for push notification on device lock screen/notification panel  
**Expected:** Firebase FCM push notification appears with anxiety alert details even when app is backgrounded. Notification uses data-only payload to ensure delivery and triggers local notification with proper channel, sound, and vibration based on severity level.

---

**AE-Alert-010** | Confirmation Dialog Module | User confirms anxiety episode via dialog  
**Steps:**  
1. Trigger anxiety alert (mild/moderate/severe level requiring confirmation)  
2. Tap anxiety alert notification to open AnxietyConfirmationDialog  
3. Review dialog showing severity-based colors, confidence level, and personalized message  
4. Tap "Yes" to confirm experiencing anxiety  
5. Select actual severity level from dropdown (Mild/Moderate/Severe) and tap "Submit"  
**Expected:** Confirmation dialog appears with severity-specific colors (Green/Yellow/Orange), confidence percentage (60%/70%/85%), user response recorded to Supabase notifications table with 'answered' status, rate limiting adjusted based on confirmation accuracy.

---

**AE-Alert-011** | Confirmation Dialog Module | User dismisses false positive alert  
**Steps:**  
1. Trigger anxiety alert notification (mild/moderate/severe)  
2. Tap notification to open AnxietyConfirmationDialog  
3. Tap "No" to indicate not experiencing anxiety (false positive)  
4. Tap "Submit" to record false positive feedback  
**Expected:** False positive response recorded to Supabase with 'answered' status and 'no' response, rate limiting cooldown extended for that specific severity level to reduce false positives, snackbar confirmation: "Feedback recorded - thank you!" appears.

---

**AE-Alert-012** | Answered Alert Module | View previously answered alert notification  
**Steps:**  
1. Complete anxiety confirmation dialog (answer "Yes" with chosen severity level)  
2. Navigate to Notifications screen (/notifications route)  
3. Locate and tap the answered anxiety alert in the notifications list  
4. Review answered alert details view  
**Expected:** Alert shows as "Answered" status with checkmark, displays user's response ("Yes - [Severity Level]"), original detection data (HR, baseline, percentage), timestamp, and help options remain available for accessing breathing exercises, grounding techniques, and crisis resources.

---

**AE-Alert-013** | Help Resources Module | Access emergency resources from alert  
**Steps:**  
1. Open answered anxiety alert from notifications screen  
2. Look for help/resource buttons in notification details  
3. Tap available help resources (breathing/grounding/crisis buttons)  
4. Review navigation to appropriate help sections  
**Expected:** Severity-based navigation: Mild alerts → Notifications screen, Moderate alerts → Breathing exercises (/breathing route), Severe alerts → Grounding techniques (/grounding route), Critical alerts → Direct help modal with emergency resources. Access to breathing exercises, grounding techniques, and crisis hotlines available from anxiety alert context.

---

**AE-Alert-014** | Rate Limiting Module | Verify rate limiting after user responses  
**Steps:**  
1. Trigger mild anxiety alert (88.2 BPM sustained 30+ seconds) and confirm as false positive ("No")  
2. Attempt to trigger another mild alert within extended cooldown period (typically 30-60 minutes)  
3. Observe rate limiting suppression behavior in Firebase logs  
4. Verify duplicate alerts of same severity are blocked  
**Expected:** Enhanced rate limiting prevents duplicate alerts of same severity based on false positive feedback. System extends cooldown period for that specific severity level (mild/moderate/severe independently). No user messaging about cooldown - silently suppressed to avoid notification spam. Rate limiting data stored in Supabase for persistence across app sessions.

---

## Testing Notes

### Prerequisites
- Device must be assigned to user with established baseline (73.2 BPM)
- Valid FCM token for push notifications
- Firebase Cloud Functions deployed and active
- Supabase connection configured

### Test Environment Setup
1. Ensure device AnxieEase001 is connected
2. Verify baseline is established in user profile
3. Confirm Firebase realtime database is accessible
4. Test FCM token validity

### Expected Firebase Function Behavior
- Function: `realTimeSustainedAnxietyDetection`
- Trigger: `/devices/{deviceId}/current` data updates
- Duration: 30+ seconds sustained elevation required
- Rate limiting: Per-severity cooldown periods
- Data persistence: Supabase notifications table

### Debugging Tips
- Check Firebase Console logs for detection triggers
- Monitor Supabase notifications table for recorded alerts
- Verify FCM token in device assignments
- Test with simulated data using `real_anxiety_simulator.js`

---

*Last Updated: October 6, 2025*  
*System Version: AnxieEase v2.0 - Sustained Detection Implementation*