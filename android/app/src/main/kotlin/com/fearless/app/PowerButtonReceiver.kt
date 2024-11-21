package com.fearless.app

import android.app.PendingIntent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs


class PowerButtonReceiver : BroadcastReceiver() {

    private var pressCount = 0
    private var lastPressTime: Long = 0
    private val interval: Long = 2000 // 2 seconds

    override fun onReceive(context: Context, intent: Intent) {
        val currentTime = System.currentTimeMillis()

        if (currentTime - lastPressTime > interval) {
            pressCount = 0
        }

        if (intent.action == Intent.ACTION_SCREEN_OFF || intent.action == Intent.ACTION_SCREEN_ON) {
            pressCount++
            if (pressCount == 3) {
                pressCount = 0

                // Log the detection
                Log.d("PowerButtonReceiver", "Triple power button press detected")

                // For Android 10 and above, use a notification to bring the app to the foreground
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    showNotification(context)
                } else {
                    // Start MainActivity directly for older Android versions
                    val activityIntent = Intent(context, MainActivity::class.java)
                    activityIntent.action = "TRIGGER_EMERGENCY_SHARING"
                    activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(activityIntent)
                }
            }
            lastPressTime = currentTime
        }
    }

    private fun showNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "emergency_notification_channel"

        // Create notification channel for Android O and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelName = "Emergency Notification"
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            action = "TRIGGER_EMERGENCY_SHARING"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle("Emergency Detected")
            .setContentText("Tap to open Fearless and trigger emergency sharing.")
            .setSmallIcon(R.drawable.ic_notification) // Use your app's icon
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(1, notification)
    }

}
