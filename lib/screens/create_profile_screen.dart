import 'dart:io';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../Widgets/snack_bar.dart';
import 'home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  CreateProfileScreenState createState() => CreateProfileScreenState();
}

class CreateProfileScreenState extends State<CreateProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _emergencyContact1Controller =
      TextEditingController();
  final TextEditingController _emergencyContact2Controller =
      TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController =
      TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();
  bool _isLoading = false;
  File? _image;

  static const int maxFileSize = 2 * 1024 * 1024;

  Future<void> _pickImage(ImageSource source) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final pickedFile = await ImagePicker().pickImage(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileSize = await file.length();

      if (fileSize <= maxFileSize) {
        setState(() {
          _image = file;
        });
      } else {
        showSnackBar(scaffoldMessenger, "Image size should be less than 2MB.",
            Colors.red);
      }
    } else {
      showSnackBar(scaffoldMessenger, "No image selected.", Colors.red);
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_image != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _removeImage();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImageOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xffad7bff)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff986ae7),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  ProfileImage(
                    image: _image,
                    showImageSourceActionSheet: _showImageSourceActionSheet,
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _phoneNoController,
                    labelText: 'Contact Number',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an your contact number';
                      }
                      final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _emergencyContact1Controller,
                    labelText: 'Emergency Contact 1',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an emergency contact number';
                      }
                      final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _emergencyContact2Controller,
                    labelText: 'Emergency Contact 2',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an emergency contact number';
                      }
                      final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _guardianNameController,
                    labelText: 'Guardian/Trusted Person Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a trusted person\'s name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _guardianPhoneController,
                    labelText: 'Guardian Phone Number',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a trusted person\'s phone number';
                      }
                      final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  CustomTextFormField(
                    controller: _medicalInfoController,
                    labelText: 'Medical Info (Optional)',
                    validator: (value) {
                      return null; // Not required
                    },
                  ),
                  const SizedBox(height: 30.0),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _createProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Create Profile',
                            style: TextStyle(
                              fontSize: 18.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final FirebaseAuth auth = FirebaseAuth.instance;
        final User? user = auth.currentUser;
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        String? imageUrl;
        String? blurHash;

        if (_image != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user?.uid}.${_image!.path.split('.').last}');
          await storageRef.putFile(_image!);
          imageUrl = await storageRef.getDownloadURL();

          final imageBytes = await _image!.readAsBytes();
          final decodedImage = img.decodeImage(imageBytes);
          blurHash =
              BlurHash.encode(decodedImage!, numCompX: 6, numCompY: 4).hash;
        }

        await firestore.collection('users').doc(user?.uid).set({
          'name': _nameController.text.trim(),
          'imageUrl': imageUrl,
          'blurHash': blurHash,
          'phone': _phoneNoController.text.trim(),
          'emergencyContact1': _emergencyContact1Controller.text.trim(),
          'emergencyContact2': _emergencyContact2Controller.text.trim(),
          'guardianName': _guardianNameController.text.trim(),
          'guardianPhone': _guardianPhoneController.text.trim(),
          'medicalInfo': _medicalInfoController.text.trim(),
        });

        showSnackBar(
            scaffoldMessenger, "Profile created successfully!", Colors.green);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(triggerEmergencySharing: false)),
            (Route<dynamic> route) => false,
          );
        }
      } on FirebaseException catch (e) {
        showSnackBar(
            scaffoldMessenger, "Firebase Error:${e.message}", Colors.redAccent);
      } catch (e) {
        showSnackBar(
            scaffoldMessenger, "Error creating profile: $e", Colors.redAccent);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?) validator;
  final bool readOnly;
  final bool isGrayedOut;
  final VoidCallback? onTap;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.validator,
    this.readOnly = false,
    this.isGrayedOut =
        false, // New parameter to control the grayed-out appearance
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      enabled: !isGrayedOut, // Disables the field if grayed out
    );
  }
}

class ProfileImage extends StatelessWidget {
  final File? image;
  final VoidCallback showImageSourceActionSheet;

  const ProfileImage({
    super.key,
    required this.image,
    required this.showImageSourceActionSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin:
              const EdgeInsets.all(8.0), // Add margin around the CircleAvatar
          child: CircleAvatar(
            radius: 60,
            backgroundImage: image != null ? FileImage(image!) : null,
            child: image == null
                ? const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey,
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: -5,
          right: -5,
          child: Container(
            margin: const EdgeInsets.only(right: 5.0, bottom: 5.0),
            decoration: const BoxDecoration(
              color: Color(0xffc1a8ff),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: showImageSourceActionSheet,
            ),
          ),
        ),
      ],
    );
  }
}
