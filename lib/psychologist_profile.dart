import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/psychologist_model.dart';
import 'models/appointment_model.dart';
import 'services/supabase_service.dart';
import 'utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class PsychologistProfilePage extends StatefulWidget {
  const PsychologistProfilePage({super.key});

  @override
  State<PsychologistProfilePage> createState() =>
      _PsychologistProfilePageState();
}

class _PsychologistProfilePageState extends State<PsychologistProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  PsychologistModel? _psychologist;
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  bool _isLoadingAppointments = true;
  bool _showArchivedAppointments = false;

  // Filter state
  String _selectedFilter = 'All'; // Default filter
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Accepted',
    'Expired',
    'Unavailable',
    'Completed'
  ];

  // Form controllers
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _reasonController = TextEditingController();

  // Form validation
  final Map<String, String> _fieldErrors = {
    'date': '',
    'time': '',
    'reason': '',
  };

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Set loading state but don't block UI completely
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load essential data first (psychologist info) - this is what users care about most
      await _loadPsychologistData();

      // Load appointments in background after showing the main content
      _loadAppointmentsInBackground();
    } catch (e) {
      Logger.error('Error in _loadData', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPsychologistData() async {
    print('🔍 Starting _loadPsychologistData...');
    try {
      // Load psychologist data (main priority)
      print('📞 Calling getAssignedPsychologist...');
      final psychologistData = await _supabaseService.getAssignedPsychologist();
      print(
          '📋 Got psychologist data: ${psychologistData != null ? 'Found' : 'Null'}');

      if (psychologistData != null) {
        if (mounted) {
          setState(() {
            _psychologist = PsychologistModel.fromJson(psychologistData);
          });
        }

        // Try to get latest profile picture URL if available (non-blocking)
        if (_psychologist != null && mounted) {
          try {
            final latestPictureUrl = await _supabaseService
                .getPsychologistProfilePictureUrl(_psychologist!.id);
            if (latestPictureUrl != null &&
                latestPictureUrl.isNotEmpty &&
                mounted) {
              setState(() {
                _psychologist = PsychologistModel(
                  id: _psychologist!.id,
                  name: _psychologist!.name,
                  specialization: _psychologist!.specialization,
                  contactEmail: _psychologist!.contactEmail,
                  contactPhone: _psychologist!.contactPhone,
                  biography: _psychologist!.biography,
                  imageUrl: latestPictureUrl,
                );
              });
            }
          } catch (e) {
            Logger.error('Error loading profile picture', e);
            // Don't show error for profile picture - it's not critical
          }
        }
      } else {
        // Handle case where no psychologist is found
        if (mounted) {
          setState(() {
            _psychologist = null;
          });
        }
      }
    } catch (e) {
      Logger.error('Error loading psychologist data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Error loading psychologist details. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always turn off loading state whether successful or failed
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAppointmentsInBackground() async {
    if (mounted) {
      setState(() {
        _isLoadingAppointments = true;
      });
    }

    try {
      // Auto-archive old appointments first (maintenance task)
      try {
        final archivedCount =
            await _supabaseService.autoArchiveOldAppointments();
        if (archivedCount > 0) {
          Logger.info('Auto-archived $archivedCount old appointments');
        }
      } catch (e) {
        Logger.error('Error auto-archiving appointments', e);
      }

      // Load appointment history
      final appointmentsData = await _supabaseService.getAppointments();
      final List<AppointmentModel> appointments = [];

      // Process appointments, correcting statuses as needed
      for (var data in appointmentsData) {
        // Auto-correct status if it's pending but has a response
        if (data['status'] == 'pending' &&
            data['response_message'] != null &&
            data['response_message'].toString().isNotEmpty) {
          // Update status to accepted/approved in the model
          data['status'] = 'accepted';

          // Also try to update in the database
          try {
            await _supabaseService.refreshAppointmentStatus(data['id']);
          } catch (e) {
            Logger.error('Error updating appointment status', e);
          }
        }

        // Add to the appointments list
        appointments.add(AppointmentModel.fromJson(data));
      }

      if (mounted) {
        setState(() {
          _appointments = appointments;
        });
      }
    } catch (e) {
      Logger.error('Error loading appointments', e);
      // Don't show error for appointments - they can load later via refresh
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3AA772),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(picked);
        _fieldErrors['date'] = '';
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3AA772),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
        _fieldErrors['time'] = '';
      });
    }
  }

  void _resetForm() {
    setState(() {
      _dateController.text = '';
      _timeController.text = '';
      _reasonController.text = '';
      _selectedDate = null;
      _selectedTime = null;
      _fieldErrors['date'] = '';
      _fieldErrors['time'] = '';
      _fieldErrors['reason'] = '';
    });
  }

  bool _validateForm() {
    bool isValid = true;

    setState(() {
      // Validate date
      if (_selectedDate == null) {
        _fieldErrors['date'] = 'Date is required';
        isValid = false;
      } else {
        _fieldErrors['date'] = '';
      }

      // Validate time
      if (_selectedTime == null) {
        _fieldErrors['time'] = 'Time is required';
        isValid = false;
      } else {
        _fieldErrors['time'] = '';
      }

      // Validate reason
      if (_reasonController.text.trim().isEmpty) {
        _fieldErrors['reason'] = 'Reason is required';
        isValid = false;
      } else {
        _fieldErrors['reason'] = '';
      }
    });

    return isValid;
  }

  Future<void> _submitAppointmentRequest() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Create appointment data
      final appointmentData = {
        'psychologist_id': _psychologist!.id,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'reason': _reasonController.text.trim(),
      };

      // Submit appointment request
      await _supabaseService.requestAppointment(appointmentData);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your appointment request has been submitted. Please wait for confirmation.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset form and reload data
      _resetForm();
      await _loadData();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      Logger.error('Error submitting appointment request', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // (Removed) _refreshAppointmentStatus was unused; rely on _loadData and targeted updates instead.

  // Method to determine if an appointment should be archived
  bool _shouldArchiveAppointment(AppointmentModel appointment) {
    final now = DateTime.now();

    // Archive appointments that are:
    // 1. Completed older than 30 days
    // 2. Cancelled or denied more than 7 days ago
    // 3. Accepted/approved but the date has passed (expired) more than 3 days ago

    if (appointment.status == AppointmentStatus.completed) {
      // Only archive completed appointments that are older than 30 days
      return now.difference(appointment.appointmentDate).inDays > 30;
    }

    if ((appointment.status == AppointmentStatus.cancelled ||
            appointment.status == AppointmentStatus.denied) &&
        now.difference(appointment.createdAt).inDays > 7) {
      return true;
    }

    if ((appointment.status == AppointmentStatus.accepted ||
            appointment.status == AppointmentStatus.approved) &&
        appointment.appointmentDate.isBefore(now) &&
        now.difference(appointment.appointmentDate).inDays > 3) {
      return true;
    }

    return false;
  }

  // Method to format harsh response messages into gentler ones
  String _formatResponseMessage(String message) {
    // Convert harsh messages to gentler alternatives
    if (message.toLowerCase().contains('declined by psychologist')) {
      return 'Unavailable date';
    }

    // Add more message transformations as needed
    if (message.toLowerCase().contains('rejected')) {
      return 'Unavailable date';
    }

    if (message.toLowerCase().contains('denied')) {
      return 'Unavailable date';
    }

    // Return original message if no transformation needed
    return message;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Your Psychologist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: const Color(0xFF3AA772),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [],
      ),
      floatingActionButton: _isLoading || _psychologist == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF3AA772),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.event_available),
              label: const Text('Request'),
              onPressed: _openAppointmentRequestSheet,
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
            _isLoadingAppointments = true;
          });
          await _loadData();
        },
        color: const Color(0xFF3AA772),
        child: _isLoading && _psychologist == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3AA772)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Psychologist information section
                    _buildPsychologistInfo(),

                    // Divider
                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),

                    // If no psychologist, show informative message
                    if (_psychologist == null) ...[
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.person_off_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Psychologist Assigned',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'A psychologist will be assigned to you by an administrator. This typically happens after your initial assessment.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Please contact support if you have questions about your psychologist assignment.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Request appointment section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Appointment Requests',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Compact status filter
                            DropdownButtonFormField<String>(
                              value: _selectedFilter,
                              items: _filterOptions
                                  .map((f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedFilter = value);
                              },
                              decoration: InputDecoration(
                                labelText: 'Filter by status',
                                prefixIcon:
                                    const Icon(Icons.filter_list_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Appointments list
                            _buildAppointmentsList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // Opens the appointment request as a modern bottom sheet to keep the page uncluttered
  void _openAppointmentRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppointmentForm(inSheet: true),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPsychologistInfo() {
    const gradient = LinearGradient(
      colors: [Color(0xFF3AA772), Color(0xFF2F8E6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern header
        Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            20,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: ClipOval(
                  child: (_psychologist?.imageUrl != null &&
                          _psychologist!.imageUrl!.isNotEmpty)
                      ? Image.network(
                          _psychologist!.imageUrl!,
                          fit: BoxFit.cover,
                          width: 84,
                          height: 84,
                          errorBuilder: (context, error, stack) {
                            Logger.error(
                                'Failed to load psychologist image', error);
                            return _buildProfileInitials();
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : _buildProfileInitials(),
                ),
              ),
              const SizedBox(width: 16),
              // Name + contact chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _psychologist?.name ?? 'Your Psychologist',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_psychologist?.specialization != null &&
                        _psychologist!.specialization.isNotEmpty)
                      Text(
                        _psychologist!.specialization,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_psychologist?.contactPhone != null &&
                            _psychologist!.contactPhone != 'N/A')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.7)),
                              backgroundColor: Colors.white.withOpacity(0.12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.phone,
                                size: 16, color: Colors.white),
                            label: Text(_psychologist!.contactPhone,
                                overflow: TextOverflow.ellipsis),
                            onPressed: () async {
                              final uri = Uri(
                                  scheme: 'tel',
                                  path: _psychologist!.contactPhone);
                              try {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Cannot launch dialer on this device')),
                                    );
                                  }
                                }
                              } catch (e) {
                                Logger.error('Failed to launch dialer', e);
                              }
                            },
                          ),
                        if (_psychologist?.contactEmail != null &&
                            _psychologist!.contactEmail.isNotEmpty &&
                            _psychologist!.contactEmail != 'N/A')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.7)),
                              backgroundColor: Colors.white.withOpacity(0.12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.email_outlined,
                                size: 16, color: Colors.white),
                            label: Text(_psychologist!.contactEmail,
                                overflow: TextOverflow.ellipsis),
                            onPressed: () async {
                              // Copy email directly to clipboard
                              await Clipboard.setData(ClipboardData(
                                  text: _psychologist!.contactEmail));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Email copied to clipboard!'),
                                    backgroundColor: const Color(0xFF3AA772),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Biography
        if (_psychologist != null &&
            _psychologist!.biography != 'No biography available')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 18, color: Color(0xFF3AA772)),
                      SizedBox(width: 8),
                      Text('Biography',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _psychologist!.biography,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileInitials() {
    if (_psychologist == null) {
      return const Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: Color(0xFF3AA772),
        ),
      );
    }

    return Center(
      child: Text(
        _psychologist!.initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3AA772),
        ),
      ),
    );
  }

  Widget _buildAppointmentForm({bool inSheet = true}) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF3AA772), width: 1.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Request an Appointment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 14),

        // Date + Time row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date',
                  hintText: 'Select a date',
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  enabledBorder: inputBorder,
                  focusedBorder: focusedBorder,
                  errorBorder: inputBorder.copyWith(
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  border: inputBorder,
                  errorText: _fieldErrors['date']!.isNotEmpty
                      ? _fieldErrors['date']
                      : null,
                ),
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _timeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Time',
                  hintText: 'Select a time',
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.access_time_rounded),
                  enabledBorder: inputBorder,
                  focusedBorder: focusedBorder,
                  errorBorder: inputBorder.copyWith(
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  border: inputBorder,
                  errorText: _fieldErrors['time']!.isNotEmpty
                      ? _fieldErrors['time']
                      : null,
                ),
                onTap: () => _selectTime(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Reason field
        TextField(
          controller: _reasonController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Reason for Appointment',
            hintText: 'Briefly describe what you’d like to discuss',
            filled: true,
            fillColor: Colors.grey[50],
            enabledBorder: inputBorder,
            focusedBorder: focusedBorder,
            errorBorder: inputBorder.copyWith(
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            border: inputBorder,
            errorText: _fieldErrors['reason']!.isNotEmpty
                ? _fieldErrors['reason']
                : null,
          ),
        ),

        const SizedBox(height: 18),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _resetForm();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitAppointmentRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3AA772),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
    try {
      // Show loading animation while appointments are being loaded
      if (_isLoadingAppointments) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF3AA772),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading appointments...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (_appointments.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No appointment history',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Request your first appointment above',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Filter appointments first based on selected filter
      List<AppointmentModel> filteredAppointments = _appointments;

      if (_selectedFilter != 'All') {
        filteredAppointments = _appointments.where((apt) {
          switch (_selectedFilter) {
            case 'Pending':
              // True pending: pending status with no response message
              return apt.status == AppointmentStatus.pending &&
                  (apt.responseMessage == null || apt.responseMessage!.isEmpty);
            case 'Accepted':
              // Accepted: either officially accepted/approved OR pending with positive response
              return apt.status == AppointmentStatus.accepted ||
                  apt.status == AppointmentStatus.approved ||
                  (apt.status == AppointmentStatus.pending &&
                      apt.responseMessage != null &&
                      apt.responseMessage!.isNotEmpty &&
                      !apt.responseMessage!.toLowerCase().contains('declined'));
            case 'Expired':
              return apt.status == AppointmentStatus.expired;
            case 'Unavailable':
              // Unavailable: officially denied/cancelled OR pending with decline response
              return apt.status == AppointmentStatus.denied ||
                  apt.status == AppointmentStatus.cancelled ||
                  (apt.status == AppointmentStatus.pending &&
                      apt.responseMessage != null &&
                      apt.responseMessage!.toLowerCase().contains('declined'));
            case 'Completed':
              return apt.status == AppointmentStatus.completed;
            default:
              return true;
          }
        }).toList();

        // If filter is applied and no results, show empty state
        if (filteredAppointments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No $_selectedFilter appointments found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'All';
                      });
                    },
                    child: const Text('Clear filter'),
                  ),
                ],
              ),
            ),
          );
        }
      }

      // Separate active and archived appointments
      final activeAppointments = <AppointmentModel>[];
      final archivedAppointments = <AppointmentModel>[];

      for (var appointment in filteredAppointments) {
        if (_shouldArchiveAppointment(appointment)) {
          archivedAppointments.add(appointment);
        } else {
          activeAppointments.add(appointment);
        }
      }

      // Group active appointments by status
      final upcomingAppointments = activeAppointments
          .where((apt) =>
              (apt.status == AppointmentStatus.accepted ||
                  apt.status == AppointmentStatus.approved) &&
              apt.appointmentDate.isAfter(DateTime.now()))
          .toList();

      final pendingAppointments = activeAppointments
          .where((apt) =>
              apt.status == AppointmentStatus.pending &&
              (apt.responseMessage == null || apt.responseMessage!.isEmpty))
          .toList();

      final acceptedAppointments = activeAppointments
          .where((apt) =>
              apt.status == AppointmentStatus.pending &&
              apt.responseMessage != null &&
              apt.responseMessage!.isNotEmpty &&
              !apt.responseMessage!.toLowerCase().contains('declined'))
          .toList();

      final completedAppointments = activeAppointments
          .where((apt) => apt.status == AppointmentStatus.completed)
          .toList();

      final expiredAppointments = activeAppointments
          .where((apt) => apt.status == AppointmentStatus.expired)
          .toList();

      final pastAppointments = activeAppointments
          .where((apt) =>
              apt.status != AppointmentStatus.completed &&
              ((apt.status == AppointmentStatus.accepted ||
                      apt.status == AppointmentStatus.approved) &&
                  apt.appointmentDate.isBefore(DateTime.now())))
          .toList();

      final cancelledAppointments = activeAppointments
          .where((apt) =>
              apt.status == AppointmentStatus.cancelled ||
              apt.status == AppointmentStatus.denied ||
              (apt.status == AppointmentStatus.pending &&
                  apt.responseMessage != null &&
                  apt.responseMessage!.toLowerCase().contains('declined')))
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active appointments
          if (activeAppointments.isEmpty && !_showArchivedAppointments)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active appointments',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Upcoming appointments
            if (upcomingAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Upcoming Appointments', upcomingAppointments, Colors.green),
              const SizedBox(height: 16),
            ],

            // Pending appointment requests
            if (pendingAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Pending Requests', pendingAppointments, Colors.orange),
              const SizedBox(height: 16),
            ],

            // Accepted appointment requests
            if (acceptedAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Accepted Requests', acceptedAppointments, Colors.green),
              const SizedBox(height: 16),
            ],

            // Expired appointment requests
            if (expiredAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Expired Requests', expiredAppointments, Colors.red.shade400),
              const SizedBox(height: 16),
            ],

            // Completed appointments
            if (completedAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Completed Appointments', completedAppointments, Colors.grey),
              const SizedBox(height: 16),
            ],

            // Past appointments
            if (pastAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Recent Past Appointments', pastAppointments, Colors.blue),
              const SizedBox(height: 16),
            ],

            // Cancelled appointments
            if (cancelledAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Unavailable', cancelledAppointments, Colors.grey),
              const SizedBox(height: 16),
            ],
          ],

          // Archive toggle button
          if (archivedAppointments.isNotEmpty && _selectedFilter == 'All')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showArchivedAppointments = !_showArchivedAppointments;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showArchivedAppointments
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showArchivedAppointments
                          ? 'Hide archived appointments'
                          : 'Show archived appointments (${archivedAppointments.length})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Archived appointments (only show if toggle is on and no filter is applied)
          if (_showArchivedAppointments &&
              archivedAppointments.isNotEmpty &&
              _selectedFilter == 'All')
            _buildAppointmentCategory(
                'Archived Appointments', archivedAppointments, Colors.grey),
        ],
      );
    } catch (e) {
      // Fallback UI in case of any error
      Logger.error('Error building appointments list', e);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading appointments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3AA772),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAppointmentCategory(
      String title, List<AppointmentModel> appointments, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...appointments
            .map((appointment) => _buildAppointmentCard(appointment, color))
            .toList(),
      ],
    );
  }

  Widget _buildAppointmentCard(
      AppointmentModel appointment, Color statusColor) {
    try {
      final formattedDate =
          DateFormat('MMM dd, yyyy').format(appointment.appointmentDate);
      final formattedTime =
          DateFormat('h:mm a').format(appointment.appointmentDate);

      // Determine the correct status to display
      String displayStatus = appointment.statusText;

      // Check if response message indicates decline/denial
      if (appointment.responseMessage != null &&
          appointment.responseMessage!.toLowerCase().contains('declined')) {
        displayStatus = "Unavailable";
      }
      // If the appointment has a response message but is still pending,
      // and it's not declined, display it as "Accepted" instead
      else if (appointment.status == AppointmentStatus.pending &&
          appointment.responseMessage != null &&
          appointment.responseMessage!.isNotEmpty) {
        displayStatus = "Accepted";
      }

      final now = DateTime.now();
      final isPastAppointment = appointment.appointmentDate.isBefore(now);
      final canMarkAsCompleted =
          (appointment.status == AppointmentStatus.accepted ||
                  appointment.status == AppointmentStatus.approved) &&
              isPastAppointment &&
              appointment.status != AppointmentStatus.completed;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _statusChip(displayStatus, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.subject_outlined,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.reason,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[900], height: 1.4),
                    ),
                  ),
                ],
              ),
              if (appointment.responseMessage != null &&
                  appointment.responseMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.forum_outlined,
                          size: 18, color: Color(0xFF3AA772)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatResponseMessage(appointment.responseMessage!),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canMarkAsCompleted) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final success =
                            await _supabaseService.updateAppointmentStatus(
                                appointment.id, 'completed');
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Appointment marked as completed'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Failed to update appointment status'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark as Completed'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      // Fallback card in case of errors
      Logger.error('Error displaying appointment card', e);
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Error displaying this appointment',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Modern status chip used in appointment cards
  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // (removed) rounded app bar icon helper after removing actions
}
