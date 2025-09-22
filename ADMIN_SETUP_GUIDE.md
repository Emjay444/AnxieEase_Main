# AnxieEase Admin Device Management System

This system allows administrators to manually connect and disconnect users from the AnxieEase001 wearable device for testing purposes.

## 🎯 **How User-Device Separation Works**

### **Physical Device Reality:**
- **Wearable Hardware**: Sends data to `devices/AnxieEase001/current` in Firebase (hardcoded)
- **Single Device**: Only one physical AnxieEase001 device exists

### **Multi-User App Logic:**
- **Virtual Device IDs**: App creates `AnxieEase001_<userID>` for user separation
- **Firebase Reading**: App extracts real device ID and reads from correct path
- **Database Storage**: Uses real device ID with user_id for Supabase records

### **Admin Control Layer:**
- **Assignment Management**: Admin controls which user can use the device
- **Time-based Sessions**: Assignments can have expiration times
- **Session Tracking**: Monitor active testing sessions

## 🚀 **Setup Instructions**

### **1. Install Database Functions**
Run the SQL functions in your Supabase SQL editor:

```bash
# Copy and run this file in Supabase SQL Editor
supabase/admin_device_functions.sql
```

### **2. Set up Admin Dashboard**
Use the HTML admin dashboard:

1. **Edit Configuration**: Update `admin_dashboard.html` with your Supabase details:
   ```javascript
   const SUPABASE_URL = 'https://your-project.supabase.co';  // UPDATE THIS
   const SUPABASE_ANON_KEY = 'your-anon-key';                // UPDATE THIS
   ```

2. **Host the Dashboard**: 
   - Upload `admin_dashboard.html` to your web hosting
   - Or serve locally: `python -m http.server 8000`
   - Access at: `http://localhost:8000/admin_dashboard.html`

### **3. Admin User Setup**
Create admin users in Supabase Auth or use existing user accounts.

## 📋 **Admin Dashboard Features**

### **Device Status Monitoring**
- View current assignment status
- See assigned user information
- Check session duration and expiration
- Monitor device connectivity

### **User Assignment**
- **Select User**: Choose from dropdown of registered users
- **Set Duration**: 1-24 hours assignment periods
- **Add Notes**: Admin notes for tracking purposes
- **Assign Device**: Grant device access to selected user

### **Device Management**
- **Release Assignment**: Manually disconnect user from device
- **View History**: See past assignments and usage patterns
- **Session Tracking**: Monitor active testing sessions

## 🔄 **Workflow Example**

### **Admin Side:**
1. **Login** to admin dashboard
2. **Select User** from dropdown (e.g., "Jamie Lou")
3. **Set Duration** (e.g., 2 hours)
4. **Add Notes** (e.g., "Baseline testing session")
5. **Assign Device** - User can now link device in mobile app

### **User Side:**
1. **Open App** and navigate to device setup
2. **Enter Device ID**: "AnxieEase001"
3. **Device Validation**: App checks assignment and connects
4. **Baseline Recording**: User can record baseline heart rate
5. **Testing Session**: Device streams real-time data

### **Session End:**
1. **Auto-Expiry**: Assignment expires after set duration
2. **Manual Release**: Admin can manually disconnect
3. **Session Complete**: Device becomes available for next user

## 🛠 **Technical Architecture**

```
Physical Device → Firebase: devices/AnxieEase001/current
                    ↓
Admin Dashboard → Supabase: Controls user assignments
                    ↓
Mobile App → Reads: devices/AnxieEase001/current (real data)
         → Saves: user_id + device_id records (user separation)
```

### **Database Schema**
```sql
wearable_devices:
- device_id: "AnxieEase001" 
- user_id: Currently assigned user (NULL when available)
- assignment_status: "assigned" | "active" | "completed" | "available"
- session_status: "pending" | "active" | "completed"
- assigned_at: When admin assigned device
- expires_at: When assignment expires
- admin_notes: Admin notes about assignment

baseline_heart_rates:
- user_id: User who recorded baseline
- device_id: "AnxieEase001"
- baseline_hr: Recorded baseline value
- (Composite key ensures one baseline per user-device pair)
```

## 🔐 **Security Features**

### **Access Control**
- **Admin Authentication**: Dashboard requires Supabase login
- **RLS Policies**: Row-level security on database tables
- **User Isolation**: Users only see their own data

### **Assignment Validation**
- **Single Assignment**: Device can only be assigned to one user at a time
- **Expiration Checking**: Automatic assignment expiry
- **Conflict Prevention**: Prevents double-assignment errors

### **Data Separation**
- **Virtual Device IDs**: User-specific app logic without affecting hardware
- **Database Isolation**: Composite keys ensure proper user separation
- **Firebase Security**: Read-only access for mobile apps

## 📊 **Monitoring & Analytics**

### **Real-time Dashboard**
- Current device status
- Active user sessions
- Device connectivity status
- Assignment history

### **Usage Tracking**
- Session duration logs
- User testing frequency
- Device utilization metrics
- Error and success rates

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Device Not Linking**:
   - Check admin assignment status
   - Verify user is assigned and not expired
   - Confirm Firebase device data is active

2. **Permission Denied**:
   - Ensure user has valid assignment
   - Check Supabase RLS policies
   - Verify admin functions are installed

3. **Assignment Conflicts**:
   - Release existing assignment first
   - Check for expired assignments
   - Refresh admin dashboard

### **Debug Steps**
1. Check admin dashboard for current assignment
2. Verify device data in Firebase console
3. Review Supabase logs for function calls
4. Check mobile app logs for validation errors

## 📱 **Mobile App Integration**

The admin system is fully integrated with your existing mobile app:

- **Device Validation**: Checks admin assignment before allowing connection
- **Session Management**: Updates session status during testing
- **Data Recording**: Saves user-specific data with proper separation
- **Error Handling**: Provides clear messages when device not assigned

## 🔄 **Updates & Maintenance**

### **Database Functions**
- Run migration scripts in Supabase SQL editor
- Update function permissions as needed
- Monitor function performance and logs

### **Admin Dashboard**
- Update Supabase configuration for new projects
- Customize styling and branding as needed
- Add additional features (notifications, reporting, etc.)

---

**Your admin system provides complete control over device assignments while maintaining proper user data separation! 🎉**