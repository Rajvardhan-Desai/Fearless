import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC1CC), // Light pink
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Text(
          'Emergency Sharing',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 10),
            // Dynamic List of Contacts
            ...widget.selectedContacts.map((contact) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFF80AB), // Pink avatar color
                    child: Text(
                      contact['name']!.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    contact['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Real-time location',
                  style: TextStyle(color: Colors.white, fontSize: 16),
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
            if (_liveLocationLink != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _liveLocationLink!,
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  _isSharing
                      ? '${TimeOfDay.now().format(context)} - Started Emergency Sharing'
                      : 'Stopped Emergency Sharing',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _stopLiveLocationSharing();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D77), // Red color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Call emergency number
                    const emergencyNumber = 'tel:112';
                    launchUrl(Uri.parse(emergencyNumber));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5), // Blue color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text(
                      'Call 112',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
