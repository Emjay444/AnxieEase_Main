package com.example.ctrlzed

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.IOException
import java.util.*

/**
 * Enhanced Bluetooth Monitor Service with full IoT Gateway functionality
 * 
 * This service:
 * 1. Maintains persistent Bluetooth connection to IoT device
 * 2. Parses sensor data and uploads to Firebase
 * 3. Streams real-time data to Flutter via EventChannel
 * 4. Handles commands from Flutter via MethodChannel
 * 5. Continues operation when app is closed/killed
 */
class BluetoothIoTGatewayService : Service() {
    
    companion object {
        private const val TAG = "BluetoothIoTGateway"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bluetooth_iot_gateway_channel"
        
        // Actions
        const val ACTION_START_GATEWAY = "com.example.ctrlzed.START_GATEWAY"
        const val ACTION_STOP_GATEWAY = "com.example.ctrlzed.STOP_GATEWAY"
        const val ACTION_RECONNECT = "com.example.ctrlzed.RECONNECT"
        
        // Event Channel for streaming data to Flutter
        const val EVENT_CHANNEL_NAME = "com.example.ctrlzed/iot_data_stream"
        
        // Method Channel for commands from Flutter
        const val METHOD_CHANNEL_NAME = "com.example.ctrlzed/iot_gateway_control"
        
        // Bluetooth SPP UUID
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        
        // Static reference to service instance for EventSink communication
        private var serviceInstance: BluetoothIoTGatewayService? = null
        
        fun setEventSink(eventSink: EventChannel.EventSink?) {
            Log.d(TAG, "🔗 Setting EventSink: $eventSink")
            serviceInstance?.eventSink = eventSink
        }
        
        fun isServiceRunning(): Boolean {
            val instance = serviceInstance
            val isRunning = instance != null && instance.isConnected && instance.gatewayJob?.isActive == true
            Log.d(TAG, "🔍 Service running check: instance=$instance, connected=${instance?.isConnected}, jobActive=${instance?.gatewayJob?.isActive}, result=$isRunning")
            return isRunning
        }
    }
    
    // Service state
    private var deviceAddress: String? = null
    private var userId: String? = null
    private var deviceId: String? = null
    private var notificationManager: NotificationManager? = null
    
    // Bluetooth
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothDevice: BluetoothDevice? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var isConnected = false
    
    // Data processing
    private val dataBuffer = StringBuilder()
    private var gatewayJob: Job? = null
    private var reconnectJob: Job? = null
    
    // Firebase
    private lateinit var firebaseDatabase: FirebaseDatabase
    private var deviceRef: DatabaseReference? = null
    private var currentRef: DatabaseReference? = null
    
    // Flutter communication
    var eventSink: EventChannel.EventSink? = null
    var methodChannelHandler: ((method: String, args: Any?) -> Any?)? = null
    
    // Analytics
    private val heartRateWindow = mutableListOf<Double>()
    private var lastAlertTime: Long = 0
    private val heartRateWindowSize = 10
    private val alertCooldownMs = 5 * 60 * 1000L // 5 minutes
    
    // Data throttling to prevent Firebase flooding
    private var lastUploadedHeartRate: Double = 0.0
    private var lastUploadTime: Long = 0
    private val uploadThrottleMs = 5000L // Only upload every 5 seconds (was 10)
    private val heartRateChangeThreshold = 3.0 // Only upload if HR changes by 3+ bpm (was 5)
    
    init {
        Log.d(TAG, "BluetoothIoTGatewayService created")
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // Set service instance for static access
        serviceInstance = this
        Log.d(TAG, "📡 Service instance set for EventSink communication")
        
        // Initialize Bluetooth
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        
        // Initialize Firebase
        try {
            firebaseDatabase = FirebaseDatabase.getInstance()
            Log.d(TAG, "Firebase Database initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Firebase: ${e.message}")
        }
        
        Log.d(TAG, "Service created and initialized")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🚀 onStartCommand called with action: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_GATEWAY -> {
                deviceAddress = intent.getStringExtra("deviceAddress")
                userId = intent.getStringExtra("userId")
                deviceId = intent.getStringExtra("deviceId") ?: "AnxieEase001"
                
                Log.d(TAG, "📱 Starting IoT Gateway - Device: $deviceAddress, User: $userId")
                startIoTGateway()
            }
            ACTION_STOP_GATEWAY -> {
                Log.d(TAG, "🛑 Stopping IoT Gateway")
                stopIoTGateway()
            }
            ACTION_RECONNECT -> {
                Log.d(TAG, "🔄 Reconnecting to device")
                reconnectToDevice()
            }
        }
        
