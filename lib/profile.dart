import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  // If false (default), page is strictly view-only.
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
  int _editSectionIndex = 0; // 0 = Personal, 1 = Contact

  // Dropdown options removed; page is view-only by default.

  @override
  void initState() {
    super.initState();
    // Always start in view mode, even if page is editable
    _isEditing = false;
    _loadUserData();
    _loadProfileImage();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      debugPrint('📋 Loading profile data for user: ${user.email}');

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

      // Check for incomplete profile and log for debugging
      final missingFields = <String>[];
      if (user.firstName == null || user.firstName!.trim().isEmpty)
        missingFields.add('First Name');
      if (user.lastName == null || user.lastName!.trim().isEmpty)
        missingFields.add('Last Name');
      if (user.birthDate == null) missingFields.add('Birth Date');
      if (user.gender == null || user.gender!.trim().isEmpty)
        missingFields.add('Gender');
      if (user.contactNumber == null || user.contactNumber!.trim().isEmpty)
        missingFields.add('Contact Number');
      if (user.emergencyContact == null ||
          user.emergencyContact!.trim().isEmpty)
        missingFields.add('Emergency Contact');

      if (missingFields.isNotEmpty) {
        debugPrint(
            '⚠️ Incomplete profile detected. Missing: ${missingFields.join(', ')}');

        // Show a helpful message to the user if this is not an editing session
        if (!widget.isEditable && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Your profile is incomplete. Missing: ${missingFields.join(', ')}'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Complete Profile',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) =>
                              const ProfilePage(isEditable: true),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          });
        }
      } else {
        debugPrint('✅ Profile is complete');
      }
    } else {
      debugPrint('❌ No user data available for profile loading');

      // Show error message if no user data
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to load profile data. Please try signing in again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final user = context.read<AuthProvider>().currentUser;

      if (user != null) {
        // First try to load from user's avatar URL (from Supabase)
        if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
          debugPrint('Using avatar from Supabase: ${user.avatarUrl}');
          // For network images, we don't set _profileImage file, we'll handle this in the UI
          // The CircleAvatar will use NetworkImage if avatarUrl is available
          return;
        }

        // Fallback to local storage
        final directory = await getApplicationDocumentsDirectory();
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

  // Show profile picture options dialog
  void _showProfilePictureOptions() {
    final user = context.read<AuthProvider>().currentUser;
    final hasImage = _getAvatarImage() != null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),

                // Profile picture preview
                if (hasImage) ...[
                  GestureDetector(
                    onTap: () => _showFullSizeImage(),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _getAvatarImage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to view full size',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3AA772),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF3AA772),
                      child: Text(
                        user?.firstName?.isNotEmpty == true
                            ? user!.firstName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No profile picture set',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Change/Add picture button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _pickImage();
                      },
                      icon: Icon(hasImage ? Icons.edit : Icons.add_a_photo),
                      label: Text(hasImage ? 'Change' : 'Add Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3AA772),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),

                    // Remove picture button (only if image exists)
                    if (hasImage)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeProfilePicture();
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 15),

                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show full size image preview
  void _showFullSizeImage() {
    final avatarImage = _getAvatarImage();
    if (avatarImage == null) return;

    Navigator.of(context).pop(); // Close options dialog first

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Full screen image with zoom capability - stretched to fill
              Positioned.fill(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.1,
                  maxScale: 5.0,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: Image(
                        image: avatarImage,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit
                            .contain, // This will stretch to fill while maintaining aspect ratio
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 100,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Status bar overlay for immersive experience
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).padding.top,
                  color: Colors.black54,
                ),
              ),

              // Close button - top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 15,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    splashRadius: 25,
                  ),
                ),
              ),

              // Info overlay - top left with fade in animation
              Positioned(
                top: MediaQuery.of(context).padding.top + 15,
                left: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pinch to zoom',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action bar with glassmorphism effect
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    top: 20,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Change picture button
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _pickImage();
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Change Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3AA772),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),

                      // Remove picture button
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _removeProfilePicture();
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Targeted profile picture cache clearing method
  Future<void> _clearProfileImageCache() async {
    try {
      final user = context.read<AuthProvider>().currentUser;

      // Only evict specific profile-related network images
      if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
        try {
          // Evict the current avatar URL
          NetworkImage(user.avatarUrl!).evict();

          // Also try to evict common cache-busted variations
          final baseUrl = user.avatarUrl!.split('?')[0]; // Remove query params
          NetworkImage(baseUrl).evict();

          debugPrint('🖼️ Evicted profile image from cache: ${user.avatarUrl}');
        } catch (e) {
          debugPrint('Error evicting specific profile image: $e');
        }
      }

      // Force rebuild this specific widget
      if (mounted) {
        setState(() {
          // Just trigger rebuild of this profile widget
        });
      }
    } catch (e) {
      debugPrint('Error in profile image cache clear: $e');
    }
  }

  // Remove profile picture
  Future<void> _removeProfilePicture() async {
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Profile Picture'),
          content: const Text(
              'Are you sure you want to remove your profile picture?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // TARGETED CACHE CLEARING BEFORE ANY CHANGES - only profile images
      await _clearProfileImageCache();

      // IMMEDIATE UI UPDATE - Clear local image state first
      if (mounted) {
        setState(() {
          _profileImage = null;
        });
      }

      // Another round of targeted cache clearing after state change
      await _clearProfileImageCache();

      // Update user profile in database to remove avatar URL (explicit flag)
      try {
        await context.read<AuthProvider>().updateProfile(
              firstName: user.firstName,
              lastName: user.lastName,
              contactNumber: user.contactNumber,
              emergencyContact: user.emergencyContact,
              gender: user.gender,
              avatarUrl: null,
              removeAvatar: true, // ensure column is set to NULL
            );
        debugPrint('✅ Successfully updated profile to remove avatar URL');
      } catch (e) {
        debugPrint('Error updating profile: $e');
        throw Exception('Failed to update profile: $e');
      }

      // Delete local profile images after successful database update
      try {
        final directory = await getApplicationDocumentsDirectory();
        final dir = Directory(directory.path);

        // Delete all profile images for this user
        await for (var entity in dir.list()) {
          if (entity is File) {
            final filename = path.basename(entity.path);
            if (filename.startsWith('profile_${user.id}')) {
              await entity.delete();
              debugPrint('Deleted local profile image: $filename');
            }
          }
        }
      } catch (e) {
        debugPrint('Error deleting local images: $e');
      }

      // FORCE ANOTHER UI UPDATE after database changes
      if (mounted) {
        setState(() {
          _profileImage = null;
        });

        // Final round of targeted profile image cache clearing
        await _clearProfileImageCache();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing profile picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    // Allow profile picture editing even in view mode
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
          // TARGETED CACHE CLEARING BEFORE ANY CHANGES - only profile images
          await _clearProfileImageCache();

          // Use a timestamp in filename to avoid caching issues
          final imagePath =
              path.join(directory.path, 'profile_${user.id}_$timestamp.jpg');

          // Copy the image to permanent storage with the new filename
          final savedFile = await pickedFile.copy(imagePath);

          // Delete any previous profile images
          await _deleteOldProfileImages(user.id, directory, timestamp);

          // IMMEDIATELY update local state to show new image (before upload)
          if (mounted) {
            setState(() {
              _profileImage = savedFile;
            });
          }

          // Upload to Supabase storage
          String? newAvatarUrl;
          try {
            newAvatarUrl =
                await context.read<AuthProvider>().uploadAvatar(savedFile);

            if (newAvatarUrl != null) {
              debugPrint(
                  'Avatar uploaded successfully to Supabase: $newAvatarUrl');

              // FORCE IMMEDIATE UI UPDATE with the new URL
              if (mounted) {
                // Targeted profile image cache clearing for new image
                await _clearProfileImageCache();

                // Trigger rebuild with new data
                setState(() {
                  // Force rebuild to pick up new avatar URL from AuthProvider
                });

                // Wait a moment then clear cache again for network image
                Future.delayed(const Duration(milliseconds: 100), () async {
                  if (mounted) {
                    await _clearProfileImageCache();
                  }
                });
              }
            }
          } catch (supabaseError) {
            debugPrint('Error uploading to Supabase: $supabaseError');
            // Continue with local storage even if Supabase upload fails
          }

          // Verify the file was copied correctly
          if (await savedFile.exists()) {
            debugPrint('Profile image saved successfully to: $imagePath');

            // Show success message
            if (mounted) {
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

  // Helper method to get the appropriate avatar image
  ImageProvider? _getAvatarImage() {
    final user = context.read<AuthProvider>().currentUser;

    // Priority 1: Local profile image (most recent)
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }

    // Priority 2: Supabase avatar URL (no global cache-busting; we evict on change)
    if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      final avatarUrl = user.avatarUrl!;
      return NetworkImage(avatarUrl);
    }

    // No image available
    return null;
  }

  // Show date picker to select birth date
  // Date picker removed; birthdate is fixed after registration.

  // Phone number validation function
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final phone = value.trim();

    // Check if it contains only digits
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return 'Only numbers allowed';
    }

    // Check if it's exactly 11 digits
    if (phone.length != 11) {
      return 'Must be exactly 11 digits';
    }

    return null;
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
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Profile', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            if (_isEditing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Editing',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF3AA772),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Header with gradient + avatar
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 24,
                        left: 24,
                        right: 24,
                        bottom: 32),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3AA772), Color(0xFF2F8E6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showProfilePictureOptions(),
                          child: Tooltip(
                            message: 'Tap to view or change profile picture',
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3AA772),
                                        Color(0xFF55B789)
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 58,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 54,
                                      backgroundColor: const Color(0xFF3AA772),
                                      backgroundImage: _getAvatarImage(),
                                      key: ValueKey(
                                          'profile_avatar_${context.read<AuthProvider>().currentUser?.avatarUrl ?? 'no-avatar'}_${_profileImage?.path ?? 'no-local'}'),
                                      child: _getAvatarImage() == null
                                          ? Text(
                                              _firstNameController
                                                      .text.isNotEmpty
                                                  ? _firstNameController.text[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                // Always show camera icon for profile picture editing
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.camera_alt,
                                      size: 18, color: Color(0xFF3AA772)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _firstNameController.text.isNotEmpty
                              ? '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                              : 'Your Name',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              _emailController.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isEditing) _editTabs(),
                  if (_isEditing) const SizedBox(height: 8),
                  // Personal Info Section
                  !_isEditing
                      ? _sectionCard(
                          title: 'Personal Information',
                          children: [
                            _infoTile(
                              icon: Icons.person_outline,
                              label: 'First Name',
                              value: _firstNameController.text.trim().isEmpty
                                  ? '-'
                                  : _firstNameController.text.trim(),
                            ),
                            _infoTile(
                              icon: Icons.person_outline,
                              label: 'Middle Name',
                              value: _middleNameController.text.trim().isEmpty
                                  ? '-'
                                  : _middleNameController.text.trim(),
                            ),
                            _infoTile(
                              icon: Icons.person_outline,
                              label: 'Last Name',
                              value: _lastNameController.text.trim().isEmpty
                                  ? '-'
                                  : _lastNameController.text.trim(),
                            ),
                            _infoTile(
                              icon: Icons.cake_outlined,
                              label: 'Birth Date',
                              value: _birthDateController.text.isEmpty
                                  ? 'Not set'
                                  : _birthDateController.text,
                            ),
                            _infoTile(
                              icon: Icons.wc_outlined,
                              label: 'Gender',
                              value: _selectedGender ?? 'Not specified',
                            ),
                          ],
                        )
                      : (_editSectionIndex == 0
                          ? _editSectionCard(
                              icon: Icons.badge_outlined,
                              title: 'Personal Information',
                              children: [
                                _field(
                                  label: 'First Name',
                                  icon: Icons.person_outline,
                                  controller: _firstNameController,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                                _field(
                                  label: 'Middle Name',
                                  icon: Icons.person_outline,
                                  controller: _middleNameController,
                                ),
                                _field(
                                  label: 'Last Name',
                                  icon: Icons.person_outline,
                                  controller: _lastNameController,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                                _fixedInfoRow(
                                  label: 'Birth Date',
                                  icon: Icons.cake_outlined,
                                  value: _birthDateController.text.isEmpty
                                      ? 'Not set'
                                      : _birthDateController.text,
                                ),
                                _fixedInfoRow(
                                  label: 'Gender',
                                  icon: Icons.wc_outlined,
                                  value: _selectedGender ?? 'Not specified',
                                ),
                              ],
                            )
                          : _editSectionCard(
                              icon: Icons.contact_phone_outlined,
                              title: 'Contact Details',
                              children: [
                                _field(
                                  label: 'Contact Number',
                                  icon: Icons.phone_outlined,
                                  controller: _contactNumberController,
                                  keyboardType: TextInputType.phone,
                                  validator: _validatePhoneNumber,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                ),
                                _field(
                                  label: 'Emergency Contact',
                                  icon: Icons.contact_phone_outlined,
                                  controller: _emergencyContactController,
                                  keyboardType: TextInputType.phone,
                                  validator: _validatePhoneNumber,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                ),
                                _fixedInfoRow(
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  value: _emailController.text,
                                ),
                              ],
                            )),
                  const SizedBox(height: 16),
                  if (!_isEditing)
                    _sectionCard(
                      title: 'Contact Details',
                      children: [
                        _infoTile(
                          icon: Icons.phone_outlined,
                          label: 'Contact Number',
                          value: _contactNumberController.text.trim().isEmpty
                              ? '-'
                              : _contactNumberController.text.trim(),
                        ),
                        _infoTile(
                          icon: Icons.contact_phone_outlined,
                          label: 'Emergency Contact',
                          value: _emergencyContactController.text.trim().isEmpty
                              ? '-'
                              : _emergencyContactController.text.trim(),
                        ),
                        _infoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _emailController.text,
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isEditing
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _loadUserData(); // revert changes
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              await context.read<AuthProvider>().updateProfile(
                                    firstName: _firstNameController.text.trim(),
                                    middleName:
                                        _middleNameController.text.trim(),
                                    lastName: _lastNameController.text.trim(),
                                    birthDate: _selectedBirthDate,
                                    contactNumber:
                                        _contactNumberController.text.trim(),
                                    emergencyContact:
                                        _emergencyContactController.text.trim(),
                                    gender: _selectedGender,
                                  );
                              if (mounted) {
                                setState(() => _isEditing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Profile updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF3AA772),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: widget.isEditable && !_isEditing
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              backgroundColor: const Color(0xFF3AA772),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  // New styled reusable widgets
  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF3AA772),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._withDividers(children),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final List<Widget> out = [];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(const SizedBox(height: 14));
      }
    }
    return out;
  }

  InputDecoration _decoration(String label, IconData icon) {
    final base = InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF3AA772)),
      filled: !_isEditing,
      fillColor: _isEditing ? null : const Color(0xFFF8FAF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      // No suffix icons in view-only mode
      suffixIcon: null,
      border: _isEditing
          ? const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB0BEC5), width: 1),
            )
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
      enabledBorder: _isEditing
          ? const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB0BEC5), width: 1),
            )
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
      disabledBorder: _isEditing
          ? const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1),
            )
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
      focusedBorder: _isEditing
          ? const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2D9254), width: 2),
            )
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2D9254), width: 2),
            ),
    );
    return base;
  }

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled && _isEditing && label != 'Email',
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _decoration(label, icon),
    );
  }

  // Removed old read-only field widgets; replaced with _fixedInfoRow.

  // Edit mode section card with distinct styling
  Widget _editSectionCard(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D9254).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF2D9254), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: children[i],
                  ),
                  if (i != children.length - 1)
                    Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fixed info row used in edit mode for non-editable fields (e.g., Birth Date, Gender, Email)
  Widget _fixedInfoRow(
      {required String label, required IconData icon, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2D9254).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2D9254), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Segmented tabs for edit sections
  Widget _editTabs() {
    Widget tab(String text, int index) {
      final bool active = _editSectionIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _editSectionIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2D9254) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? const Color(0xFF2D9254) : Colors.grey.shade300,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2D9254).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF1E2432),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          tab('Personal', 0),
          const SizedBox(width: 8),
          tab('Contact', 1),
        ],
      ),
    );
  }

  // View-only info tile for cleaner presentation
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3AA772).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3AA772), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2432),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
