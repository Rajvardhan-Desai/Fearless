import 'package:flutter/material.dart';

void showSnackBar(ScaffoldMessengerState scaffoldMessenger, String message, Color color) {
  Future.delayed(Duration.zero, () {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                scaffoldMessenger.hideCurrentSnackBar();
              },
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(25),
      ),
    );
  });
}
