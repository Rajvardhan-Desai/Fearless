package com.fearless.app

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CONTACT_CHANNEL = "com.fearless.contacts/choose"
    private val SMS_CHANNEL = "com.fearless.sms/send"
    private val REQUEST_CODE_PICK_CONTACT = 1

    private var resultCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Contact picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                resultCallback = result
                val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
            } else {
                result.notImplemented()
            }
        }

        // SMS sending channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message")

                if (phoneNumber != null && message != null) {
                    try {
                        val smsManager = SmsManager.getDefault()
                        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                        result.success("SMS sent to $phoneNumber")
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", "Failed to send SMS: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone number or message is missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                handleContactResult(data)
            } else {
                resultCallback?.error("CANCELED", "Contact picking was canceled", null)
            }
        }
    }

    private fun handleContactResult(data: Intent) {
        val contactUri: Uri = data.data ?: run {
            resultCallback?.error("INVALID_DATA", "Contact data is null", null)
            return
        }

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
                    "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                    arrayOf(id),
                    null
                )
                if (phoneCursor != null && phoneCursor.moveToFirst()) {
                    phoneNumber = phoneCursor.getString(phoneCursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER))
                    phoneCursor.close()
                }
            }

            cursor.close()

            if (!name.isNullOrEmpty() && !phoneNumber.isNullOrEmpty()) {
                val resultMap = mapOf("name" to name, "number" to phoneNumber)
                resultCallback?.success(resultMap)
            } else {
                resultCallback?.error("CONTACT_DATA_MISSING", "Contact name or phone number is missing", null)
            }
        } else {
            resultCallback?.error("QUERY_FAILED", "Failed to query contact", null)
        }
    }
}
