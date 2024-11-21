package com.fearless.app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.view.FlutterMain
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {

    companion object {
        lateinit var flutterEngine: FlutterEngine
    }

    override fun onCreate() {
        super.onCreate()

        // Initialize the Flutter engine
        flutterEngine = FlutterEngine(this)

        // Start executing Dart code to pre-warm the FlutterEngine.
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Cache the FlutterEngine to be used by FlutterActivity.
        FlutterEngineCache
            .getInstance()
            .put("my_flutter_engine", flutterEngine)
    }
}

