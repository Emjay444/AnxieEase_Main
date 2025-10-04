import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check and update expired appointments when app starts or user views appointments
  Future<void> checkAndExpireAppointments() async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));

      print(
          '🔍 Checking for appointments created before: ${cutoffTime.toIso8601String()}');

      // Query pending appointments older than 24 hours
      final response = await _supabase
          .from('appointments')
          .select()
          .eq('status', 'pending')
          .lt('created_at', cutoffTime.toIso8601String());

      final pendingAppointments = response as List<dynamic>?;

      if (pendingAppointments == null || pendingAppointments.isEmpty) {
        print('ℹ️ No pending appointments found past deadline');
        return;
      }

      print('📋 Found ${pendingAppointments.length} appointments to expire');

      int expiredCount = 0;
      int errorCount = 0;

      // Process each overdue appointment
      for (final appointment in pendingAppointments) {
        try {
          await _expireAppointment(appointment);
          expiredCount++;
          print('✅ Successfully expired appointment ${appointment['id']}');
        } catch (error) {
          errorCount++;
          print('❌ Error expiring appointment ${appointment['id']}: $error');
        }
      }

      print(
          '📊 Expiration summary: ✅ Expired: $expiredCount, ❌ Errors: $errorCount');
    } catch (error) {
      print('❌ Error in checkAndExpireAppointments: $error');
    }
  }

  /// Expire a single appointment
  Future<void> _expireAppointment(Map<String, dynamic> appointment) async {
    final now = DateTime.now();

    // Update appointment status to expired
    await _supabase.from('appointments').update({
      'status': 'expired',
      'response_message': 'Appointment request expired after 24-hour deadline. '
          'Created on ${DateTime.parse(appointment['created_at']).toLocal().toString().split(' ')[0]}, '
          'expired on ${now.toLocal().toString().split(' ')[0]}.',
      'updated_at': now.toIso8601String(),
    }).eq('id', appointment['id']);

    // Create notification for user
    await _createExpirationNotification(appointment, now);
  }

  /// Create notification about appointment expiration
  Future<void> _createExpirationNotification(
      Map<String, dynamic> appointment, DateTime now) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': appointment['user_id'],
        'title': 'Appointment Request Expired',
        'message': 'Your appointment request from '
            '${DateTime.parse(appointment['created_at']).toLocal().toString().split(' ')[0]} '
            'has expired after 24 hours. Please submit a new request if you still need an appointment.',
        'type': 'info',
        'related_screen': 'psychologist_profile',
        'created_at': now.toIso8601String(),
      });

      print(
          '📬 Created expiration notification for user ${appointment['user_id']}');
    } catch (error) {
      print('⚠️ Failed to create expiration notification: $error');
    }
  }

  /// Check if a specific appointment is expired (for UI display)
  bool isAppointmentExpired(DateTime createdAt) {
    final now = DateTime.now();
    final expirationTime = createdAt.add(const Duration(hours: 24));
    return now.isAfter(expirationTime);
  }

  /// Get time remaining until appointment expires (for countdown display)
  Duration? getTimeUntilExpiration(DateTime createdAt) {
    final now = DateTime.now();
    final expirationTime = createdAt.add(const Duration(hours: 24));

    if (now.isAfter(expirationTime)) {
      return null; // Already expired
    }

    return expirationTime.difference(now);
  }

  /// Format remaining time for display
  String formatTimeUntilExpiration(DateTime createdAt) {
    final remaining = getTimeUntilExpiration(createdAt);

    if (remaining == null) {
      return 'Expired';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${minutes}m remaining';
    }
  }
}
