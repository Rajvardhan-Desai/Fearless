import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencySharingScreen extends StatefulWidget {
  final List<Map<String, String>> selectedContacts; // Dynamic contact list

  const EmergencySharingScreen({super.key, required this.selectedContacts});

  @override
  State<EmergencySharingScreen> createState() => _EmergencySharingScreenState();
}

class _EmergencySharingScreenState extends State<EmergencySharingScreen> {
  String? _liveLocationLink;
  bool _isSharing = true;

  @override
  void initState() {
    super.initState();
    _startLiveLocationSharing();
  }

  @override
  void dispose() {
    _stopLiveLocationSharing();
    super.dispose();
  }

  /// Generate Google Maps Live Location Link
  Future<void> _startLiveLocationSharing() async {
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
    setState(() {
      _isSharing = false;
    });
    // Implement logic to stop sharing in your app (e.g., updating backend state).
  }

  /// Initiate call to emergency contact
  Future<void> _makeCall(String number) async {
    final Uri phoneUri = Uri.parse('tel:$number');

    // Check for CALL_PHONE permission
    if (await Permission.phone.request().isGranted) {
      // Directly call using CALL_PHONE intent
      try {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication, // Ensures the call is placed directly
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to make a direct call')),
        );
      }
    } else {
      // Permission not granted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone call permission is not granted')),
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

    await showDialog(
      context: context,
      builder: (context) {
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
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                // Handle stopping sharing and notifying contacts
                if (reason != null && reason!.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reason sent: $reason')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
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
                    _makeCall(number);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number is missing or invalid')),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFF80AB), // Pink avatar color
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

                const Icon(Icons.share_location_sharp, color: Colors.white,size: 30,),
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
                    _showStopSharingDialog(context); // Pass the context explicitly
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D3A), // Red color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // Rounded corners
                    ),
                    minimumSize: const Size(150, 60), // Size for consistent button look
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
                    const emergencyNumber = 'tel:112';
                    launchUrl(Uri.parse(emergencyNumber));
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white), // White border
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50), // Rounded corners
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
