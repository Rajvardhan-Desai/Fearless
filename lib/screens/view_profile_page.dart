import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ViewProfilePage extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const ViewProfilePage({super.key, required this.userProfile});

  @override
  ViewProfilePageState createState() => ViewProfilePageState();
}

class ViewProfilePageState extends State<ViewProfilePage> {
  late final Map<String, dynamic> userProfile;

  @override
  void initState() {
    super.initState();
    // Safely cast the user profile map
    userProfile = Map<String, dynamic>.from(widget.userProfile);

    // Explicitly cast the visibility map
    if (userProfile['visibility'] is Map) {
      userProfile['visibility'] = Map<String, bool>.from(
        Map<String, dynamic>.from(userProfile['visibility']),
      );
    }
  }

  Future<void> _launchEmail(String? email) async {
    if (email == null || email.isEmpty) {
      _showError('Email address is not available.');
      return;
    }
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showError('No email app found. Please install an email app.');
      }
    } catch (error) {
      _showError(
          'Could not launch email app. Please check your email settings.');
    }
  }

  Future<void> _launchDialer(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showError('Phone number is not available.');
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showError('No dialer app found. Please install a phone app.');
      }
    } catch (error) {
      _showError('Could not launch dialer. Please check your phone settings.');
    }
  }

  Future<void> _launchWhatsApp(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showError('Phone number is not available.');
      return;
    }
    final Uri whatsappUri = Uri.parse("https://wa.me/$phoneNumber");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        _showError('No WhatsApp app found. Please install WhatsApp.');
      }
    } catch (error) {
      _showError(
          'Could not launch WhatsApp. Please check your WhatsApp settings.');
    }
  }

  Future<void> _launchLinkedIn(String? linkedin) async {
    if (linkedin == null || linkedin.isEmpty) {
      _showError('LinkedIn profile is not available.');
      return;
    }
    final Uri linkedInUri = Uri.parse(linkedin);
    try {
      if (await canLaunchUrl(linkedInUri)) {
        await launchUrl(linkedInUri);
      } else {
        _showError('No LinkedIn app found. Please install LinkedIn.');
      }
    } catch (error) {
      _showError(
          'Could not launch LinkedIn. Please check your LinkedIn settings.');
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildProfileTile(BuildContext context, IconData icon, String title,
      String? subtitle, bool isVisible,
      {void Function()? onTap}) {
    if (!isVisible || subtitle == null || subtitle.isEmpty) {
      return const SizedBox
          .shrink(); // Return an empty widget if not visible or if subtitle is null/empty
    }
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 18),
          ),
          onTap: onTap,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 55.0),
          child: Divider(thickness: 0.5),
        ),
      ],
    );
  }

  Widget _buildIconButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isVisible = true}) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade500),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: const Color(0xffa57eff)),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = userProfile['uid'] ?? 'unknown';
    final String name = userProfile['name'] ?? 'No Name';

    // Safe casting of the visibility map
    final Map<String, bool> visibility = userProfile['visibility'] ?? {};

    // Check if any of the icon buttons are visible
    final bool areAnyButtonsVisible = (visibility['phone'] ?? true) ||
        (visibility['email'] ?? true) ||
        (visibility['linkedin'] ?? true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff986ae7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Hero(
                  tag: 'profileImage-$uid',
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: userProfile['imageUrl'] != null
                        ? NetworkImage(userProfile['imageUrl'])
                        : null,
                    child: userProfile['imageUrl'] == null
                        ? const Icon(Icons.person_outline, size: 60)
                        : null,
                  ),
                ),
              ),
              if (areAnyButtonsVisible) const SizedBox(height: 8),
              if (areAnyButtonsVisible)
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis),
                ),
              if (areAnyButtonsVisible) const SizedBox(height: 16),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16, // spacing between buttons
                  children: [
                    if (visibility['phone'] ?? true)
                      _buildIconButton(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        onTap: () => _launchDialer(userProfile['phone']),
                      ),
                    if (visibility['email'] ?? true)
                      _buildIconButton(
                        icon: Icons.mail_outline_outlined,
                        label: 'Email',
                        onTap: () => _launchEmail(userProfile['email']),
                      ),
                    if (visibility['phone'] ?? true)
                      _buildIconButton(
                        icon: FontAwesomeIcons.whatsapp,
                        label: 'WhatsApp',
                        onTap: () => _launchWhatsApp(userProfile['phone']),
                      ),
                    if ((visibility['linkedin'] ?? true) &&
                        (userProfile['linkedin']?.isNotEmpty ?? false))
                      _buildIconButton(
                        icon: FontAwesomeIcons.linkedin,
                        label: 'LinkedIn',
                        onTap: () => _launchLinkedIn(userProfile['linkedin']),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 0.5),
              _buildProfileTile(context, Icons.person_outline, 'Name',
                  userProfile['name'], visibility['name'] ?? true),
              _buildProfileTile(
                  context,
                  Icons.business_center_outlined,
                  'Designation',
                  userProfile['designation'],
                  visibility['designation'] ?? true),
              _buildProfileTile(
                  context,
                  Icons.business_outlined,
                  'Organization',
                  userProfile['organization'],
                  visibility['organization'] ?? true),
              _buildProfileTile(
                context,
                Icons.email_outlined,
                'Email',
                userProfile['email'],
                visibility['email'] ?? true,
                onTap: () {
                  final email = userProfile['email'];
                  if (email != null && email.isNotEmpty) {
                    _launchEmail(email);
                  } else {
                    _showError('Email address is not available.');
                  }
                },
              ),
              _buildProfileTile(
                context,
                Icons.phone_outlined,
                'Phone',
                userProfile['phone'],
                visibility['phone'] ?? true,
                onTap: () {
                  final phone = userProfile['phone'];
                  if (phone != null && phone.isNotEmpty) {
                    _launchDialer(phone);
                  } else {
                    _showError('Phone number is not available.');
                  }
                },
              ),
              _buildProfileTile(
                context,
                FontAwesomeIcons.linkedin,
                'LinkedIn',
                userProfile['linkedin'],
                visibility['linkedin'] ?? true,
                onTap: () {
                  final linkedin = userProfile['linkedin'];
                  if (linkedin != null && linkedin.isNotEmpty) {
                    _launchLinkedIn(linkedin);
                  } else {
                    _showError('LinkedIn profile is not available.');
                  }
                },
              ),
              _buildProfileTile(
                context,
                Icons.cake_outlined,
                'Date of Birth',
                userProfile['dob'] != null
                    ? DateFormat('MMMM d').format(
                        DateFormat('dd/MM/yyyy').parse(userProfile['dob']))
                    : null,
                visibility['dob'] ?? true,
              ),
              _buildProfileTile(context, Icons.school_outlined, 'Course',
                  userProfile['course'], visibility['course'] ?? true),
              _buildProfileTile(
                  context,
                  Icons.calendar_today_outlined,
                  'Graduation Year',
                  userProfile['year'],
                  visibility['year'] ?? true),
              _buildProfileTile(context, Icons.location_city_outlined, 'City',
                  userProfile['city'], visibility['city'] ?? true),
              _buildProfileTile(context, Icons.home_outlined, 'Address',
                  userProfile['address'], visibility['address'] ?? true),
            ],
          ),
        ),
      ),
    );
  }
}
