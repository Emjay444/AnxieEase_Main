# Firebase Security Rules Deployment Script
# This script helps you deploy the new secure Firebase rules

Write-Host "🔐 Firebase Security Rules Deployment" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Check if Firebase CLI is installed
try {
    firebase --version | Out-Null
    Write-Host "✅ Firebase CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   npm install -g firebase-tools" -ForegroundColor Yellow
    Write-Host "   Then run: firebase login" -ForegroundColor Yellow
    exit 1
}

# Check if user is logged in
try {
    $loginCheck = firebase projects:list 2>&1
    if ($loginCheck -like "*not logged in*" -or $loginCheck -like "*Error*") {
        Write-Host "❌ Not logged into Firebase. Please run:" -ForegroundColor Red
        Write-Host "   firebase login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Firebase authentication verified" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase login verification failed" -ForegroundColor Red
    exit 1
}

# Show current directory and files
Write-Host "`n📁 Current directory: $PWD" -ForegroundColor Blue
Write-Host "📄 Checking for rule files..." -ForegroundColor Blue

if (Test-Path "database_rules_iot.json") {
    Write-Host "✅ Found: database_rules_iot.json" -ForegroundColor Green
} else {
    Write-Host "❌ Missing: database_rules_iot.json" -ForegroundColor Red
    exit 1
}

if (Test-Path "firebase.json") {
    Write-Host "✅ Found: firebase.json" -ForegroundColor Green
} else {
    Write-Host "⚠️  firebase.json not found. Creating basic configuration..." -ForegroundColor Yellow
    
    $firebaseConfig = @{
        "database" = @{
            "rules" = "database_rules_iot.json"
        }
    } | ConvertTo-Json -Depth 3
    
    $firebaseConfig | Out-File -FilePath "firebase.json" -Encoding UTF8
    Write-Host "✅ Created firebase.json" -ForegroundColor Green
}

# Show a preview of the rules
Write-Host "`n📋 Security Rules Preview:" -ForegroundColor Blue
Write-Host "=================================" -ForegroundColor Blue
$rulesContent = Get-Content "database_rules_iot.json" -Raw
$lines = $rulesContent -split "`n" | Select-Object -First 10
foreach ($line in $lines) {
    Write-Host "   $line" -ForegroundColor Gray
}
Write-Host "   ... (truncated)" -ForegroundColor Gray

# Ask for confirmation
Write-Host "`n⚠️  IMPORTANT SECURITY UPDATE" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow
Write-Host "This will replace your current Firebase Realtime Database rules with secure rules that:" -ForegroundColor White
Write-Host "• ✅ Require authentication for all access" -ForegroundColor Green
Write-Host "• ✅ Restrict users to their own data only" -ForegroundColor Green  
Write-Host "• ✅ Add proper data validation" -ForegroundColor Green
Write-Host "• ✅ Prevent unauthorized device access" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Your app may stop working temporarily until you:" -ForegroundColor Yellow
Write-Host "   1. Set up device ownership records" -ForegroundColor White
Write-Host "   2. Ensure user authentication is working" -ForegroundColor White
Write-Host "   3. Test all app functionality" -ForegroundColor White

$confirmation = Read-Host "`nDo you want to deploy these security rules? (y/N)"

if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
    Write-Host "`n🚀 Deploying Firebase rules..." -ForegroundColor Blue
    
    try {
        firebase deploy --only database
        Write-Host "`n✅ Firebase rules deployed successfully!" -ForegroundColor Green
        
        Write-Host "`n📋 Next Steps:" -ForegroundColor Blue
        Write-Host "=================================" -ForegroundColor Blue
        Write-Host "1. 📖 Read FIREBASE_SECURITY_RULES_GUIDE.md for complete setup instructions" -ForegroundColor White
        Write-Host "2. 🔧 Run setup_device_ownership.js to configure device ownership" -ForegroundColor White
        Write-Host "3. 🧪 Test your app to ensure it still works with new rules" -ForegroundColor White
        Write-Host "4. 📊 Monitor Firebase Console > Database > Usage for any rule violations" -ForegroundColor White
        
    } catch {
        Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
        Write-Host "Please check your Firebase project configuration and try again." -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Deployment cancelled. Your current rules remain unchanged." -ForegroundColor Yellow
    Write-Host "⚠️  WARNING: Your database is still vulnerable to unauthorized access!" -ForegroundColor Red
}

Write-Host "`nFor detailed setup instructions, see: FIREBASE_SECURITY_RULES_GUIDE.md" -ForegroundColor Cyan