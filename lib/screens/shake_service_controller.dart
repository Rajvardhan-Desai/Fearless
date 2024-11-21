import 'package:flutter/services.dart';

class ShakeServiceController {
  static const platform = MethodChannel('com.fearless.app/sharing');

  static Future<void> startService() async {
    try {
      await platform.invokeMethod('startShakeService');
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
    }
  }

  static Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopShakeService');
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
    }
  }

  static void listenForEmergencySharing(Function callback) {
    platform.setMethodCallHandler((call) async {
      if (call.method == "emergencySharingTriggered") {
        callback();
      }
    });
  }
}
