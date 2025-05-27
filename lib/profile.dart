import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfilePage extends StatefulWidget {
  final bool isEditable;
  const ProfilePage({super.key, this.isEditable = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  File? _profileImage;

  // Controllers for text fields
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditable;
    _loadUserData();
    _loadProfileImage();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _firstNameController.text = user.firstName ?? '';
      _middleNameController.text = user.middleName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _emailController.text = user.email ?? '';
      if (user.age != null) {
        _ageController.text = user.age.toString();
      }
      _contactNumberController.text = user.contactNumber ?? '';
    }
  }

  Future<void> _loadProfileImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final imagePath = path.join(directory.path, 'profile_${user.id}.jpg');
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        setState(() {
          _profileImage = imageFile;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _profileImage = File(pickedImage.path);
      });

      // Save image permanently
      final directory = await getApplicationDocumentsDirectory();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        final imagePath = path.join(directory.path, 'profile_${user.id}.jpg');
        await File(pickedImage.path).copy(imagePath);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF3AA772),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit,
                  color: Colors.white),
              onPressed: () async {
                if (_isEditing) {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await context.read<AuthProvider>().updateProfile(
                            firstName: _firstNameController.text,
                            middleName: _middleNameController.text,
                            lastName: _lastNameController.text,
                            age: int.tryParse(_ageController.text),
                            contactNumber: _contactNumberController.text,
                          );

                      if (mounted) {
                        setState(() => _isEditing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Profile updated successfully')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Error updating profile: ${e.toString()}')),
                        );
                      }
                    }
                  }
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _profileImage != null
                            ? CircleAvatar(
                                radius: 60,
                                backgroundImage: FileImage(_profileImage!),
                              )
                            : CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFF3AA772),
                                child: Text(
                                  _firstNameController.text.isNotEmpty
                                      ? _firstNameController.text[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                      if (_isEditing)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF3AA772),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildProfileField(
                        icon: Icons.person_outline,
                        label: 'First Name',
                        controller: _firstNameController,
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 32),
                      _buildProfileField(
                        icon: Icons.person_outline,
                        label: 'Middle Name',
                        controller: _middleNameController,
                        enabled: _isEditing,
                      ),
                      const Divider(height: 32),
                      _buildProfileField(
                        icon: Icons.person_outline,
                        label: 'Last Name',
                        controller: _lastNameController,
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 32),
                      _buildProfileField(
                        icon: Icons.cake_outlined,
                        label: 'Age',
                        controller: _ageController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid age';
                            }
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 32),
                      _buildProfileField(
                        icon: Icons.phone_outlined,
                        label: 'Contact Number',
                        controller: _contactNumberController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your contact number';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 32),
                      _buildProfileField(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        controller: _emailController,
                        enabled: false,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF3AA772)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            validator: validator,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16.0,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontSize: 14.0,
              ),
              border: enabled ? const UnderlineInputBorder() : InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3AA772), width: 2.0),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
