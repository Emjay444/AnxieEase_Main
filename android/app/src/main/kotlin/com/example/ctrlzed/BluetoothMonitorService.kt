package com.example.ctrlzed

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class BluetoothMonitorService : Service() {
    
    companion object {
        private const val TAG = "BluetoothMonitorService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bluetooth_monitor_channel"
        const val ACTION_START_MONITORING = "com.example.ctrlzed.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.example.ctrlzed.STOP_MONITORING"
    }
    
    private var deviceAddress: String? = null
    private var userId: String? = null
    private var monitoringJob: Job? = null
    private var notificationManager: NotificationManager? = null
    
    init {
        Log.d(TAG, "BluetoothMonitorService created")
        Log.d(TAG, "Native Bluetooth service initialized successfully")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🚀 BluetoothMonitorService: onStartCommand called")
        Log.d(TAG, "🚀 Intent: $intent")
        Log.d(TAG, "🚀 Action: ${intent?.action}")
        Log.d(TAG, "🚀 Flags: $flags, StartId: $startId")
        
        when (intent?.action) {
            ACTION_START_MONITORING -> {
                Log.d(TAG, "✅ BluetoothMonitorService: Starting monitoring action received")
                deviceAddress = intent.getStringExtra("deviceAddress")
                userId = intent.getStringExtra("userId")
                val deviceId = intent.getStringExtra("deviceId")
                
                Log.d(TAG, "📱 Device Address: $deviceAddress")
                Log.d(TAG, "👤 User ID: $userId")
                Log.d(TAG, "🔧 Device ID: $deviceId")
                
                startMonitoring()
            }
            ACTION_STOP_MONITORING -> {
                Log.d(TAG, "✅ BluetoothMonitorService: Stopping monitoring action received")
                stopMonitoring()
            }
        }
        
        Log.d(TAG, "🔄 BluetoothMonitorService: Returning START_STICKY")
        return START_STICKY
    }
    
    private fun startMonitoring() {
        Log.d(TAG, "🔍 BluetoothMonitorService: startMonitoring() called")
        Log.d(TAG, "🔍 Starting Bluetooth monitoring for device: $deviceAddress")
        
        createNotificationChannel()
        
        Log.d(TAG, "📳 Creating notification for foreground service...")
        val notification = createNotification("Background monitoring starting...")
        
        Log.d(TAG, "🚀 Starting foreground service with notification ID: $NOTIFICATION_ID")
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "✅ Foreground service started successfully!")
        
        Log.d(TAG, "🔄 Starting monitoring coroutine...")
        monitoringJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "🛡️ Background service running - monitoring will continue when app is closed")
                // Don't create a separate Bluetooth connection - let Flutter handle that
                // This service just ensures the process stays alive for background monitoring
                
                var lastUpdateTime = System.currentTimeMillis()
                while (!monitoringJob?.isCancelled!!) {
                    val currentTime = System.currentTimeMillis()
                    val timeSinceUpdate = currentTime - lastUpdateTime
                    
                    updateNotification("Background monitoring active - Running for ${timeSinceUpdate / 1000}s")
                    
                    // Keep the service alive with periodic updates
                    delay(30000) // Update every 30 seconds
                    lastUpdateTime = currentTime
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error in monitoring: ${e.message}")
                updateNotification("Monitoring error: ${e.message}")
            }
        }
        Log.d(TAG, "🔄 Monitoring coroutine started")
    }

    private fun stopMonitoring() {
        Log.d(TAG, "🔻 BluetoothMonitorService: stopMonitoring() called")
        
        monitoringJob?.cancel()
        monitoringJob = null
        
        stopForeground(true)
        stopSelf()
        Log.d(TAG, "✅ BluetoothMonitorService: Monitoring stopped")
    }
    
    private fun updateNotification(status: String) {
        if (notificationManager == null) {
            notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        }
        
        val notification = createNotification(status)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bluetooth Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background monitoring for IoT device"
                setShowBadge(false)
            }
            
            notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(status: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AnxieEase Background Monitor")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🔻 BluetoothMonitorService: onDestroy() called")
        stopMonitoring()
    }
}
