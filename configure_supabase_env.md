# Configure Supabase Environment Variables for Firebase Functions

## Problem

Your anxiety detection notifications are being sent to your phone but not appearing in the notifications screen because:

1. ✅ **Background Handler Works**: FCM notifications are received and processed
2. ❌ **Cloud Functions Don't Store to Supabase**: Missing environment variables
3. ❌ **Notifications Screen Empty**: No data in Supabase database

## Solution

### Step 1: Get Your Supabase Service Role Key

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Select your project: `gqsustjxzjzfntcsnvpk`
3. Go to **Settings** → **API**
4. Copy the **eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTIwODg1OCwiZXhwIjoyMDU2Nzg0ODU4fQ.cpwoYCQIEiqnRliT-A25GESAy7lS_YP_ETTYM5idujY** key (not the anon key)

### Step 2: Configure Firebase Functions Environment

Run these commands in your `AnxieEase_Main` directory:

```bash
# Method 1: Using Firebase Functions Config (Recommended)
firebase functions:config:set supabase.url="https://gqsustjxzjzfntcsnvpk.supabase.co"
firebase functions:config:set supabase.service_role_key="YOUR_SERVICE_ROLE_KEY_HERE"

# Deploy the functions with new config
firebase deploy --only functions
```

OR

```bash
# Method 2: Using Environment Variables
# Create a .env file in the functions directory
echo "SUPABASE_URL=https://gqsustjxzjzfntcsnvpk.supabase.co" > functions/.env
echo "SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_HERE" >> functions/.env

# Deploy functions
firebase deploy --only functions
```

### Step 3: Test the Fix

After deploying:

1. **Trigger a real anxiety detection** (use heart rate above baseline)
2. **Check Firebase Functions logs** for: `"🗃️ Supabase insert success:"`
3. **Open your notifications screen** - you should now see the notifications!

### Step 4: Verify It's Working

Look for these logs in Firebase Functions:

- ✅ `"✅ Notification sent successfully to user"`
- ✅ `"🗃️ Supabase insert success:"` (NEW - this means it's working!)
- ❌ `"ℹ️ Supabase env not configured; skipping server-side Supabase insert"` (OLD - this means it's not configured)

## Why This Fixes the Issue

Your current flow:

1. Heart rate exceeds threshold → Cloud Function triggers
2. Cloud Function sends FCM → Your phone receives notification
3. Cloud Function tries to store to Supabase → **FAILS** (missing env vars)
4. Background handler processes FCM → Creates debug markers only
5. Notifications screen loads from Supabase → **EMPTY** (nothing stored)

After the fix:

1. Heart rate exceeds threshold → Cloud Function triggers
2. Cloud Function sends FCM → Your phone receives notification
3. Cloud Function stores to Supabase → **SUCCESS** ✅
4. Background handler processes FCM → Creates debug markers
5. Notifications screen loads from Supabase → **SHOWS NOTIFICATIONS** ✅

## Security Note

The service role key has admin privileges. Keep it secure and never commit it to version control.
