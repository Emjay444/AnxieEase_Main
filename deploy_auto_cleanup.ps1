# 🚀 DEPLOY AUTO-CLEANUP FIREBASE FUNCTIONS (PowerShell)
# 
# This script deploys the auto-cleanup functions to Firebase

Write-Host "🔥 Deploying Auto-Cleanup Firebase Functions..." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

# Navigate to functions directory
Set-Location functions

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Build TypeScript
Write-Host "🔧 Building TypeScript..." -ForegroundColor Cyan
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build TypeScript" -ForegroundColor Red
    exit 1
}

# Deploy specific functions
Write-Host "🚀 Deploying auto-cleanup functions..." -ForegroundColor Cyan
firebase deploy --only functions:autoCleanup,functions:manualCleanup,functions:getCleanupStats

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Auto-Cleanup Functions Deployed!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Available Functions:" -ForegroundColor White
    Write-Host "1. autoCleanup - Scheduled daily cleanup (2 AM UTC)" -ForegroundColor Gray
    Write-Host "2. manualCleanup - On-demand cleanup via HTTP" -ForegroundColor Gray
    Write-Host "3. getCleanupStats - View cleanup history and statistics" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔗 Function URLs:" -ForegroundColor White
    Write-Host "Manual cleanup: https://us-central1-anxieease-sensors.cloudfunctions.net/manualCleanup" -ForegroundColor Blue
    Write-Host "Cleanup stats: https://us-central1-anxieease-sensors.cloudfunctions.net/getCleanupStats" -ForegroundColor Blue
    Write-Host ""
    Write-Host "⏰ Scheduled cleanup runs daily at 2 AM UTC automatically." -ForegroundColor Yellow
    Write-Host "💡 Test manual cleanup first to ensure everything works correctly." -ForegroundColor Yellow
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}