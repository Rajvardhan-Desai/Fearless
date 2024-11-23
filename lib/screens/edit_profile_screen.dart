import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:fearless/providers/user_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  EditProfileScreenState createState() => EditProfileScreenState();
}

class EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyContact1Controller =
      TextEditingController();
  final TextEditingController _emergencyContact2Controller =
      TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController =
      TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();

  File? _image;
  String? _existingImageUrl;
  String? _blurHash;

  bool _isLoading = false;
  bool _isButtonLoading = false;
  bool _isChanged = false;

  Map<String, dynamic> _initialValues = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });

    // Add listeners to form fields to track changes
    _nameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
    _emergencyContact1Controller.addListener(_checkForChanges);
    _emergencyContact2Controller.addListener(_checkForChanges);
    _guardianNameController.addListener(_checkForChanges);
    _guardianPhoneController.addListener(_checkForChanges);
    _medicalInfoController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContact1Controller.dispose();
    _emergencyContact2Controller.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _medicalInfoController.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userState = ref.read(userProvider);
      _populateUserProfile(userState);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _populateUserProfile(UserState userState) {
    _nameController.text = userState.name;
    _emailController.text = userState.email;
    _phoneController.text = userState.phone;
    _emergencyContact1Controller.text = userState.emergencyContact1;
    _emergencyContact2Controller.text = userState.emergencyContact2;
    _guardianNameController.text = userState.guardianName;
    _guardianPhoneController.text = userState.guardianPhone;
    _medicalInfoController.text = userState.medicalInfo;
    _existingImageUrl = userState.imageUrl;
    _blurHash = userState.blurHash;

    _initialValues = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'emergencyContact1': _emergencyContact1Controller.text,
      'emergencyContact2': _emergencyContact2Controller.text,
      'guardianName': _guardianNameController.text,
      'guardianPhone': _guardianPhoneController.text,
      'medicalInfo': _medicalInfoController.text,
      'imageUrl': _existingImageUrl,
      'blurHash': _blurHash,
    };
  }

  Future<void> _updateProfile() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_formKey.currentState!.validate() && _isChanged) {
      setState(() {
        _isButtonLoading = true;
      });
      try {
        final FirebaseAuth auth = FirebaseAuth.instance;
        final User? user = auth.currentUser;

        String? imageUrl = _existingImageUrl;
        if (_image != null && user != null) {
          imageUrl = await _uploadImage(user.uid);
        }

        if (user != null) {
          await ref.read(userProvider.notifier).updateUserProfile(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                emergencyContact1: _emergencyContact1Controller.text.trim(),
                emergencyContact2: _emergencyContact2Controller.text.trim(),
                guardianName: _guardianNameController.text.trim(),
                guardianPhone: _guardianPhoneController.text.trim(),
                medicalInfo: _medicalInfoController.text.trim(),
                imageUrl: imageUrl ?? '',
                blurHash: _blurHash ?? '',
              );

          if (_emailController.text.trim() != user.email) {
            await user.updateEmail(_emailController.text.trim());
          }

          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                  content: Text('Profile updated successfully!'),
                  backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                  content: Text('User not authenticated.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
                content: Text('An error occurred: ${e.toString()}'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isButtonLoading = false;
          });
        }
      }
    }
  }

  Future<String?> _uploadImage(String uid) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.${_image!.path.split('.').last}');
    await storageRef.putFile(_image!);
    return await storageRef.getDownloadURL();
  }

  Future<void> _pickImage(ImageSource source) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        _checkForChanges();
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(
              content: Text('No image selected.'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _removeImage() async {
    if (_image != null) {
      // User has selected a new image and wants to remove it before uploading
      setState(() {
        _image = null;
        _isChanged = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected image removed.'),
            backgroundColor: Colors.green),
      );
    } else if (_existingImageUrl != null &&
        _existingImageUrl!.isNotEmpty &&
        (_existingImageUrl!.startsWith('gs://') ||
            _existingImageUrl!.startsWith('http'))) {
      // User wants to remove the existing image from Firebase Storage
      try {
        // Delete the image from Firebase Storage
        final storageRef =
            FirebaseStorage.instance.refFromURL(_existingImageUrl!);
        await storageRef.delete();

        // Update Firestore to clear the imageUrl and blurHash
        final FirebaseAuth auth = FirebaseAuth.instance;
        final User? user = auth.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'imageUrl': '', 'blurHash': ''});

          // Update userProvider state
          await ref
              .read(userProvider.notifier)
              .updateUserImage(imageUrl: '', blurHash: '');
        }

        // Update local state to remove the image
        setState(() {
          _existingImageUrl = null;
          _blurHash = null;
          _isChanged = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile image removed successfully'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove image: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } else {
      // No image to remove
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No image to remove.'), backgroundColor: Colors.red),
      );
    }
  }

  void _checkForChanges() {
    setState(() {
      _isChanged = _nameController.text != _initialValues['name'] ||
          _emailController.text != _initialValues['email'] ||
          _phoneController.text != _initialValues['phone'] ||
          _emergencyContact1Controller.text !=
              _initialValues['emergencyContact1'] ||
          _emergencyContact2Controller.text !=
              _initialValues['emergencyContact2'] ||
          _guardianNameController.text != _initialValues['guardianName'] ||
          _guardianPhoneController.text != _initialValues['guardianPhone'] ||
          _medicalInfoController.text != _initialValues['medicalInfo'] ||
          _image != null; // Checks if a new image has been selected
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff6c5270),
        iconTheme: const IconThemeData(
            color: Colors.white), // Set the back arrow color to white
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AbsorbPointer(
                  absorbing: _isButtonLoading || _isLoading,
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          ProfileImage(
                            image: _image,
                            existingImageUrl: _existingImageUrl,
                            blurHash: _blurHash,
                            pickImage: _pickImage,
                            removeImage: _removeImage,
                          ),
                          const SizedBox(height: 20.0),
                          CustomTextFormField(
                            controller: _nameController,
                            labelText: 'Full Name',
                            validator: (value) => value!.isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 16.0),
                          CustomTextFormField(
                            controller: _emailController,
                            labelText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your email';
                              }
                              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          CustomTextFormField(
                            controller: _phoneController,
                            labelText: 'Phone Number',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                              if (!phoneRegex.hasMatch(value!)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          // CustomTextFormField(
                          //   controller: _emergencyContact1Controller,
                          //   labelText: 'Emergency Contact 1',
                          //   keyboardType: TextInputType.phone,
                          //   validator: (value) {
                          //     final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                          //     if (!phoneRegex.hasMatch(value!)) {
                          //       return 'Please enter a valid phone number';
                          //     }
                          //     return null;
                          //   },
                          // ),
                          // const SizedBox(height: 16.0),
                          // CustomTextFormField(
                          //   controller: _emergencyContact2Controller,
                          //   labelText: 'Emergency Contact 2',
                          //   keyboardType: TextInputType.phone,
                          //   validator: (value) {
                          //     final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                          //     if (!phoneRegex.hasMatch(value!)) {
                          //       return 'Please enter a valid phone number';
                          //     }
                          //     return null;
                          //   },
                          // ),
                          // const SizedBox(height: 16.0),
                          CustomTextFormField(
                            controller: _guardianNameController,
                            labelText: 'Guardian Name',
                            validator: (value) => value!.isEmpty
                                ? 'Please enter a guardian name'
                                : null,
                          ),
                          const SizedBox(height: 16.0),
                          CustomTextFormField(
                            controller: _guardianPhoneController,
                            labelText: 'Guardian Phone Number',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final phoneRegex = RegExp(r'^\+?\d{10,15}$');
                              if (!phoneRegex.hasMatch(value!)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          CustomTextFormField(
                            controller: _medicalInfoController,
                            labelText: 'Medical Information (optional)',
                          ),
                          const SizedBox(height: 30.0),
                          _isButtonLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _isChanged ? _updateProfile : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xff725678),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                  ),
                                  child: const Text(
                                    'Update Profile',
                                    style: TextStyle(
                                        fontSize: 18.0, color: Colors.white),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ProfileImage extends StatelessWidget {
  final File? image;
  final String? existingImageUrl;
  final String? blurHash;
  final Function(ImageSource) pickImage;
  final VoidCallback removeImage;

  const ProfileImage({
    super.key,
    required this.image,
    required this.existingImageUrl,
    required this.blurHash,
    required this.pickImage,
    required this.removeImage,
  });

  @override
  Widget build(BuildContext context) {
    String? imageUrl = existingImageUrl;

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade300,
          child: ClipOval(
            child: image != null
                ? Image.file(
                    image!,
                    fit: BoxFit.cover,
                    width: 120,
                    height: 120,
                  )
                : (imageUrl != null && imageUrl.isNotEmpty
                    ? Stack(
                        children: [
                          if (blurHash != null && blurHash!.isNotEmpty)
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: BlurHash(
                                hash: blurHash!,
                                imageFit: BoxFit.cover,
                              ),
                            ),
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error, size: 60),
                          ),
                        ],
                      )
                    : const Icon(
                        Icons.person, // Placeholder icon
                        size: 60,
                        color: Colors.grey,
                      )),
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
              onPressed: () => _showImageSourceActionSheet(context),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (existingImageUrl != null || image != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        removeImage();
                        Navigator.pop(context); // Close the action sheet
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
                      pickImage(ImageSource.camera);
                      Navigator.pop(context); // Close the action sheet
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      pickImage(ImageSource.gallery);
                      Navigator.pop(context); // Close the action sheet
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xffad7bff)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.validator,
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
      validator: validator,
    );
  }
}