        return START_STICKY // Restart if killed
    }
    
    private fun startIoTGateway() {
        if (gatewayJob?.isActive == true) {
            Log.d(TAG, "Gateway already running")
            return
        }
        
        createNotificationChannel()
        val notification = createNotification("Starting IoT Gateway...")
        startForeground(NOTIFICATION_ID, notification)
        
        // Initialize Firebase references
        setupFirebaseReferences()
        
        // Start gateway coroutine
        gatewayJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "🚀 Starting IoT Gateway main loop")
                connectToDevice()
                
                if (isConnected) {
                    startDataReading()
                } else {
                    // Schedule reconnection
                    scheduleReconnection()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Gateway error: ${e.message}")
                updateNotification("Gateway error: ${e.message}")
                scheduleReconnection()
            }
        }
    }
    
    private fun stopIoTGateway() {
        gatewayJob?.cancel()
        reconnectJob?.cancel()
        
        // Close Bluetooth connection
        try {
            bluetoothSocket?.close()
            isConnected = false
            Log.d(TAG, "Bluetooth connection closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing Bluetooth connection: ${e.message}")
        }
        
        // Send disconnection event to Flutter
        sendEventToFlutter(mapOf(
            "type" to "connection_status",
            "connected" to false
        ))
        
        stopForeground(true)
        stopSelf()
    }
    
    private fun setupFirebaseReferences() {
        if (deviceId != null && userId != null) {
            deviceRef = firebaseDatabase.reference
                .child("devices")
                .child(deviceId!!)
            
            currentRef = firebaseDatabase.reference
                .child("devices")
                .child(deviceId!!)
                .child("current")
                
            Log.d(TAG, "Firebase references setup for device: $deviceId")
        }
    }
    
    private suspend fun connectToDevice() {
        deviceAddress?.let { address ->
            try {
                Log.d(TAG, "🔗 Connecting to device: $address")
                updateNotification("Connecting to device...")
                
                bluetoothDevice = bluetoothAdapter?.getRemoteDevice(address)
                bluetoothSocket = bluetoothDevice?.createRfcommSocketToServiceRecord(SPP_UUID)
                
                // Cancel discovery to improve connection speed
                bluetoothAdapter?.cancelDiscovery()
                
                bluetoothSocket?.connect()
                isConnected = true
                
                Log.d(TAG, "✅ Successfully connected to device")
                updateNotification("Connected - Monitoring sensor data")
                
                // Send connection event to Flutter
                sendEventToFlutter(mapOf(
                    "type" to "connection_status",
                    "connected" to true,
                    "deviceAddress" to address
                ))
                
            } catch (e: IOException) {
                Log.e(TAG, "Connection failed: ${e.message}")
                isConnected = false
                updateNotification("Connection failed - Will retry")
                
                // Try alternative connection method
                tryAlternativeConnection()
            }
        }
    }
    
    private suspend fun tryAlternativeConnection() {
        try {
            Log.d(TAG, "🔄 Trying alternative connection method")
            val method = bluetoothDevice?.javaClass?.getMethod("createRfcommSocket", Int::class.java)
            bluetoothSocket = method?.invoke(bluetoothDevice, 1) as BluetoothSocket?
            bluetoothSocket?.connect()
            isConnected = true
            
            Log.d(TAG, "✅ Alternative connection successful")
            updateNotification("Connected - Monitoring sensor data")
            
            sendEventToFlutter(mapOf(
                "type" to "connection_status",
                "connected" to true,
                "deviceAddress" to deviceAddress
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Alternative connection failed: ${e.message}")
            isConnected = false
            updateNotification("All connection attempts failed")
        }
    }
    
    private suspend fun startDataReading() {
        val inputStream = bluetoothSocket?.inputStream
        val buffer = ByteArray(1024)
        
        Log.d(TAG, "📡 Starting data reading loop")
        
        while (isConnected && gatewayJob?.isActive == true) {
            try {
                val bytesRead = inputStream?.read(buffer) ?: 0
                if (bytesRead > 0) {
                    val receivedData = String(buffer, 0, bytesRead)
                    
                    // Add received data to buffer
                    dataBuffer.append(receivedData)
                    
                    // Process complete JSON objects from buffer
                    processBufferedData()
                    
                    updateNotification("Active - Last data: ${System.currentTimeMillis()}")
                }
                
                // Small delay to prevent excessive CPU usage
                delay(100)
                
            } catch (e: IOException) {
                Log.e(TAG, "Error reading data: ${e.message}")
                isConnected = false
                
                // Send disconnection event
                sendEventToFlutter(mapOf(
                    "type" to "connection_status",
                    "connected" to false
                ))
                
                // Schedule reconnection
                scheduleReconnection()
                break
            }
        }
    }
    
    private fun processBufferedData() {
        val bufferContent = dataBuffer.toString()
        
        // Find all complete JSON objects in the buffer
        var searchIndex = 0
        while (searchIndex < bufferContent.length) {
            val jsonStart = bufferContent.indexOf('{', searchIndex)
            if (jsonStart == -1) break
            
            // Count braces to find the matching closing brace
            var braceCount = 0
            var jsonEnd = -1
            for (i in jsonStart until bufferContent.length) {
                when (bufferContent[i]) {
                    '{' -> braceCount++
                    '}' -> {
                        braceCount--
                        if (braceCount == 0) {
                            jsonEnd = i
                            break
                        }
                    }
                }
            }
            
            if (jsonEnd == -1) {
                // Incomplete JSON, keep remaining data in buffer starting from jsonStart
                if (jsonStart > 0) {
                    dataBuffer.delete(0, jsonStart)
                }
                break
            }
            
            // Extract and process complete JSON object
            val jsonString = bufferContent.substring(jsonStart, jsonEnd + 1)
            processReceivedData(jsonString)
            
            searchIndex = jsonEnd + 1
        }
        
        // Remove all processed data from buffer
        if (searchIndex > 0) {
            dataBuffer.delete(0, searchIndex)
        }
        
        // Prevent buffer from growing too large
        if (dataBuffer.length > 1024) {
            Log.w(TAG, "Buffer too large (${dataBuffer.length}), clearing")
            dataBuffer.clear()
        }
    }
    
    private fun processReceivedData(data: String) {
        try {
            Log.d(TAG, "📊 Processing IoT data: $data")
            
            // Parse JSON data
            val jsonObject = JSONObject(data)
            
            // Extract sensor values
            val heartRate = jsonObject.optDouble("heartRate", 0.0)
            val spo2 = jsonObject.optDouble("spo2", 0.0)
            val bodyTemp = jsonObject.optDouble("bodyTemp", 0.0)
            val ambientTemp = jsonObject.optDouble("ambientTemp", 0.0)
            val batteryPerc = jsonObject.optDouble("battPerc", 0.0)
            val worn = jsonObject.optInt("worn", 0) == 1
            val timestamp = System.currentTimeMillis()
            
            // Create structured data
            val sensorData = mapOf(
                "heartRate" to heartRate,
                "spo2" to spo2,
                "bodyTemperature" to bodyTemp,
                "ambientTemperature" to ambientTemp,
                "batteryLevel" to batteryPerc,
                "isDeviceWorn" to worn,
                "timestamp" to timestamp,
                "deviceAddress" to deviceAddress,
                "userId" to userId,
                "source" to "native_gateway"
            )
            
            // Send to Firebase
            uploadToFirebase(sensorData)
            
            // Send to Flutter
            sendEventToFlutter(mapOf(
                "type" to "sensor_data",
                "data" to sensorData
            ))
            
            // Perform anxiety detection
            if (heartRate > 0) {
                performAnxietyDetection(heartRate, sensorData)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing data: ${e.message}")
        }
    }
    
    private fun uploadToFirebase(data: Map<String, Any?>) {
        try {
            val currentTime = System.currentTimeMillis()
            val heartRate = (data["heartRate"] as? Number)?.toDouble() ?: 0.0
            
            // THROTTLING: Only upload if significant change or time interval passed
            val timeSinceLastUpload = currentTime - lastUploadTime
            val heartRateChange = Math.abs(heartRate - lastUploadedHeartRate)
            
            val shouldUpload = when {
                // Always upload first reading
                lastUploadTime == 0L -> true
                
                // Upload if significant heart rate change (5+ bpm)
                heartRateChange >= heartRateChangeThreshold -> true
                
                // Upload if enough time has passed (5 seconds)
                timeSinceLastUpload >= uploadThrottleMs -> true
                
                // Upload if crossing severity thresholds (85, 100, 120)
                (lastUploadedHeartRate < 85 && heartRate >= 85) ||
                (lastUploadedHeartRate < 100 && heartRate >= 100) ||
                (lastUploadedHeartRate < 120 && heartRate >= 120) ||
                (lastUploadedHeartRate >= 120 && heartRate < 120) ||
                (lastUploadedHeartRate >= 100 && heartRate < 100) ||
                (lastUploadedHeartRate >= 85 && heartRate < 85) -> true
                
                else -> false
            }
            
            if (!shouldUpload) {
                Log.d(TAG, "⏭️ Skipping upload - HR: $heartRate (change: ${heartRateChange.toInt()}bpm, time: ${timeSinceLastUpload/1000}s)")
                return
            }
            
            val timestamp = System.currentTimeMillis()
            
            // Upload to current data reference
            currentRef?.child("sensors")?.setValue(data)
            currentRef?.child("device")?.setValue(mapOf(
                "batteryLevel" to data["batteryLevel"],
                "isConnected" to true,
                "lastUpdate" to timestamp
            ))
            
            // Upload to metrics for historical data
            deviceRef?.child("Metrics")?.setValue(data)
            
            // Update throttling trackers
            lastUploadedHeartRate = heartRate
            lastUploadTime = currentTime
            
            Log.d(TAG, "📤 Data uploaded to Firebase - HR: $heartRate (change: ${heartRateChange.toInt()}bpm)")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to upload to Firebase: ${e.message}")
        }
    }
    
    private fun performAnxietyDetection(heartRate: Double, sensorData: Map<String, Any?>) {
        // Add to heart rate window
        heartRateWindow.add(heartRate)
        if (heartRateWindow.size > heartRateWindowSize) {
            heartRateWindow.removeAt(0)
        }
        
        // Calculate average and determine severity
        if (heartRateWindow.size >= 3) {
            val avgHeartRate = heartRateWindow.average()
            val severity = when {
                avgHeartRate >= 120 -> "severe"
                avgHeartRate >= 100 -> "moderate"
                avgHeartRate >= 85 -> "mild"
                else -> "normal"
            }
            
            // Check if alert should be logged (but don't write to Firebase alerts anymore)
            val currentTime = System.currentTimeMillis()
            if (severity != "normal" && (currentTime - lastAlertTime) > alertCooldownMs) {
                
                // Log the detection (app will handle notifications from reading heart rate data)
                lastAlertTime = currentTime
                Log.d(TAG, "🚨 Anxiety severity detected: $severity (HR: $avgHeartRate) - App will handle notifications")
            }
        }
    }
    
    private fun sendEventToFlutter(data: Map<String, Any?>) {
        try {
            eventSink?.success(data)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter: ${e.message}")
        }
    }
    
    private fun scheduleReconnection() {
        reconnectJob?.cancel()
        reconnectJob = CoroutineScope(Dispatchers.IO).launch {
            delay(5000) // Wait 5 seconds before reconnecting
            
            if (gatewayJob?.isActive == true) {
                Log.d(TAG, "🔄 Attempting automatic reconnection...")
                connectToDevice()
                
                if (isConnected) {
                    startDataReading()
                } else {
                    // Recursive retry
                    scheduleReconnection()
                }
            }
        }
    }
    
    private fun reconnectToDevice() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Close existing connection
                bluetoothSocket?.close()
                isConnected = false
                
                // Wait a moment
                delay(1000)
                
                // Reconnect
                connectToDevice()
                
                if (isConnected && gatewayJob?.isActive == true) {
                    startDataReading()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Manual reconnection failed: ${e.message}")
            }
        }
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
                "IoT Gateway Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Bluetooth IoT Gateway for continuous sensor monitoring"
                setShowBadge(false)
            }
            
            notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(status: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AnxieEase IoT Gateway")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🔻 Service destroyed")
        
        // Clear service instance
        serviceInstance = null
        
        gatewayJob?.cancel()
        reconnectJob?.cancel()
        
        try {
            bluetoothSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing socket in onDestroy: ${e.message}")
        }
    }
}
