#!/bin/bash

# 🚀 DEPLOY AUTO-CLEANUP FIREBASE FUNCTIONS
# 
# This script deploys the auto-cleanup functions to Firebase

echo "🔥 Deploying Auto-Cleanup Firebase Functions..."
echo "============================================="

# Navigate to functions directory
cd functions

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build TypeScript
echo "🔧 Building TypeScript..."
npm run build

# Deploy specific functions (optional - deploy only cleanup functions)
echo "🚀 Deploying auto-cleanup functions..."
firebase deploy --only functions:autoCleanup,functions:manualCleanup,functions:getCleanupStats

echo ""
echo "✅ Auto-Cleanup Functions Deployed!"
echo "=================================="
echo ""
echo "📋 Available Functions:"
echo "1. autoCleanup - Scheduled daily cleanup (2 AM UTC)"
echo "2. manualCleanup - On-demand cleanup via HTTP"
echo "3. getCleanupStats - View cleanup history and statistics"
echo ""
echo "🔗 Function URLs:"
echo "Manual cleanup: https://us-central1-anxieease-sensors.cloudfunctions.net/manualCleanup"
echo "Cleanup stats: https://us-central1-anxieease-sensors.cloudfunctions.net/getCleanupStats"
echo ""
echo "⏰ Scheduled cleanup runs daily at 2 AM UTC automatically."
echo "💡 Test manual cleanup first to ensure everything works correctly."