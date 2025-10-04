// Example usage in your appointment widgets

import 'package:flutter/material.dart';
import '../services/appointment_service.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final AppointmentService _appointmentService = AppointmentService();

  AppointmentCard({Key? key, required this.appointment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(appointment['created_at']);
    final isExpired = _appointmentService.isAppointmentExpired(createdAt);
    final timeRemaining =
        _appointmentService.formatTimeUntilExpiration(createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appointment Request',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Text('Psychologist: ${appointment['psychologist_name'] ?? 'N/A'}'),
            Text('Requested: ${createdAt.toLocal().toString().split(' ')[0]}'),

            // Show expiration status
            if (appointment['status'] == 'pending') ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isExpired ? Colors.red.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExpired ? Colors.red : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired
                          ? Icons.schedule_outlined
                          : Icons.timer_outlined,
                      size: 16,
                      color: isExpired ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeRemaining,
                      style: TextStyle(
                        color: isExpired ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String status = appointment['status'] ?? 'unknown';

    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.green;
        break;
      case 'expired':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.blue;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// In your appointments screen, call this when screen loads:
class AppointmentsScreen extends StatefulWidget {
  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
    // Check for expired appointments when user opens this screen
    _appointmentService.checkAndExpireAppointments();
  }

  @override
  Widget build(BuildContext context) {
    // Your appointments UI here
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: FutureBuilder(
        // Your appointments loading logic
        future: _loadAppointments(),
        builder: (context, snapshot) {
          // Your UI building logic
          return Container(); // Replace with your actual UI
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAppointments() async {
    // Your appointment loading logic
    return [];
  }
}
