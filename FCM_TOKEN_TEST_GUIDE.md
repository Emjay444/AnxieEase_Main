#!/bin/bash

# FCM Token Persistence Testing Guide
# This script helps test the FCM token persistence fix

echo "🧪 FCM Token Persistence Testing Guide"
echo "======================================"
echo ""

echo "📋 Test Scenario: Multiple Users with Single Wearable Device"
echo "Prerequisites:"
echo "- One wearable device (AnxieEase001) with sensor data"
echo "- Multiple user accounts (user1, user2, etc.)"
echo "- Admin access to assign/unassign devices"
echo ""

echo "🔧 Test Steps:"
echo ""

echo "1️⃣ INITIAL SETUP:"
echo "   - Assign AnxieEase001 to User1"
echo "   - User1 opens app and logs in"
echo "   - Wait for FCM token to be stored in assignment node"
echo "   - Check Firebase: /devices/AnxieEase001/assignment/fcmToken should exist"
echo ""

echo "2️⃣ TEST APP BACKGROUNDING/FOREGROUNDING:"
echo "   - User1: Close app completely"
echo "   - Wait 30 seconds"
echo "   - User1: Reopen app"
echo "   - Check logs for 'FCM token stored in assignment node'"
echo "   - Check Firebase: Token should still exist and be refreshed"
echo ""

echo "3️⃣ TEST NOTIFICATION DELIVERY:"
echo "   - While User1 app is closed:"
echo "   - Trigger anxiety alert (simulate high heart rate)"
echo "   - User1 should receive push notification"
echo "   - User1: Tap notification to open app"
echo "   - Verify notification appears in app"
echo ""

echo "4️⃣ TEST DEVICE REASSIGNMENT:"
echo "   - Admin: Unassign device from User1"
echo "   - Admin: Assign device to User2"
echo "   - User2: Open app and log in"
echo "   - Check Firebase: /devices/AnxieEase001/assignment/fcmToken should update to User2's token"
echo "   - Check Firebase: /devices/AnxieEase001/assignment/assignedUser should be User2's ID"
echo ""

echo "5️⃣ TEST NOTIFICATION TO NEW USER:"
echo "   - User2: Close app"
echo "   - Trigger anxiety alert"
echo "   - User2 should receive notification (NOT User1)"
echo "   - User1 should NOT receive notification"
echo ""

echo "🔍 DEBUGGING COMMANDS:"
echo ""
echo "Check Firebase assignment node:"
echo "curl -X GET 'https://[PROJECT].firebaseio.com/devices/AnxieEase001/assignment.json'"
echo ""

echo "Check FCM token in assignment:"
echo "curl -X GET 'https://[PROJECT].firebaseio.com/devices/AnxieEase001/assignment/fcmToken.json'"
echo ""

echo "Check user-level FCM tokens:"
echo "curl -X GET 'https://[PROJECT].firebaseio.com/users/[USER_ID]/fcmToken.json'"
echo ""

echo "📱 MOBILE APP LOGS TO WATCH FOR:"
echo "✅ 'FCM token stored in assignment node: AnxieEase001'"
echo "✅ 'App resumed - refreshing FCM token'"
echo "✅ 'FCM token persisted before app backgrounding'"
echo "✅ 'Periodic FCM token refresh'"
echo "✅ 'Assignment FCM token validation passed'"
echo "⚠️  'Assignment missing FCM token or belongs to different user'"
echo "❌ 'No anxiety alert FCM token found for user'"
echo ""

echo "🎯 SUCCESS CRITERIA:"
echo "- FCM token persists when app is closed/reopened"
echo "- Notifications reach the currently assigned user"
echo "- Previous users stop receiving notifications after reassignment"
echo "- Token is refreshed periodically while app is active"
echo "- Token is validated and refreshed if missing"
echo ""

echo "🚨 COMMON ISSUES TO CHECK:"
echo "- Multiple tokens in assignment node (should be only one)"
echo "- Token belongs to wrong user ID"
echo "- Assignment node missing fcmToken field"
echo "- Cloud Functions looking in wrong location for token"
echo ""

echo "Test completed! Check the results above. ✅"