import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fearless/screens/profile_page.dart';
import 'package:fearless/screens/search_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import 'emergency_sharing_screen.dart';
import 'news_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final TextEditingController _reasonController = TextEditingController();
  late int _selectedIndex;
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  final TwilioFlutter twilioFlutter = TwilioFlutter(
    accountSid : dotenv.env['TWILIO_ACCOUNT_SID']!,
    authToken: dotenv.env['TWILIO_AUTH_TOKEN']!,
    twilioNumber: dotenv.env['TWILIO_NO']!,
  );

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    final userNotifier = ref.read(userProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await userNotifier.fetchUserData();

        setState(() {
          _isLoading = false;
        });
      } catch (error) {
        _showErrorSnackBar(error.toString());
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);

    final List<Widget> widgetOptions = [
      _isLoading ? _buildShimmerHomeContent() : _buildHomeContent(userState),
      const SearchPage(),
      const NewsPage(),
      ProfilePage(
        userName: userState.name,
        userEmail: userState.email,
        userImageUrl: userState.imageUrl,
        blurHash: userState.blurHash,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          'Fearless',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 22.0,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xff6f5172),
        automaticallyImplyLeading: false,
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Color(0xff6c5270)),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route_rounded, color: Color(0xff6c5270)),
          label: 'Search Route',
        ),
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper, color: Color(0xff6c5270)),
          label: 'News',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: Color(0xff6c5270)),
          label: 'Profile',
        ),
      ],
      backgroundColor: Colors.white,
      elevation: 5.0,
    );
  }

  Widget _buildShimmerHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 214,
                  height: 34.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 145.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 30.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 200.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Container(
                  width: 200,
                  height: 30.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 70.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 70.0,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 200.0,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(UserState userState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get help fast',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickAccess(),
          const SizedBox(height: 32),
          const Text(
            'Be prepared',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPreparednessTile(),
        ],
      ),
    );
  }

  // Call Emergency Number
  Future<void> _callEmergencyNumber() async {
    const emergencyNumber = '112';
    final Uri url = Uri(scheme: 'tel', path: emergencyNumber);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showErrorSnackBar('Unable to launch dialer.');
    }
  }

// Emergency tools UI
  Widget _buildQuickAccess() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.wifi_tethering,
            title: 'Emergency Sharing',
            onTap: () => _showEmergencySharingBottomSheet(),
          ),
        ),
        const SizedBox(width: 12), // Spacing between buttons
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone,
            title: 'Call 112',
            onTap: _showCallConfirmationDialog, // Show the confirmation dialog
          ),
        ),
      ],
    );
  }

  // Show Confirmation Dialog
  Future<void> _showCallConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Call 112?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to call emergency services?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _callEmergencyNumber();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('Call 112',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Preparedness UI
  Widget _buildPreparednessTile() {
    return _buildActionButton(
      icon: Icons.security,
      title: 'Safety Check',
      onTap: () {
        // Handle navigation
      },
    );
  }

  Future<List<Map<String, String>>> _fetchEmergencyContacts() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final phone = sanitizePhoneNumber(doc['phone'].toString());
        return {
          'id': doc.id.toString(),
          'name': doc['name'].toString(),
          'phone': phone,
        };
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch contacts.")),
      );
      return [];
    }
  }

  // Add below emergency contact list
  final List<Map<String, dynamic>> toggleOptions = [
    {
      'title': 'Phone call',
      'description': 'When you start and end a call',
      'value': true,
      'disabled': false, // Enabled
    },
    {
      'title': 'Emergency call',
      'description': 'When you start and end an emergency call',
      'value': true,
      'disabled': false, // Enabled
    },
    {
      'title': 'Low battery',
      'description': 'When your battery is below 15%',
      'value': false,
      'disabled': false, // Enabled
    },
    {
      'title': 'Real-time location',
      'description':
      'Required for Emergency Sharing. Uses Location Sharing in Google Maps.',
      'value': true,
      'disabled': true, // Always disabled
    },
  ];

  Widget _buildToggleOptions(
      BuildContext context, void Function(void Function()) setState) {
    return Column(
      children: toggleOptions.map((option) {
        // Extract fields and ensure correct types
        final String title = option['title'] as String;
        final String description = option['description'] as String;
        final bool value = option['value'] as bool;
        final bool isDisabled = option['disabled'] as bool;

        return SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDisabled
                  ? Colors.grey
                  : Colors.black, // Disabled items appear grey
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(
              color: isDisabled
                  ? Colors.grey
                  : Colors.black54, // Disabled subtitle text
            ),
          ),
          value: value,
          onChanged: isDisabled
              ? null // Prevent toggling if disabled
              : (bool newValue) {
            setState(() {
              option['value'] = newValue;
            });
          },
          activeColor: isDisabled
              ? Colors.grey
              : Colors.deepPurple, // Adjust toggle color
        );
      }).toList(),
    );
  }

