import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Widgets/snack_bar.dart';
import '../widgets/user_avatar.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfilePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userImageUrl;
  final String? blurHash;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userImageUrl,
    this.blurHash,
  });

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String? _userImageUrl;
  late FirebaseAuth _auth;

  @override
  void initState() {
    super.initState();
    _userImageUrl = widget.userImageUrl;
    _auth = FirebaseAuth.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              child: UserAvatar(
                key: ValueKey(_userImageUrl),
                imageUrl: _userImageUrl,
                blurHash: widget.blurHash,
                radius: 55,
                iconSize: 60, // Slightly smaller radius inside the border
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.userEmail,
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 4),
            _buildProfileOptions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOptions() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Account'),
        ProfileOption(
          icon: Icons.edit_outlined,
          text: 'Edit Profile',
          onTap: () => _navigateToEditProfile(context),
        ),
        ProfileOption(
          icon: Icons.password_outlined,
          text: 'Change Password',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen()),
            );
          },
        ),

        _buildSectionTitle('App'),
        ProfileOption(
          icon: Icons.group_outlined,
          text: 'Invite Friends',
          onTap: () {
            showSnackBar(
                scaffoldMessenger, "Under development ! ", Colors.grey);
          },
          subtitle: 'Invite your friends to join the app',
        ),
        _buildSectionTitle('About'),
        ProfileOption(
          icon: Icons.help_outline_rounded,
          text: 'Help',
          onTap: () {
            showSnackBar(
                scaffoldMessenger, "Under development ! ", Colors.grey);
          },
        ),
        ProfileOption(
          icon: Icons.description_outlined,
          text: 'Terms of Service',
          onTap: () {
            showSnackBar(
                scaffoldMessenger, "Under development ! ", Colors.grey);
          },
        ),
        ProfileOption(
          icon: Icons.info_outline_rounded,
          text: 'Fearless',
          onTap: () {
            // Implement terms of service navigation or function
          },
          subtitle: "beta.x1",
        ),
        ProfileOption(
          icon: Icons.logout,
          text: 'Sign Out',
          fontStyle: const TextStyle(color: Color(0xffee4c41)),
          onTap: () => _confirmSignOut(context),
          iconColor: const Color(0xffee4c41), // Custom icon color for sign out
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.0,
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _navigateToEditProfile(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    if (result == true && widget.userImageUrl != null) {
      await _clearImageCache(widget.userImageUrl!);
      setState(() {
        _userImageUrl = Uri.parse(widget.userImageUrl!).replace(
            queryParameters: {
              't': DateTime.now().millisecondsSinceEpoch.toString()
            }).toString();
      });
    }
  }

  Future<void> _clearImageCache(String imageUrl) async {
    await CachedNetworkImage.evictFromCache(imageUrl);
    final parsedUri = Uri.parse(imageUrl);
    if (parsedUri.queryParameters.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(
          parsedUri.replace(queryParameters: {}).toString());
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, 'SignInScreen', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error signing out: ${e.toString()}. Please try again.'),
          ),
        );
      }
    }
  }

  void _confirmSignOut(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Sign Out',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Are you sure you want to sign out?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                      _signOut(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffff2121),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sign Out',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final String? subtitle; // Optional subtitle
  final TextStyle? fontStyle; // Optional font style
  final Color? iconColor; // Optional icon color

  const ProfileOption({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.subtitle, // Initialize subtitle
    this.fontStyle, // Initialize font style
    this.iconColor, // Initialize icon color
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ??
              const Color(0xff575f64), // Use provided icon color or default
          size: 28,
        ),
        title: Text(
          text,
          style: fontStyle ??
              const TextStyle(
                // Use provided font style or default
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!)
            : null, // Show subtitle if provided
        onTap: onTap,
      ),
    );
  }
}
