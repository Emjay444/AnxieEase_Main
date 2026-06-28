import 'package:intl/intl.dart';

import '../services/supabase_service.dart';

/// Shared model for a single day's mood/stress/symptom log and/or journal
/// entry, used by both the Calendar screen and the Metrics/charts screen.
///
/// `date` is the calendar day this entry belongs to (the day the user
/// selected), independent of `timestamp` (the actual creation/edit time).
/// Persisting these separately keeps backdated entries pinned to the day
/// they were logged for instead of silently moving to "today" once they
/// round-trip through Supabase's `wellness_logs.date` column.
class DailyLog {
  final List<String> feelings;
  final double stressLevel;
  final List<String> symptoms;
  final DateTime timestamp;
  final DateTime date;
  final String? journal;
  String? id; // wellness_logs row id
  String? journalId; // journals table row id (separate from wellness_logs)
  bool sharedWithPsychologist; // Journal sharing status

  DailyLog({
    required this.feelings,
    required this.stressLevel,
    required this.symptoms,
    required this.timestamp,
    DateTime? date,
    this.journal,
    this.id,
    this.journalId,
    this.sharedWithPsychologist = false,
  }) : date = date ?? DateTime(timestamp.year, timestamp.month, timestamp.day);

  // Local cache (SharedPreferences) JSON round-trip.
  Map<String, dynamic> toJson() => {
        'feelings': feelings,
        'stressLevel': stressLevel,
        'symptoms': symptoms,
        'timestamp': timestamp.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(date),
        'journal': journal,
        'id': id,
        'journalId': journalId,
        'sharedWithPsychologist': sharedWithPsychologist,
      };

  factory DailyLog.fromJson(Map<dynamic, dynamic> json) {
    final timestamp = DateTime.parse(json['timestamp']);
    return DailyLog(
      feelings: List<String>.from(json['feelings'] ?? []),
      stressLevel: (json['stressLevel'] ?? 0.0).toDouble(),
      symptoms: List<String>.from(json['symptoms'] ?? []),
      timestamp: timestamp,
      // Entries cached before the date/timestamp split won't have a 'date'
      // key - fall back to the timestamp's day so old local caches keep
      // working instead of crashing or losing data.
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      journal: json['journal'],
      id: json['id'],
      journalId: json['journalId'],
      sharedWithPsychologist: json['sharedWithPsychologist'] ?? false,
    );
  }

  // Convert to format for Supabase's wellness_logs table. `date` (the
  // selected calendar day) drives the SQL DATE column - never `timestamp`.
  Map<String, dynamic> toSupabaseJson() => {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'feelings': feelings,
        'stress_level': stressLevel,
        'symptoms': symptoms,
        'journal': journal,
        'timestamp': timestamp.toIso8601String(), // SQL TIMESTAMPTZ format
        if (id != null) 'id': id, // Include ID if it exists for updates
      };

  // Save this log to Supabase.
  Future<void> syncWithSupabase() async {
    try {
      final supabaseService = SupabaseService();
      final data = toSupabaseJson();

      if (id != null) {
        // If we have an ID, this is an update operation
        await supabaseService.updateWellnessLog(data);
      } else {
        // If no ID, this is a create operation
        await supabaseService.saveWellnessLog(data);
      }
    } catch (e) {
      print('Error syncing log to Supabase: $e');
      rethrow;
    }
  }
}
