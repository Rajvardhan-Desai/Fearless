import 'package:flutter/material.dart';
import 'package:fearless/widgets/user_avatar.dart';

class UserInfoCard extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String userCourse;
  final String userYear;
  final String? imageUrl;
  final String? blurHash;

  const UserInfoCard({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userCourse,
    required this.userYear,
    this.imageUrl,
    this.blurHash,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xffdfcbff),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            UserAvatar(imageUrl: imageUrl, blurHash: blurHash,radius: 30.0,iconSize: 30),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userCourse,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userYear,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
