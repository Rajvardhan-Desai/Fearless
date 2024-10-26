import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(UserState.initial());

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> fetchUserData() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final documentSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (documentSnapshot.exists) {
        final userData = documentSnapshot.data() as Map<String, dynamic>;

        state = state.copyWith(
          isLoading: false,
          name: userData['name'] ?? 'User',
          email: user.email ?? '',
          phone: userData['phone'],
          emergencyContact1: userData['emergencyContact1'] ?? '',
          emergencyContact2: userData['emergencyContact2'] ?? '',
          guardianName: userData['guardianName'] ?? '',
          guardianPhone: userData['guardianPhone'] ?? '',
          medicalInfo: userData['medicalInfo'] ?? '',
          imageUrl: userData['imageUrl'] ?? '',
          blurHash: userData['blurHash'] ?? '',
        );
      } else {
        throw Exception('User data not found');
      }
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String email,
    required String phone,
    required String emergencyContact1,
    required String emergencyContact2,
    required String guardianName,
    required String guardianPhone,
    required String medicalInfo,
    required String imageUrl,
    required String blurHash,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'email': email,
        'phone': phone,
        'emergencyContact1': emergencyContact1,
        'emergencyContact2': emergencyContact2,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'medicalInfo': medicalInfo,
        'imageUrl': imageUrl,
        'blurHash': blurHash,
      });

      state = state.copyWith(
        isLoading: false,
        name: name,
        email: email,
        phone: phone,
        emergencyContact1: emergencyContact1,
        emergencyContact2: emergencyContact2,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
        medicalInfo: medicalInfo,
        imageUrl: imageUrl,
        blurHash: blurHash,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
  Future<void> updateUserImage({required String imageUrl, required String blurHash}) async {
    state = state.copyWith(imageUrl: imageUrl, blurHash: blurHash);
  }
}

class UserState {
  final bool isLoading;
  final String name;
  final String email;
  final String phone;
  final String emergencyContact1;
  final String emergencyContact2;
  final String guardianName;
  final String guardianPhone;
  final String medicalInfo;
  final String imageUrl;
  final String blurHash;
  final String? error;

  UserState({
    required this.isLoading,
    required this.name,
    required this.email,
    required this.phone,
    required this.emergencyContact1,
    required this.emergencyContact2,
    required this.guardianName,
    required this.guardianPhone,
    required this.medicalInfo,
    required this.imageUrl,
    required this.blurHash,
    this.error,
  });

  factory UserState.initial() {
    return UserState(
      isLoading: false,
      name: '',
      email: '',
      phone: '',
      emergencyContact1: '',
      emergencyContact2: '',
      guardianName: '',
      guardianPhone: '',
      medicalInfo: '',
      imageUrl: '',
      blurHash: '',
      error: null,
    );
  }

  UserState copyWith({
    bool? isLoading,
    String? name,
    String? email,
    String? phone,
    String? emergencyContact1,
    String? emergencyContact2,
    String? guardianName,
    String? guardianPhone,
    String? medicalInfo,
    String? imageUrl,
    String? blurHash,
    String? error,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emergencyContact1: emergencyContact1 ?? this.emergencyContact1,
      emergencyContact2: emergencyContact2 ?? this.emergencyContact2,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      medicalInfo: medicalInfo ?? this.medicalInfo,
      imageUrl: imageUrl ?? this.imageUrl,
      blurHash: blurHash ?? this.blurHash,
      error: error ?? this.error,
    );
  }
}
