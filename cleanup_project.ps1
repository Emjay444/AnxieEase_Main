# AnxieEase Project Cleanup Script
# This script removes unnecessary files while keeping the core Flutter app intact

Write-Host "Starting AnxieEase project cleanup..." -ForegroundColor Green

# Define the project root
$projectRoot = "c:\Users\molin\OneDrive\Desktop\Capstone\AnxieEase\AnxieEase_Main"
Set-Location $projectRoot

# Files to remove - these are unnecessary for the Flutter app to function
$filesToRemove = @(
    # JavaScript test files (these don't belong in a Flutter project)
    "cleanup_duplicate_data.js",
    "cleanup_test_users.js", 
    "comprehensive_iot_test.js",
    "debug_fcm_cloud_function.js",
    "debug_fcm_step_by_step.js",
    "direct_token_test.js",
    "final_notification_analysis.js",
    "get_fcm_token.js",
    "notification_diagnostic.js",
    "notification_system_analysis.js",
    "quick_test.js",
    "test_app_close_monitoring.js",
    "test_app_open.js",
    "test_auth_notifications.js",
    "test_background_comprehensive.js",
    "test_background_fcm.js",
    "test_background_monitoring.js",
    "test_background_notifications_fixed.js",
    "test_cloud_function.js",
    "test_complete_notifications.js",
    "test_comprehensive_notifications.js",
    "test_data_structure_fix.js",
    "test_database_trigger.js",
    "test_deduplication.js",
    "test_direct_fcm.js",
    "test_direct_fcm_token.js",
    "test_duplicate_notification_fix.js",
    "test_emergency_features.js",
    "test_fcm_background_fixed.js",
    "test_fcm_simple.js",
    "test_fcm_system.js",
    "test_fcm_token_direct.js",
    "test_fcm_unified_system.js",
    "test_fcm_wellness_reminders.js",
    "test_fcm_wellness_simple.js",
    "test_final_diagnosis.js",
    "test_final_fix.js",
    "test_firebase_data_change.js",
    "test_foreground_notification.js",
    "test_notification_fix.js",
    "test_notification_icon.js",
    "test_notification_states.js",
    "test_no_duplicates.js",
    "test_phone_calling_fix.js",
    "test_phone_calling_functionality.js",
    "test_reminder_reliability.js",
    "test_severe_attack.js",
    "test_severity_notification.js",
    "test_simplified_emergency.js",
    "test_single_notification.js",
    "test_single_notification_fix.js",
    "test_unified_notifications.js",
    "test_updated_emergency_features.js",
    "test_watch_widget.js",
    "test_wellness_background.js",
    "test_wellness_messages.js",
    "test_wellness_reminders.js",
    "test_wellness_simple.js",
    
    # Script files
    "check_notification_system.sh",
    "fix_notifications.bat",
    "fix_notifications.ps1",
    "get_sha1.bat",
    "get_sha1_fingerprint.bat",
    "get_sha1_fingerprint.sh",
    "test_background_monitoring.ps1",
    
    # HTML/Python files that don't belong
    "generate_app_icon.html",
    "generate_icon.py",
    "test_google_maps_api.html",
    
    # Excessive documentation files (keeping only essential ones)
    "BACKGROUND_MONITORING_SOLUTION.md",
    "BACKGROUND_MONITORING_TEST_GUIDE.md", 
    "BACKGROUND_NOTIFICATION_FIX.md",
    "check_device_settings.md",
    "CONFIGURE_GOOGLE_MAPS_API.md",
    "CUSTOM_NOTIFICATION_SOUNDS_GUIDE.md",
    "DEPLOY_FUNCTIONS_GUIDE.md",
    "download_notification_sounds.md",
    "EMERGENCY_FEATURES_SUMMARY.md",
    "FCM_TROUBLESHOOTING_GUIDE.md",
    "FCM_WELLNESS_REMINDERS_COMPLETE.md",
    "FIREBASE_DATABASE_SETUP.md",
    "GOOGLE_MAPS_SETUP.md",
    "HOW_TO_ADD_CUSTOM_SOUNDS.md",
    "NATIVE_IOT_GATEWAY_GUIDE.md",
    "NOTIFICATION_ANALYSIS_REPORT.md",
    "NOTIFICATION_SYSTEM_CHECKPOINT.md",
    "NOTIFICATION_SYSTEM_UPDATE.md",
    "README_NOTIFICATIONS.md",
    "SIMPLIFIED_EMERGENCY_SUMMARY.md",
    "TESTING_GUIDE.md",
    
    # Duplicate/unnecessary config files
    "ctrlzed.iml",
    "anxiease.iml"
)

# Count of files to be removed
$totalFiles = $filesToRemove.Count
$removedCount = 0

Write-Host "Found $totalFiles unnecessary files to remove..." -ForegroundColor Yellow

# Remove files safely
foreach ($file in $filesToRemove) {
    $fullPath = Join-Path $projectRoot $file
    if (Test-Path $fullPath) {
        try {
            Remove-Item $fullPath -Force
            Write-Host "✓ Removed: $file" -ForegroundColor Green
            $removedCount++
        }
        catch {
            Write-Host "✗ Failed to remove: $file - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "○ Not found: $file" -ForegroundColor Gray
    }
}

# Clean up node_modules if it exists (not needed for Flutter)
if (Test-Path "node_modules") {
    Write-Host "Removing node_modules directory..." -ForegroundColor Yellow
    try {
        Remove-Item "node_modules" -Recurse -Force
        Write-Host "✓ Removed node_modules directory" -ForegroundColor Green
        $removedCount++
    }
    catch {
        Write-Host "✗ Failed to remove node_modules: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nCleanup completed!" -ForegroundColor Green
Write-Host "Successfully removed $removedCount items." -ForegroundColor Cyan
Write-Host "`nYour Flutter project structure is now clean and organized." -ForegroundColor Green
Write-Host "Essential files preserved:" -ForegroundColor Yellow
Write-Host "  - All lib/ source code" -ForegroundColor White
Write-Host "  - pubspec.yaml and pubspec.lock" -ForegroundColor White 
Write-Host "  - android/, ios/, windows/, web/, linux/, macos/ platform folders" -ForegroundColor White
Write-Host "  - assets/ folder" -ForegroundColor White
Write-Host "  - firebase.json and service-account-key.json" -ForegroundColor White
Write-Host "  - Essential configuration files" -ForegroundColor White
Write-Host "  - README.md" -ForegroundColor White

Write-Host "`nYou can now run 'flutter pub get' to ensure dependencies are up to date." -ForegroundColor Cyan
