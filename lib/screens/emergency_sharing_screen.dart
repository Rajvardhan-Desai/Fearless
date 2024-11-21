import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

import 'home_screen.dart';

class EmergencySharingScreen extends ConsumerStatefulWidget {
  final List<Map<String, String>> selectedContacts; // Dynamic contact list
  final List selectedOptions;
  final String reason;

  const EmergencySharingScreen({
    super.key,
    required this.selectedContacts,
    required this.selectedOptions,
    required this.reason,
  });

  @override
  EmergencySharingScreenState createState() => EmergencySharingScreenState();
}

class EmergencySharingScreenState
    extends ConsumerState<EmergencySharingScreen> {
  String? _liveLocationLink;
  bool _isSharing = true;
  late final userState;
  int chopCount = 0;
  bool isChopDetecting = false;
  bool lowBatteryAlertSent = false;

  StreamSubscription<Position>? positionStream;

  final TwilioFlutter twilioFlutter = TwilioFlutter(
    accountSid: dotenv.env['TWILIO_ACCOUNT_SID']!,
    authToken: dotenv.env['TWILIO_AUTH_TOKEN']!,
    twilioNumber: dotenv.env['TWILIO_NO']!,
  );

  @override
  void initState() {
    super.initState();
    _startLiveLocationSharing();
    monitorBatteryLevel(); // Start monitoring battery level

    sendEmergencySMSInBackground(
      contacts: widget.selectedContacts.map((c) => c['phone']!).toList(),
      message:
          "\nYou're receiving this message because you're an emergency contact for ${userState.name}.",
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize userState here safely
    userState = ref.watch(userProvider);
  }

  @override
  void dispose() {
    _stopLiveLocationSharing();
    positionStream?.cancel(); // Cancel the stream if active
    super.dispose();
  }

  /// Generate Google Maps Live Location Link
  Future<void> _startLiveLocationSharing() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _liveLocationLink = 'Location permission denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _liveLocationLink = 'Location permissions are permanently denied.';
      });
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _liveLocationLink =
            'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      });
    } catch (e) {
      setState(() {
        _liveLocationLink = 'Unable to fetch location. Check permissions.';
      });
    }
  }

  /// Stop Live Location Sharing
  void _stopLiveLocationSharing() {
    if (mounted) {
      setState(() {
        _isSharing = false;
      });
    } else {
      _isSharing = false; // Update the variable directly without setState
    }
  }

  /// Initiate call to emergency contact
  Future<void> _makeCall(String number) async {
    final Uri phoneUri = Uri.parse('tel:$number');
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to make a call')),
      );
    }
  }

  /// Show confirmation dialog to stop sharing
  Future<void> _showStopSharingDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              color: Colors.black, // Dark background for the dialog
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Stop sharing?',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Text color
                  ),
                ),
                const SizedBox(height: 10.0),
                const Text(
                  'Your emergency contacts will no longer see your real-time location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white70, // Subtitle text color
                  ),
                ),
                const SizedBox(height: 20.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[800], // Dark gray button
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white, // Button text color
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue, // Highlighted button
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Stop sharing',
                        style: TextStyle(
                          color: Colors.white, // Button text color
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      _showSafetyConfirmationDialog(context);
    }
  }

  /// Show safety confirmation dialog
  Future<void> _showSafetyConfirmationDialog(BuildContext context) async {
    String? reason;
    bool isDoneEnabled = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212), // Dark background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Confirm that you\'re safe',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tell your emergency contacts why you\'ve stopped sharing',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLength: 40,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a reason',
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      counterText: '',
                    ),
                    onChanged: (value) {
                      reason = value;
                      setState(() {
                        isDoneEnabled = value.trim().isNotEmpty;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Stop sharing and notify contacts without a reason
                    sendEmergencySMSInBackground(
                      message:
                          '\n${userState.name} has stopped sharing their location.',
                      contacts: widget.selectedContacts
                          .map((c) => c['phone']!)
                          .toList(),
                    );

                    // Navigate to home screen
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const HomeScreen(triggerEmergencySharing: false)),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDoneEnabled
                      ? () {
                          // Stop sharing and notify contacts with a reason
                          sendEmergencySMSInBackground(
                            message:
                                '\n${userState.name} has stopped sharing their location.',
                            contacts: widget.selectedContacts
                                .map((c) => c['phone']!)
                                .toList(),
                            reason: reason,
                          );

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen(
                                    triggerEmergencySharing: false)),
                            (route) => false,
                          );

                          // Navigate to home screen
                          //   Navigator.pushNamedAndRemoveUntil(
                          //       context, '/home', (route) => false);
                          //
                        }
                      : null,
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return null;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever
      return null;
    }

    // Get the current location
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String generateGoogleMapsLink(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  String sanitizePhoneNumber(String phone) {
    phone = phone.replaceAll(' ', ''); // Remove all spaces
    if (!phone.startsWith('+91')) {
      phone = '+91$phone'; // Add country code if not present
    }
    return phone;
  }

  Future<void> sendEmergencySMSInBackground({
    required String message,
    required List<String> contacts,
    String? reason,
  }) async {
    final position = await _getCurrentLocation();
    if (position != null) {
      final locationLink =
          generateGoogleMapsLink(position.latitude, position.longitude);
      message += "\nLocation: $locationLink";
    } else {
      message += "\nUnable to fetch location.";
    }

    if (reason != null && reason.isNotEmpty) {
      message += "\nReason: $reason";
    }

    // Offload SMS sending to a background isolate
    try {
      final result = await compute(
          _sendBulkSMS, {'contacts': contacts, 'message': message});
      if (result['success'] == contacts.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "SMS sent successfully to ${contacts.length} contacts!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "SMS sent to ${result['success']} out of ${contacts.length} contacts. Errors: ${result['errors']}",
            ),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to send SMS due to an unexpected error.")),
      );
      debugPrint("Error sending SMS: $error");
    }
  }

  Map<String, dynamic> _sendBulkSMS(Map<String, dynamic> args) {
    final contacts = args['contacts'] as List<String>;
    final message = args['message'] as String;
    int successCount = 0;
    List<String> errors = [];

    final twilioFlutter = TwilioFlutter(
      accountSid: dotenv.env['TWILIO_ACCOUNT_SID']!,
      authToken: dotenv.env['TWILIO_AUTH_TOKEN']!,
      twilioNumber: dotenv.env['TWILIO_NO']!,
    );

    for (String contact in contacts) {
      try {
        final sanitizedContact = sanitizePhoneNumber(contact);
        twilioFlutter.sendSMS(toNumber: sanitizedContact, messageBody: message);
        successCount++;
      } catch (error) {
        errors.add(contact);
      }
    }

    return {
      'success': successCount,
      'errors': errors,
    };
  }

  void handleActions(String actionType) async {
    if (actionType == "phone_call" &&
        widget.selectedOptions.contains("Phone call")) {
      // Send SMS for phone call
      String message =
          '\nEmergency alert!\n${userState.name} is contacting you as an emergency contact.';
      List<String> contacts =
          widget.selectedContacts.map((c) => c['phone']!).toList();
      sendEmergencySMSInBackground(
          message: message, contacts: contacts, reason: widget.reason);
    }

    if (actionType == "emergency_call" &&
        widget.selectedOptions.contains("Emergency call")) {
      // Send SMS for emergency call
      String message =
          '\nEmergency alert!\n${userState.name} is calling emergency services.';
      List<String> contacts =
          widget.selectedContacts.map((c) => c['phone']!).toList();
      sendEmergencySMSInBackground(
          message: message, contacts: contacts, reason: widget.reason);

      // Proceed to call emergency services
      const emergencyNumber = '112';
      launchUrl(Uri.parse('tel:$emergencyNumber'));
    }

    if (actionType == "low_battery" &&
        widget.selectedOptions.contains("Low battery")) {
      // Send SMS for low battery alert
      String message =
          "\nAlert: ${userState.name}'s phone battery is below 15%.";
      List<String> contacts =
          widget.selectedContacts.map((c) => c['phone']!).toList();
      sendEmergencySMSInBackground(message: message, contacts: contacts);
    }
  }

  Future<int> getBatteryLevel() async {
    final battery = Battery();
    return await battery.batteryLevel;
  }

  void monitorBatteryLevel() async {
    final battery = Battery();
    battery.onBatteryStateChanged.listen((BatteryState state) async {
      if (state == BatteryState.discharging && !lowBatteryAlertSent) {
        int batteryLevel = await battery.batteryLevel;
        if (batteryLevel <= 15) {
          handleActions("low_battery");
          lowBatteryAlertSent = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF2D3A),
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Text(
          'Emergency Sharing',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sharing with',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18.0,
              ),
            ),
            const SizedBox(height: 10),
            // Dynamic List of Contacts
            ...widget.selectedContacts.map((contact) {
              return GestureDetector(
                onTap: () {
                  final number = contact['phone'];
                  if (number != null && number.isNotEmpty) {
                    handleActions("phone_call");
                    _makeCall(number);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Phone number is missing or invalid')),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            const Color(0xFFFF80AB), // Pink avatar color
                        child: Text(
                          contact['name']!.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact['phone']!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            const Text(
              'Sharing',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18.0,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.share_location_sharp,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 20),
                const Text(
                  'Real-time location',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.blueAccent),
                  onPressed: _liveLocationLink != null
                      ? () {
                          // Open Google Maps link
                          launchUrl(Uri.parse(_liveLocationLink!));
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  _isSharing
                      ? '${TimeOfDay.now().format(context)} - Started Emergency Sharing'
                      : 'Stopped Emergency Sharing',
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stop Button
                ElevatedButton(
                  onPressed: () {
                    _showStopSharingDialog(
                        context); // Pass the context explicitly
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D3A), // Red color
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30), // Rounded corners
                    ),
                    minimumSize:
                        const Size(150, 60), // Size for consistent button look
                    elevation: 2, // Slight elevation for the button
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, color: Colors.white), // Close icon
                      SizedBox(width: 8),
                      Text(
                        'Stop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Call 112 Button
                OutlinedButton(
                  onPressed: () {
                    // Call emergency number
                    handleActions("emergency_call");
                    const emergencyNumber = 'tel:112';
                    launchUrl(Uri.parse(emergencyNumber));
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white), // White border
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(50), // Rounded corners
                    ),
                    minimumSize: const Size(150, 60), // Consistent button size
                    foregroundColor: Colors.white, // Text/Icon color
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, color: Colors.white), // Phone icon
                      SizedBox(width: 8),
                      Text(
                        'Call 112',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
