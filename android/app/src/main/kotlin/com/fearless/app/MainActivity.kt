package com.fearless.app

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.ContactsContract
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_CONTACT = "com.fearless.app/choose"
    private val REQUEST_CODE_PICK_CONTACT = 1

    private val CHANNEL_SHARING = "com.fearless.app/sharing"
    private val CHANNEL_POWER_BUTTON = "com.fearless.app/powerbutton"

    private var resultCallback: MethodChannel.Result? = null
    private var methodChannelSharing: MethodChannel? = null
    private var methodChannelPowerButton: MethodChannel? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return FlutterEngineCache.getInstance().get("my_flutter_engine")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Retrieve the cached FlutterEngine
        val flutterEngine = FlutterEngineCache.getInstance().get("my_flutter_engine")
        if (flutterEngine != null) {
            setupMethodChannels(flutterEngine)
        } else {
            // Handle the case where the FlutterEngine is null
            Log.e("MainActivity", "FlutterEngine is null")
        }

        // Handle the intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Use the cached engine
        super.configureFlutterEngine(MyApplication.flutterEngine)

        // Initialize method channels using the cached engine
        setupMethodChannels(MyApplication.flutterEngine)
    }



    private fun setupMethodChannels(flutterEngine: FlutterEngine) {
        // Method channel for contact picker
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CONTACT).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                resultCallback = result
                val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
            } else {
                result.notImplemented()
            }
        }

        // Method channel for emergency sharing
        methodChannelSharing = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SHARING)
        methodChannelSharing?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startShakeService" -> {
                    val serviceIntent = Intent(this, ShakeService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                "stopShakeService" -> {
                    val serviceIntent = Intent(this, ShakeService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Method channel for power button detection
        methodChannelPowerButton = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_POWER_BUTTON)
        methodChannelPowerButton?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPowerButtonService" -> {
                    val serviceIntent = Intent(this, PowerButtonService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                "stopPowerButtonService" -> {
                    val serviceIntent = Intent(this, PowerButtonService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val packageName = packageName
                    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnoring)
                }
                else -> result.notImplemented()
            }
        }
    }




    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.action == "TRIGGER_EMERGENCY_SHARING") {
            // Notify Flutter about the event
            Log.d("MainActivity", "Triple power button press detected, triggering emergency sharing")
            methodChannelSharing?.invokeMethod("emergencySharingTriggered", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_CONTACT && resultCode == Activity.RESULT_OK && data != null) {
            val contactUri: Uri = data.data!!
            val cursor: Cursor? = contentResolver.query(contactUri, null, null, null, null)

            if (cursor != null && cursor.moveToFirst()) {
                val id = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val name = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME))

                var phoneNumber: String? = null
                val hasPhoneNumber = cursor.getInt(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.HAS_PHONE_NUMBER)) > 0
                if (hasPhoneNumber) {
                    val phoneCursor = contentResolver.query(
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        null,
                        ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                        arrayOf(id),
                        null
                    )
                    if (phoneCursor != null && phoneCursor.moveToFirst()) {
                        phoneNumber = phoneCursor.getString(phoneCursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER))
                        phoneCursor.close()
                    }
                }

                cursor.close()

                val resultMap = mapOf("name" to name, "number" to (phoneNumber ?: ""))
                resultCallback?.success(resultMap)
            } else {
                resultCallback?.error("PICK_CONTACT_FAILED", "Failed to pick contact", null)
            }
        } else {
            resultCallback?.error("CANCELED", "Contact picking was canceled", null)
        }
    }
}
