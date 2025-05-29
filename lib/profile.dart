import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:flutter/painting.dart';

class ProfilePage extends StatefulWidget {
  final bool isEditable;
  const ProfilePage({super.key, this.isEditable = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditing = false;
  File? _profileImage;
  DateTime? _selectedBirthDate;
  String? _selectedGender;

  // List of gender options for dropdown
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

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
      _emailController.text = user.email;
      _contactNumberController.text = user.contactNumber ?? '';
      _emergencyContactController.text = user.emergencyContact ?? '';
      _selectedGender = user.gender;

      // Set birth date
      if (user.birthDate != null) {
        _selectedBirthDate = user.birthDate;
        _birthDateController.text =
            DateFormat('MMM dd, yyyy').format(user.birthDate!);
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final user = context.read<AuthProvider>().currentUser;

      if (user != null) {
        final dir = Directory(directory.path);
        List<FileSystemEntity> profileImages = [];

        // Collect all profile images for this user
        await for (var entity in dir.list()) {
          if (entity is File) {
            final filename = path.basename(entity.path);
            if (filename.startsWith('profile_${user.id}')) {
              profileImages.add(entity);
            }
          }
        }

        if (profileImages.isNotEmpty) {
          // Sort to get the most recent one (assuming timestamp in filename)
          profileImages.sort((a, b) => b.path.compareTo(a.path));
          final latestImage = profileImages.first as File;

          debugPrint('Found most recent profile image at: ${latestImage.path}');

          if (mounted) {
            setState(() {
              _profileImage = latestImage;
            });
          }
        } else {
          debugPrint('No profile images found for user ID: ${user.id}');
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Add some compression for better performance
      );

      if (pickedImage != null) {
        // Get the picked image as a file
        final File pickedFile = File(pickedImage.path);

        // Get a unique name for the file to prevent caching issues
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final directory = await getApplicationDocumentsDirectory();
        final user = context.read<AuthProvider>().currentUser;

        if (user != null) {
          // Use a timestamp in filename to avoid caching issues
          final imagePath =
              path.join(directory.path, 'profile_${user.id}_$timestamp.jpg');

          // Copy the image to permanent storage with the new filename
          final savedFile = await pickedFile.copy(imagePath);

          // Delete any previous profile images
          await _deleteOldProfileImages(user.id, directory, timestamp);

          // Verify the file was copied correctly
          if (await savedFile.exists()) {
            debugPrint('Profile image saved successfully to: $imagePath');

            // Clear any image caches
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();

            // Update the state with the permanently saved file
            if (mounted) {
              setState(() {
                _profileImage = savedFile;
              });

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Profile picture updated successfully')),
              );
            }
          } else {
            throw Exception('Failed to save profile image');
          }
        } else {
          throw Exception('User is not authenticated');
        }
      }
    } catch (e) {
      debugPrint('Error picking/saving profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating profile picture: ${e.toString()}')),
        );
      }
    }
  }

  // Helper method to delete old profile images
  Future<void> _deleteOldProfileImages(
      String userId, Directory directory, String currentTimestamp) async {
    try {
      final dir = Directory(directory.path);
      await for (var entity in dir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          // Check if it's a profile image for this user but not the current one
          if (filename.startsWith('profile_$userId') &&
              !filename.contains(currentTimestamp)) {
            await entity.delete();
            debugPrint('Deleted old profile image: $filename');
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting old profile images: $e');
      // Don't throw here, just log the error
    }
  }

  // Show date picker to select birth date
  Future<void> _selectBirthDate(BuildContext context) async {
    if (!_isEditing) return;

    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _selectedBirthDate ?? DateTime(now.year - 20, now.month, now.day);
    final DateTime firstDate =
        DateTime(now.year - 120); // 120 years ago maximum
    final DateTime lastDate =
        DateTime(now.year - 13, now.month, now.day); // At least 13 years old

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3AA772), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Calendar text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3AA772), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _contactNumberController.dispose();
    _emergencyContactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3AA772),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon:
                Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: () async {
              if (_isEditing) {
                // Only validate form fields if we're trying to save profile data
                // Profile picture is handled separately in _pickImage method
                if (_formKey.currentState!.validate()) {
                  try {
                    await context.read<AuthProvider>().updateProfile(
                          firstName: _firstNameController.text,
                          middleName: _middleNameController.text,
                          lastName: _lastNameController.text,
                          birthDate: _selectedBirthDate,
                          contactNumber: _contactNumberController.text,
                          emergencyContact: _emergencyContactController.text,
                          gender: _selectedGender,
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
                                backgroundImage: FileImage(
                                  _profileImage!,
                                  // Add a unique key to force refresh when image changes
                                  scale: 1.0,
                                ),
                                // Add a key with timestamp to force widget rebuild
                                key: ValueKey(_profileImage!.path),
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
                        label: 'Birth Date',
                        controller: _birthDateController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.datetime,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            try {
                              // Instead of using DateTime.tryParse, use DateFormat to parse the formatted date
                              // This is because our date is in the format 'MMM dd, yyyy' which DateTime.tryParse doesn't handle
                              DateFormat('MMM dd, yyyy').parse(value);
                              return null; // Valid date
                            } catch (e) {
                              return 'Please enter a valid birth date';
                            }
                          }
                          return null; // Empty is OK
                        },
                      ),
                      const Divider(height: 32),
                      _buildGenderDropdownField(),
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
                        icon: Icons.contact_phone_outlined,
                        label: 'Emergency Contact Number',
                        controller: _emergencyContactController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an emergency contact number';
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
    bool isDatePicker = false,
  }) {
    // Automatically set the birth date field as a date picker
    if (label == 'Birth Date') {
      isDatePicker = true;
    }

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
            readOnly:
                isDatePicker, // Make field read-only if it's a date picker
            onTap: isDatePicker && enabled
                ? () => _selectBirthDate(context)
                : null,
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
              // Add calendar icon for date picker
              suffixIcon: isDatePicker && enabled
                  ? const Icon(Icons.calendar_today, color: Color(0xFF3AA772))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdownField() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.person, color: const Color(0xFF3AA772)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            items: _genderOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: _isEditing
                ? (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  }
                : null,
            decoration: InputDecoration(
              labelText: 'Gender',
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontSize: 14.0,
              ),
              border: const UnderlineInputBorder(),
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
