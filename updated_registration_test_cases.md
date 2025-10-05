# Updated Search/Clinics Test Cases - Matching Actual Implementation

## Test Case Updates Based on Current Code

**AE Search-001** | Search Module | **AE-A**AE-Alert-001** | Alert Detection Module | Trigger Mild Anxiety Alert (+15 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with established baseline 73.2 BPM  
2. Simulate sustained HR increase to 88.2 BPM (73.2 + 15 = mild threshold) for 30+ seconds  
3. Wait for Firebase realtime sustained detection trigger  
4. Observe notification: "🟢 Mild Alert - 60% Confidence - I noticed a slight increase in your heart rate to 88 BPM (20% above your baseline) for 35s. Are you experiencing any anxiety or is this just normal activity?"  
**Expected:** Mild alert triggered with GREEN icon (not yellow), 60% confidence level, baseline context showing percentage increase, confirmation dialog appears requiring user response.1** | Alert Detection Module | Trigger Mild Anxiety Alert (+15 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with established baseline 73.2 BPM  
2. Simulate HR increase to 88.2 BPM (73.2 + 15 = mild threshold)  
3. Wait for Firebase realtime detection trigger  
4. Observe notification: "🟢 Mild Anxiety Alert - Heart rate 20.5% above baseline (88.2 BPM). Try some breathing exercises."  
**Expected:** Mild alert triggered with green icon, baseline context showing 20.5% increase, and breathing exercise suggestion.cesses Clinics via Quick Actions navigation  
**Steps:**  
1. Navigate to Home screen  
2. Scroll to find the quick actions section  
3. Tap the "Clinics" button (navigation icon)  
**Expected:** Search screen opens showing Google Maps interface with loading indicator. App automatically requests location permission if not previously granted.

---

**AE Search-002** | Search Module | Location permission request on first access  
**Steps:**  
1. Tap "Clinics" from quick actions (fresh install)  
2. Observe location permission popup from Android/iOS system  
3. Note available permission options  
**Expected:** System location permission dialog appears with options: "Allow only while using the app", "Allow once", "Don't allow" (exact wording varies by platform). No custom popup - uses native system dialog.

---

**AE Search-003** | Search Module | Grant location permission - Allow while using app  
**Steps:**  
1. When system permission dialog appears  
2. Tap "Allow only while using the app" (or equivalent)  
3. Observe map loading and location detection  
**Expected:** Permission granted, map loads showing current location marker, automatic search begins for nearby mental health clinics within radius, markers appear on map.

---

**AE Search-004** | Search Module | Deny location permission initially  
**Steps:**  
1. When system permission dialog appears  
2. Tap "Don't allow" or "Deny"  
3. Observe fallback screen  
**Expected:** Location permission error screen appears with red location_off icon, "Location Permission Required" title, explanation text, and "Grant Location Permission" button to retry.

---

**AE Search-005** | Search Module | Permanently deny location permission  
**Steps:**  
1. Deny location permission multiple times OR  
2. Access after selecting "Don't ask again"  
3. Try to retry permission request  
**Expected:** Shows permanently denied error screen with orange "Open App Settings" button instead of retry button. Tapping opens device app settings for manual permission enabling.

---

**AE Search-006** | Search Module | Auto-display nearby clinics within search radius  
**Steps:**  
1. After granting location permission successfully  
2. Wait for Google Places API search to complete  
3. Observe map markers and clinic data  
**Expected:** Map displays rose-colored markers for hospitals/clinics within 5km radius. Each marker shows clinic name and address. Search includes hospitals, medical centers, and mental health facilities.

---

**AE Search-007** | Search Module | View clinic details from map marker  
**Steps:**  
1. Tap any clinic marker on the map  
2. Observe bottom card that appears  
3. Check displayed information  
**Expected:** Bottom overlay card shows clinic name, full address, calculated distance from user, estimated travel time, rating (if available), and "Get Directions" button. Card is draggable.

---

**AE Search-008** | Search Module | View clinic list in draggable bottom sheet  
**Steps:**  
1. When no specific clinic is selected  
2. Drag up from bottom of screen OR tap clinic count  
3. Explore the clinic list interface  
**Expected:** Draggable sheet shows "Nearby Mental Health Clinics" header, clinic count, travel mode buttons (Drive/Walk/Bike/Transit), and scrollable list of clinic cards with details.

---

**AE Search-009** | Search Module | Switch travel modes and view updated directions  
**Steps:**  
1. Open clinic details or list view  
2. Select different travel mode buttons: Drive, Walk, Bike, Transit  
3. Observe changes in time estimates  
**Expected:** Travel mode selection updates estimated travel times and distances for all clinics. Driving is default. Transit may show "N/A" if public transport unavailable.

---

**AE Search-010** | Search Module | Get directions to selected clinic  
**Steps:**  
1. Select a clinic from map or list  
2. Review route information in bottom card  
3. Tap "Start Navigation" button  
**Expected:** Blue route polyline appears on map, navigation top bar activates showing current instruction, voice guidance begins (if enabled), "End Navigation" button appears.

---

**AE Search-011** | Search Module | Navigate with voice guidance during route  
**Steps:**  
1. Start navigation to any clinic  
2. Observe voice guidance behavior  
3. Check voice toggle functionality  
**Expected:** TTS announces turn-by-turn instructions automatically. Navigation bar shows current step and next instruction. Voice toggle button (mic icon) allows enabling/disabling voice guidance.

---

**AE Search-012** | Search Module | Toggle voice guidance during navigation  
**Steps:**  
1. During active navigation  
2. Tap the voice toggle button (mic icon) in navigation controls  
3. Test audio output changes  
**Expected:** Voice guidance toggles on/off. Mic icon changes between filled (enabled) and outline/crossed (disabled). Navigation continues visually regardless of voice setting.

---

**AE Search-013** | Search Module | End navigation session  
**Steps:**  
1. During active navigation  
2. Tap "End Navigation" button in bottom card  
3. Confirm navigation termination  
**Expected:** Navigation stops, route polyline disappears, navigation top bar hides, returns to normal map view with clinic markers. Voice guidance stops, location tracking continues.

---

**AE Search-014** | Search Module | Handle location services disabled  
**Steps:**  
1. Disable location services in device settings  
2. Open Clinics screen  
3. Observe error handling  
**Expected:** Shows "Location services are disabled" dialog with explanation and buttons: "Cancel", "Open Settings" (opens device location settings). No map or clinics load until location enabled.

---

**AE Search-015** | Search Module | Navigate back to Home screen  
**Steps:**  
1. From any state in Search/Clinics screen  
2. Tap back arrow in app bar (top-left)  
3. Confirm navigation behavior  
**Expected:** Returns to Home screen. If navigation was active, it stops automatically. Map state and permissions are preserved for next visit.

---

## Notifications Module Test Cases

**AE-Notif-011** | Notifications Module | User filters notifications by category or status, sorts by date, and navigates through paginated results  
**Steps:**  
1. Tap filter buttons (Type: All, Alert, Reminder, Logs; Status: All, Unanswered, Answered)  
2. List updates with filtered notifications  
3. Use sort dropdown to select "Newest First" or "Oldest First"  
4. Navigate between pages using First/Previous/Next/Last buttons  
5. Change items per page (5, 10, 20, 50) from dropdown  
**Expected:** Only notifications matching selected filters are displayed. Sort order changes chronologically (newest default). Pagination shows "X of Y" pages with "Showing A-B of C total" counter. Items per page updates display and resets to page 1.

---

## Anxiety Alert Detection Test Cases

**AE-Alert-001** | Alert Detection Module | Trigger Mild Anxiety Alert (+15 BPM above baseline)  
**Steps:**  
1. Wear AnxieEase device with established baseline 73.2 BPM  
2. Simulate HR increase to 88.2 BPM (73.2 + 15 = mild threshold)  
3. Wait for Firebase realtime detection trigger  
4. Observe notification: "� Mild Anxiety Detected - Heart rate 20.5% above baseline (88.2 BPM). Try some breathing exercises."  
**Expected:** Mild alert triggered with yellow icon (not green), baseline context showing 20.5% increase, and breathing exercise suggestion.

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

**AE-Alert-007** | Alert Detection Module | Sustained anxiety detection (30+ second duration requirement)  
**Steps:**  
1. Wear device and simulate sustained HR elevation  
2. Maintain 98.2 BPM (moderate level) for exactly 35+ seconds continuously  
3. Wait for sustained detection trigger after 30-second minimum threshold  
4. Observe notification with duration context included  
**Expected:** Sustained anxiety alert triggered only after 30+ seconds: "🟡 Moderate Alert - 70% Confidence - Your heart rate increased to 98 BPM (34% above your baseline) for 35s. How are you feeling?" Duration information embedded in notification body.

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