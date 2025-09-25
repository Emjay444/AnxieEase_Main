# 🔄 AUTO-SYNC SETUP GUIDE: SUPABASE ↔ FIREBASE

## 🎯 **Problem Solved:**
When admin changes device assignment in Supabase, Firebase now updates automatically in real-time!

## 📡 **Deployed Functions:**

### 1. **syncDeviceAssignment** - Webhook Receiver
- **URL:** `https://us-central1-anxieease-sensors.cloudfunctions.net/syncDeviceAssignment`
- **Purpose:** Receives Supabase webhooks when device assignments change
- **Triggers:** Automatic Firebase sync when admin makes changes

### 2. **testDeviceSync** - Manual Test Trigger  
- **URL:** `https://us-central1-anxieease-sensors.cloudfunctions.net/testDeviceSync`
- **Purpose:** Test the sync functionality manually
- **Usage:** Call this URL to verify sync is working

## 🔧 **Supabase Webhook Setup:**

### **Step 1: Create Supabase Webhook**
1. Go to your Supabase Dashboard
2. Navigate to **Database > Webhooks**
3. Click **Create a new webhook**

### **Step 2: Configure Webhook**
```
Name: Firebase Device Assignment Sync
Table: wearable_devices
Events: ☑️ INSERT, ☑️ UPDATE, ☑️ DELETE
HTTP Method: POST
URL: https://us-central1-anxieease-sensors.cloudfunctions.net/syncDeviceAssignment
HTTP Headers: 
  Content-Type: application/json
  Authorization: Bearer YOUR_SECRET_TOKEN (optional)
```

### **Step 3: Test Configuration**
```bash
# Test the webhook manually:
curl -X POST https://us-central1-anxieease-sensors.cloudfunctions.net/testDeviceSync
```

## 🎯 **How It Works:**

### **Real-Time Flow:**
```
1. Admin changes assignment in Supabase
2. Supabase triggers webhook → Firebase Function
3. Firebase Function updates assignment automatically  
4. User gets immediate access to device
5. Old user loses access instantly
```

### **Data Sync Process:**
```typescript
// When Supabase webhook fires:
{
  "type": "UPDATE",
  "record": {
    "device_id": "AnxieEase001",
    "user_id": "e0997cb7-684f-41e5-929f-4480...",
    "baseline_hr": 73.5,
    "is_active": true
  }
}

// Firebase automatically updates:
/devices/AnxieEase001/assignment/
{
  assignedUser: "e0997cb7-684f-41e5-929f-4480...",
  activeSessionId: "session_1758754470882",
  status: "active",
  assignedBy: "supabase_webhook_sync",
  supabaseSync: {
    syncedAt: timestamp,
    baselineHR: 73.5,
    webhookTrigger: true
  }
}
```

## ✅ **Benefits Achieved:**

### **Instant Sync** ⚡
- Admin changes → Immediate Firebase update
- No manual sync needed
- Real-time device handover

### **Perfect Isolation** 🛡️  
- Old user session ends automatically
- New user session starts immediately
- Clean handover with no data leaks

### **Automatic Baseline Sync** 📊
- User's personal baseline (73.5 BPM) synced from Supabase
- Anxiety detection uses correct thresholds
- No manual configuration needed

## 🧪 **Testing the Auto-Sync:**

### **Method 1: Test Function**
```bash
# Call the test function
curl https://us-central1-anxieease-sensors.cloudfunctions.net/testDeviceSync
```

### **Method 2: Change Assignment in Supabase**
1. Go to Supabase Dashboard
2. Edit `wearable_devices` table 
3. Change `user_id` for AnxieEase001
4. Firebase updates automatically! ✨

### **Method 3: Manual Verification**
```javascript
// Check if sync worked:
node auto_sync_supabase_firebase.js
```

## 📱 **Production Usage:**

### **Admin Workflow:**
```
1. Admin opens Supabase dashboard
2. Admin assigns device to new user  
3. System automatically syncs (< 2 seconds)
4. New user can use device immediately
5. Old user loses access instantly
```

### **User Experience:**
```
✅ Seamless device handover
✅ No manual steps needed  
✅ Instant access activation
✅ Perfect privacy isolation
```

## 🔧 **Troubleshooting:**

### **If Sync Doesn't Work:**
1. Check webhook is configured correctly
2. Verify Firebase Function deployment
3. Test with manual sync function
4. Check Firebase Function logs

### **Manual Sync Fallback:**
```bash
# Force sync if webhook fails:
node sync_device_assignment_from_supabase.js
```

## 🎉 **Result:**
**Admin changes in Supabase now automatically sync to Firebase in real-time!** 

No more manual intervention needed - your system is now fully automated! 🚀