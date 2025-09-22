#!/usr/bin/env powershell

# Firebase Functions Deployment Script for AnxieEase Unified System
# This script deploys the Firebase Cloud Functions that bridge Firebase and Supabase

Write-Host "🚀 Starting AnxieEase Firebase Functions Deployment..." -ForegroundColor Green

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Check if we're logged in to Firebase
try {
    $firebaseList = firebase projects:list 2>&1
    if ($firebaseList -match "Error") {
        Write-Host "❌ Not logged in to Firebase. Please login first:" -ForegroundColor Red
        Write-Host "firebase login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Firebase authentication verified" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase authentication error. Please login:" -ForegroundColor Red
    Write-Host "firebase login" -ForegroundColor Yellow
    exit 1
}

# Change to the functions directory
if (-not (Test-Path "functions")) {
    Write-Host "❌ Functions directory not found. Please run from project root." -ForegroundColor Red
    exit 1
}

Set-Location functions

# Install dependencies
Write-Host "📦 Installing Firebase Functions dependencies..." -ForegroundColor Blue
try {
    npm install
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Check for required environment variables
Write-Host "🔍 Checking environment configuration..." -ForegroundColor Blue

$envVars = @(
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "FIREBASE_PROJECT_ID"
)

$missingVars = @()
foreach ($var in $envVars) {
    $value = firebase functions:config:get | Select-String $var.ToLower()
    if (-not $value) {
        $missingVars += $var
    }
}

if ($missingVars.Count -gt 0) {
    Write-Host "⚠️  Missing required environment variables:" -ForegroundColor Yellow
    foreach ($var in $missingVars) {
        Write-Host "   - $var" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Set them using:" -ForegroundColor Yellow
    Write-Host "firebase functions:config:set supabase.url=your_supabase_url" -ForegroundColor Cyan
    Write-Host "firebase functions:config:set supabase.service_role_key=your_service_role_key" -ForegroundColor Cyan
    Write-Host "firebase functions:config:set firebase.project_id=your_project_id" -ForegroundColor Cyan
    Write-Host ""
    $continue = Read-Host "Continue deployment anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Deploy functions
Write-Host "🚀 Deploying Firebase Functions..." -ForegroundColor Blue
try {
    firebase deploy --only functions
    Write-Host "✅ Firebase Functions deployed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}

# Return to project root
Set-Location ..

Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Blue
Write-Host "1. Update your Flutter app configuration with the new function URLs" -ForegroundColor White
Write-Host "2. Deploy your web admin dashboard" -ForegroundColor White
Write-Host "3. Test the unified system end-to-end" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitor your functions at:" -ForegroundColor Blue
Write-Host "https://console.firebase.google.com/project/YOUR_PROJECT_ID/functions" -ForegroundColor Cyan