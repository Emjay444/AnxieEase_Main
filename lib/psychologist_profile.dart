import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/psychologist_model.dart';
import 'models/appointment_model.dart';
import 'services/supabase_service.dart';
import 'utils/logger.dart';
import 'screens/psychologist_list_screen.dart';

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
  bool _showAppointmentForm = false;
  bool _showArchivedAppointments = false;

  // Filter state
  String _selectedFilter = 'All'; // Default filter
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Accepted',
    'Denied',
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
    setState(() {
      _isLoading = true;
    });

    try {
      // First attempt to auto-archive old appointments
      try {
        final archivedCount =
            await _supabaseService.autoArchiveOldAppointments();
        if (archivedCount > 0) {
          Logger.info('Auto-archived $archivedCount old appointments');
        }
      } catch (e) {
        // Don't fail if auto-archiving fails
        Logger.error('Error auto-archiving appointments', e);
      }

      // Load psychologist data
      final psychologistData = await _supabaseService.getAssignedPsychologist();
      if (psychologistData != null) {
        try {
          setState(() {
            _psychologist = PsychologistModel.fromJson(psychologistData);
          });

          // Try to get latest profile picture URL if available
          if (_psychologist != null) {
            final latestPictureUrl = await _supabaseService
                .getPsychologistProfilePictureUrl(_psychologist!.id);
            if (latestPictureUrl != null && latestPictureUrl.isNotEmpty) {
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
          }
        } catch (e) {
          Logger.error('Error parsing psychologist data', e);
          // Show error but don't crash
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Error loading psychologist details. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Handle case where no psychologist is found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No psychologist is assigned. Please select one from the list.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Automatically navigate to psychologist selection screen
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PsychologistListScreen(),
                ),
              ).then((_) => _loadData());
            }
          });
        }
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
          await _supabaseService.refreshAppointmentStatus(data['id']);
        }

        // Add to the appointments list
        appointments.add(AppointmentModel.fromJson(data));
      }

      setState(() {
        _appointments = appointments;
      });
    } catch (e) {
      Logger.error('Error loading psychologist data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      setState(() {
        _showAppointmentForm = false;
      });
      await _loadData();
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

  // Method to refresh a specific appointment's status
  Future<void> _refreshAppointmentStatus(AppointmentModel appointment) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Call the API to get the latest status
      final updatedAppointment =
          await _supabaseService.refreshAppointmentStatus(appointment.id);

      if (updatedAppointment != null) {
        // Update the appointment in the list
        setState(() {
          final index =
              _appointments.indexWhere((apt) => apt.id == appointment.id);
          if (index >= 0) {
            _appointments[index] =
                AppointmentModel.fromJson(updatedAppointment);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment status refreshed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error refreshing appointment status', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing status: ${e.toString()}'),
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
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3AA772),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3AA772)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF3AA772),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Psychologist information section
                    _buildPsychologistInfo(),

                    // Divider
                    Container(
                      height: 8,
                      color: Colors.grey[100],
                    ),

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
                              Row(
                                children: [
                                  // Refresh button for appointments
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 20),
                                    onPressed: _loadData,
                                    tooltip: 'Refresh appointments',
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (_psychologist != null &&
                                      !_showAppointmentForm)
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showAppointmentForm = true;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3AA772),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: const Text('Request'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Filter options
                          if (!_showAppointmentForm) ...[
                            Container(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _filterOptions.map((filter) {
                                  final isSelected = _selectedFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: Text(filter),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedFilter = filter;
                                        });
                                      },
                                      backgroundColor: Colors.grey[200],
                                      selectedColor: const Color(0xFF3AA772)
                                          .withOpacity(0.2),
                                      checkmarkColor: const Color(0xFF3AA772),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF3AA772)
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Show appointment form or appointment list
                          if (_showAppointmentForm)
                            _buildAppointmentForm()
                          else
                            _buildAppointmentsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPsychologistInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Psychologist photo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF3AA772).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF3AA772).withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: _psychologist?.imageUrl != null &&
                        _psychologist!.imageUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _psychologist!.imageUrl!,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) {
                            Logger.error(
                                'Failed to load psychologist image: ${_psychologist!.imageUrl}',
                                error);
                            return _buildProfileInitials();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2.0,
                                color: const Color(0xFF3AA772),
                              ),
                            );
                          },
                        ),
                      )
                    : _buildProfileInitials(),
              ),
              const SizedBox(width: 16),
              // Psychologist details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _psychologist?.name ?? 'No psychologist assigned',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Contact information
                    if (_psychologist != null &&
                        _psychologist!.contactPhone != 'N/A') ...[
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _psychologist!.contactPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Biography section
          if (_psychologist != null &&
              _psychologist!.biography != 'No biography available') ...[
            Text(
              'Biography',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _psychologist!.biography,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
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

  Widget _buildAppointmentForm() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request an Appointment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            // Date field
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                hintText: 'Select a date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _fieldErrors['date']!.isNotEmpty
                    ? _fieldErrors['date']
                    : null,
              ),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),
            // Time field
            TextField(
              controller: _timeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Time',
                hintText: 'Select a time',
                prefixIcon: const Icon(Icons.access_time),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _fieldErrors['time']!.isNotEmpty
                    ? _fieldErrors['time']
                    : null,
              ),
              onTap: () => _selectTime(context),
            ),
            const SizedBox(height: 16),
            // Reason field
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for Appointment',
                hintText: 'Please describe the reason for your appointment',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _fieldErrors['reason']!.isNotEmpty
                    ? _fieldErrors['reason']
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAppointmentForm = false;
                      _resetForm();
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _submitAppointmentRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3AA772),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    try {
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
              return apt.status == AppointmentStatus.pending;
            case 'Accepted':
              return apt.status == AppointmentStatus.accepted ||
                  apt.status == AppointmentStatus.approved;
            case 'Denied':
              return apt.status == AppointmentStatus.denied ||
                  apt.status == AppointmentStatus.cancelled;
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
          .where((apt) => apt.status == AppointmentStatus.pending)
          .toList();

      final completedAppointments = activeAppointments
          .where((apt) => apt.status == AppointmentStatus.completed)
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
              apt.status == AppointmentStatus.denied)
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

            // Completed appointments
            if (completedAppointments.isNotEmpty) ...[
              _buildAppointmentCategory(
                  'Completed Appointments', completedAppointments, Colors.teal),
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
                  'Recent Cancelled/Denied', cancelledAppointments, Colors.red),
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
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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

      // If the appointment has a response message but is still pending,
      // display it as "Accepted" instead
      if (appointment.status == AppointmentStatus.pending &&
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

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Reason:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appointment.reason,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              if (appointment.responseMessage != null &&
                  appointment.responseMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Response:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.responseMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // Add action buttons if appropriate
              if (canMarkAsCompleted) ...[
                const SizedBox(height: 16),
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
                          _loadData(); // Refresh data
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
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark as Completed'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
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
}
