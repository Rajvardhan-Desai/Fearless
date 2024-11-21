package com.fearless.app

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

@TargetApi(Build.VERSION_CODES.CUPCAKE)
class ShakeService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var chopCount = 0
    private var lastChopTime = 0L

    @TargetApi(Build.VERSION_CODES.CUPCAKE)
    override fun onCreate() {
        super.onCreate()
        startInForeground()

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
    }

    private fun startInForeground() {
        val channelId = "ShakeServiceChannel"
        val channelName = "Shake Service Channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, channelName, NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Emergency Sharing Active")
            .setContentText("Listening for emergency gestures")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    @TargetApi(Build.VERSION_CODES.CUPCAKE)
    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        stopForeground(true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // Not used
    }

    override fun onSensorChanged(event: SensorEvent) {
        detectChopGesture(event)
    }

    private fun detectChopGesture(event: SensorEvent) {
        val z = event.values[2]
        val currentTime = System.currentTimeMillis()

        if (kotlin.math.abs(z) > 15) {
            if (currentTime - lastChopTime > 500) {
                chopCount++
                lastChopTime = currentTime
                Log.d("ShakeService", "Chop detected: Count = $chopCount")

                if (chopCount >= 3) {
                    chopCount = 0
                    Log.d("ShakeService", "Triggering emergency sharing")
                    triggerEmergencySharing()
                }
            }
        }
    }


    private fun triggerEmergencySharing() {
        val intent = Intent(this, MainActivity::class.java)
        intent.action = "TRIGGER_EMERGENCY_SHARING"
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed
    }
}
