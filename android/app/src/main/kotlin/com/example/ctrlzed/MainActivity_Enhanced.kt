package com.example.ctrlzed

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    private lateinit var iotEventChannel: EventChannel
    private lateinit var iotMethodChannel: MethodChannel
    private var iotEventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup EventChannel for streaming IoT data from service to Flutter
        iotEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BluetoothIoTGatewayService.EVENT_CHANNEL_NAME
        )
        
        iotEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "📡 EventChannel: Flutter started listening for IoT data")
                iotEventSink = events
                // Connect the service's event sink to this one
                // This will be handled when the service is running
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "📡 EventChannel: Flutter stopped listening for IoT data")
                iotEventSink = null
            }
        })
        
        // Setup MethodChannel for commands from Flutter to service
        iotMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BluetoothIoTGatewayService.METHOD_CHANNEL_NAME
        )
        
        iotMethodChannel.setMethodCallHandler { call, result ->
            Log.d(TAG, "📞 MethodChannel call received: ${call.method}")
            
            when (call.method) {
                "startIoTGateway" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val userId = call.argument<String>("userId")
                    val deviceId = call.argument<String>("deviceId") ?: "AnxieEase001"
                    
                    Log.d(TAG, "🚀 Starting IoT Gateway: device=$deviceAddress, user=$userId")
                    
                    if (deviceAddress != null && userId != null) {
                        val success = startIoTGatewayService(deviceAddress, userId, deviceId)
                        result.success(success)
                    } else {
                        Log.e(TAG, "❌ Missing required parameters for startIoTGateway")
                        result.error("INVALID_ARGS", "Missing deviceAddress or userId", null)
                    }
                }
                
                "stopIoTGateway" -> {
                    Log.d(TAG, "🛑 Stopping IoT Gateway")
                    val success = stopIoTGatewayService()
                    result.success(success)
                }
                
                "reconnectDevice" -> {
                    Log.d(TAG, "🔄 Reconnecting device")
                    val success = reconnectIoTGateway()
                    result.success(success)
                }
                
                "sendDeviceCommand" -> {
                    val command = call.argument<String>("command")
                    Log.d(TAG, "📤 Sending device command: $command")
                    // This would be forwarded to the service for device-specific commands
                    // like vibration, LED control, etc.
                    result.success(true)
                }
                
                "getGatewayStatus" -> {
                    // Return current gateway status
                    // This could query the service for current state
                    val status = mapOf(
                        "isRunning" to true, // This would be determined by checking service state
                        "isConnected" to true,
                        "deviceAddress" to "XX:XX:XX:XX:XX:XX"
                    )
                    result.success(status)
                }
                
                else -> {
                    Log.w(TAG, "⚠️ Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
        
        Log.d(TAG, "✅ Flutter engine configured with IoT Gateway channels")
    }
    
    private fun startIoTGatewayService(deviceAddress: String, userId: String, deviceId: String): Boolean {
        return try {
            Log.d(TAG, "🚀 Creating IoT Gateway service intent...")
            
            val intent = Intent(this, BluetoothIoTGatewayService::class.java).apply {
                action = BluetoothIoTGatewayService.ACTION_START_GATEWAY
                putExtra("deviceAddress", deviceAddress)
                putExtra("userId", userId)
                putExtra("deviceId", deviceId)
            }
            
            Log.d(TAG, "📱 Device: $deviceAddress, User: $userId, ID: $deviceId")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "📱 Android O+, starting foreground service...")
                startForegroundService(intent)
            } else {
                Log.d(TAG, "📱 Android < O, starting regular service...")
                startService(intent)
            }
            
            Log.d(TAG, "✅ IoT Gateway service start command sent")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting IoT Gateway service: ${e.message}", e)
            false
        }
    }
    
    private fun stopIoTGatewayService(): Boolean {
        return try {
            val intent = Intent(this, BluetoothIoTGatewayService::class.java).apply {
                action = BluetoothIoTGatewayService.ACTION_STOP_GATEWAY
            }
            
            startService(intent)
            Log.d(TAG, "✅ IoT Gateway stop command sent")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping IoT Gateway service: ${e.message}", e)
            false
        }
    }
    
    private fun reconnectIoTGateway(): Boolean {
        return try {
            val intent = Intent(this, BluetoothIoTGatewayService::class.java).apply {
                action = BluetoothIoTGatewayService.ACTION_RECONNECT
            }
            
            startService(intent)
            Log.d(TAG, "✅ IoT Gateway reconnect command sent")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reconnecting IoT Gateway: ${e.message}", e)
            false
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "📱 MainActivity created")
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📱 MainActivity resumed")
        
        // When the app comes to foreground, we could request current status
        // from the service and update the UI accordingly
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "📱 MainActivity paused")
        
        // The IoT Gateway service should continue running in the background
        // even when the activity is paused
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📱 MainActivity destroyed")
        
        // NOTE: We do NOT stop the IoT Gateway service here
        // It should continue running independently of the UI
    }
}