// Modify the _showEmergencySharingBottomSheet method
  Future<void> _showEmergencySharingBottomSheet() async {
    final emergencyContacts = await _fetchEmergencyContacts();

    if (emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No emergency contacts available.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        final Map<String, bool> contactSelection = {
          for (var contact in emergencyContacts) contact['phone']!: true,
        };

        return StatefulBuilder(
          builder: (context, setState) {
            final bool anyContactSelected =
            contactSelection.values.any((isSelected) => isSelected);

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi_tethering,
                              color: Colors.red, size: 28),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Share status and real-time location?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                                color: Colors.black87,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Status updates and location will be shared with emergency contacts for 24 hours or until you stop sharing.',
                        style: TextStyle(fontSize: 14.0, color: Colors.black54),
                      ),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _reasonController,
                        maxLength: 40,
                        decoration: InputDecoration(
                          hintText: 'Reason for sharing (optional)',
                          counterText: '',
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Share with',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...emergencyContacts.map((contact) {
                        final phone = contact['phone']!;
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.pink,
                              child: Text(
                                contact['name']!.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact['name']!,
                                    style: const TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 12.0,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: contactSelection[phone],
                              onChanged: (value) {
                                setState(() {
                                  contactSelection[phone] = value ?? false;
                                });
                              },
                            ),
                          ],
                        );
                      }).toList(),
                      const SizedBox(height: 16),

                      // Add the toggle options below emergency contacts
                      const Text(
                        'Emergency Sharing Options',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildToggleOptions(context, setState),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: anyContactSelected
                                ? () async {
                              final String reason = _reasonController.text.trim();

                              // Prepare message
                              String emergencyMessage =
                                  "Emergency! Please help. Reason: ${reason.isNotEmpty ? reason : 'N/A'}.";

                              // Filter selected contacts
                              final List<Map<String, String>> selectedContacts =
                              contactSelection.entries
                                  .where((entry) => entry.value)
                                  .map((entry) {
                                final contact = emergencyContacts.firstWhere(
                                        (c) => c['phone'] == entry.key);
                                return {
                                  'name': contact['name']!,
                                  'phone': contact['phone']!,
                                };
                              }).toList();

                              // Navigate to EmergencySharingScreen immediately
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EmergencySharingScreen(
                                    selectedContacts: selectedContacts,
                                  ),
                                ),
                              );

                              // Send SMS in the background
                              sendEmergencySMSInBackground(
                                context: context,
                                message: emergencyMessage,
                                contacts: selectedContacts.map((e) => e['phone']!).toList(),
                              );
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff6f5172),
                            ),
                            child: const Text(
                              'Share',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String sanitizePhoneNumber(String phone) {
    phone = phone.replaceAll(' ', ''); // Remove all spaces
    if (!phone.startsWith('+91')) {
      phone = '+91$phone'; // Add country code if not present
    }
    return phone;
  }

  String generateGoogleMapsLink(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
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

  Future<void> sendEmergencySMSInBackground({
    required BuildContext context,
    required String message,
    required List<String> contacts,
  }) async {
    final position = await _getCurrentLocation();
    if (position != null) {
      final locationLink = generateGoogleMapsLink(position.latitude, position.longitude);
      message += "\nMy location: $locationLink";
    } else {
      message += "\nUnable to fetch location.";
    }

    // Run the SMS sending in the background
    Future.microtask(() async {
      try {
        for (String contact in contacts) {
          final sanitizedContact = sanitizePhoneNumber(contact);
          await twilioFlutter.sendSMS(
            toNumber: sanitizedContact,
            messageBody: message,
          );
          debugPrint("SMS sent to $sanitizedContact");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Emergency SMS sent successfully!")),
        );
      } catch (error) {
        debugPrint("Failed to send SMS: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send SMS.")),
        );
      }
    });
  }






// Reusable UI for each feature tile
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90.0, // Fixed height for uniformity
        margin: const EdgeInsets.symmetric(horizontal: 1.0), // Equal margins
        padding: const EdgeInsets.symmetric(horizontal: 12.0), // Inner padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              // Wraps the text dynamically
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true, // Allows text wrapping if needed
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}