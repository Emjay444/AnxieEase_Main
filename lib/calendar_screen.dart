import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async'; // For Timer debounce
import 'services/supabase_service.dart';

class DailyLog {
  final List<String> feelings;
  final double stressLevel;
  final List<String> symptoms;
  final DateTime timestamp;
  final String? journal;
  String? id; // Added Supabase ID field (for wellness_logs)
  String? journalId; // Separate journal ID for journals table
  bool sharedWithPsychologist; // Journal sharing status

  DailyLog({
    required this.feelings,
    required this.stressLevel,
    required this.symptoms,
    required this.timestamp,
    this.journal,
    this.id,
    this.journalId,
    this.sharedWithPsychologist = false,
  });

  Map<String, dynamic> toJson() => {
        'feelings': feelings,
        'stressLevel': stressLevel,
        'symptoms': symptoms,
        'timestamp': timestamp.toIso8601String(),
        'journal': journal,
        'id': id,
        'journalId': journalId,
        'sharedWithPsychologist': sharedWithPsychologist,
      };

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
        feelings: List<String>.from(json['feelings']),
        stressLevel: json['stressLevel'].toDouble(),
        symptoms: List<String>.from(json['symptoms']),
        timestamp: DateTime.parse(json['timestamp']),
        journal: json['journal'],
        id: json['id'],
        journalId: json['journalId'],
        sharedWithPsychologist: json['sharedWithPsychologist'] ?? false,
      );

  // Convert to format for Supabase wellness_logs table
  Map<String, dynamic> toSupabaseJson() => {
        'date': DateFormat('yyyy-MM-dd').format(timestamp), // SQL DATE format
        'feelings': feelings,
        'stress_level': stressLevel,
        'symptoms': symptoms,
        'journal': journal,
        'timestamp': timestamp.toIso8601String(), // SQL TIMESTAMPTZ format
        if (id != null) 'id': id, // Include ID if it exists for updates
      };

  // Save this log to Supabase
  Future<void> syncWithSupabase() async {
    try {
      final supabaseService = SupabaseService();
      final data = toSupabaseJson();

      // Print debug info to help troubleshoot
      print(
          'Syncing log with Supabase. Has ID? ${id != null ? 'Yes: $id' : 'No'}');
      print('Log data: $data');

      if (id != null) {
        // If we have an ID, this is an update operation
        print('Performing UPDATE operation for log with ID: $id');
        await supabaseService.updateWellnessLog(data);
        print('Successfully updated log in Supabase with ID: $id');
      } else {
        // If no ID, this is a create operation
        print('Performing CREATE operation for new log');
        await supabaseService.saveWellnessLog(data);
        print('Successfully created new log in Supabase');
      }
    } catch (e) {
      print('Error syncing log to Supabase: $e');
      rethrow;
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Map<DateTime, List<DailyLog>> _dailyLogs = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final SupabaseService _supabaseService = SupabaseService();
  Timer? _saveLogsTimer; // debounce timer
  static const Duration _saveLogsDebounce = Duration(milliseconds: 500);

  // Performance optimization: Cache processed events to avoid recalculation
  final Map<String, List<String>> _eventsCache = {};
  DateTime? _eventsCacheDate;

  // Get user-specific key for SharedPreferences
  String get _userSpecificLogsKey {
    final userId = _supabaseService.client.auth.currentUser?.id ?? 'guest';
    return 'daily_logs_$userId';
  }

  final Map<String, bool> symptoms = {
    'None': false,
    'Unidentified': false,
    'Rapid heartbeat': false,
    'Shortness of breath': false,
    'Dizziness': false,
    'Headache': false,
    'Fatigue': false,
    'Sweating': false,
    'Muscle tension': false,
    'Nausea': false,
    'Shaking or trembling': false,
  };

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _selectedDay = DateTime.now();
    // Check if user is logged in and sync logs
    _syncLogsWithSupabase();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsJson = prefs.getString(_userSpecificLogsKey);

    if (logsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(logsJson);
      setState(() {
        _dailyLogs = decoded.map((key, value) {
          DateTime date = DateTime.parse(key);
          List<dynamic> logsList = value as List<dynamic>;
          return MapEntry(
            _normalizeDate(date),
            logsList.map((log) => DailyLog.fromJson(log)).toList(),
          );
        });
      });
    }
  }

  Future<void> _syncLogsWithSupabase() async {
    // Check if user is authenticated
    if (!_supabaseService.isAuthenticated) return;

    // First sync existing logs from SharedPreferences to Supabase
    try {
      // Flatten the logs into a list
      final List<DailyLog> allLogs = [];
      _dailyLogs.forEach((date, logs) {
        allLogs.addAll(logs);
      });

      // Sync each log to Supabase
      for (var log in allLogs) {
        await log.syncWithSupabase();
      }

      print('Successfully synced ${allLogs.length} logs with Supabase');

      // Fetch logs from Supabase to ensure we have the latest data
      final List<Map<String, dynamic>> supabaseLogs =
          await _supabaseService.getWellnessLogs();

      print('Loaded ${supabaseLogs.length} logs from Supabase');

      // Process Supabase logs
      int logsAdded = 0;
      for (var log in supabaseLogs) {
        final DateTime date = DateTime.parse(log['date']);
        final normalizedDate = _normalizeDate(date);

        if (!_dailyLogs.containsKey(normalizedDate)) {
          _dailyLogs[normalizedDate] = [];
        }

        // Create DailyLog from Supabase data
        final dailyLog = DailyLog(
          feelings: List<String>.from(log['feelings']),
          stressLevel: log['stress_level'].toDouble(),
          symptoms: List<String>.from(log['symptoms']),
          timestamp: DateTime.parse(log['timestamp']),
          journal: log['journal'],
          id: log['id'],
        );

        // Check if this log already exists in the local data
        bool isDuplicate = false;
        for (final existingLog in _dailyLogs[normalizedDate]!) {
          // Compare content to detect duplicates
          if (_areLogsSimilar(existingLog, dailyLog)) {
            isDuplicate = true;
            print('Detected duplicate log based on content similarity');
            break;
          }
        }

        if (!isDuplicate) {
          // Add new log if it doesn't exist locally
          _dailyLogs[normalizedDate]!.add(dailyLog);
          logsAdded++;
        }
      }

      print('Added $logsAdded new logs from Supabase');

      // ALSO fetch journals from the separate journals table
      try {
        final List<Map<String, dynamic>> journalEntries =
            await _supabaseService.getAllJournals();

        print('Loaded ${journalEntries.length} journals from journals table');

        int journalsAdded = 0;
        for (var journalEntry in journalEntries) {
          final DateTime journalDate = DateTime.parse(journalEntry['date']);
          final normalizedDate = _normalizeDate(journalDate);

          if (!_dailyLogs.containsKey(normalizedDate)) {
            _dailyLogs[normalizedDate] = [];
          }

          // Check if this journal already exists (by journalId)
          bool journalExists = _dailyLogs[normalizedDate]!
              .any((log) => log.journalId == journalEntry['id']);

          if (!journalExists) {
            // Create a journal-only DailyLog entry
            final journalLog = DailyLog(
              feelings: [],
              stressLevel: 0,
              symptoms: [],
              timestamp: DateTime.parse(journalEntry['created_at']),
              journal: journalEntry['content'],
              journalId: journalEntry['id'],
              sharedWithPsychologist:
                  journalEntry['shared_with_psychologist'] ?? false,
            );

            _dailyLogs[normalizedDate]!.add(journalLog);
            journalsAdded++;
          } else {
            // Update existing entry with journal info if it has the same journalId
            final existingIndex = _dailyLogs[normalizedDate]!
                .indexWhere((log) => log.journalId == journalEntry['id']);

            if (existingIndex != -1) {
              // Update the sharing status if it changed
              final existing = _dailyLogs[normalizedDate]![existingIndex];
              if (existing.sharedWithPsychologist !=
                  (journalEntry['shared_with_psychologist'] ?? false)) {
                _dailyLogs[normalizedDate]![existingIndex]
                        .sharedWithPsychologist =
                    journalEntry['shared_with_psychologist'] ?? false;
                logsAdded++; // Trigger save
              }
            }
          }
        }

        print('Added $journalsAdded new journal entries from journals table');
        logsAdded += journalsAdded;
      } catch (e) {
        print('Error loading journals from journals table: $e');
        // Don't fail the whole sync if journals fail
      }

      // Save updated logs to local storage
      if (logsAdded > 0) {
        _saveLogsDebounced();
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      print('Error syncing logs with Supabase: $e');
    }
  }

  // Helper method to determine if two logs are likely the same entry
  bool _areLogsSimilar(DailyLog log1, DailyLog log2) {
    // Check if stress levels are the same
    if (log1.stressLevel != log2.stressLevel) {
      return false;
    }

    // Check if symptoms are the same
    if (log1.symptoms.length != log2.symptoms.length) {
      return false;
    }

    for (final symptom in log1.symptoms) {
      if (!log2.symptoms.contains(symptom)) {
        return false;
      }
    }

    // Check if feelings/moods are the same
    if (log1.feelings.length != log2.feelings.length) {
      return false;
    }

    for (final feeling in log1.feelings) {
      if (!log2.feelings.contains(feeling)) {
        return false;
      }
    }

    // If we got here, the logs are very similar in content
    return true;
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encoded = _dailyLogs.map((key, value) {
      return MapEntry(
        _normalizeDate(key).toIso8601String(),
        value.map((log) => log.toJson()).toList(),
      );
    });
    await prefs.setString(_userSpecificLogsKey, jsonEncode(encoded));

    // Clear cache when logs are saved
    _eventsCache.clear();
  }

  void _saveLogsDebounced() {
    _saveLogsTimer?.cancel();
    _saveLogsTimer = Timer(_saveLogsDebounce, _saveLogs);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  bool _isFutureDate(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.isAfter(normalizedToday);
  }

  void _showFutureDateError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Cannot add logs for future dates. Please select today or a past date.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  List<String> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    final cacheKey = normalizedDay.toIso8601String();

    // Return cached result if available and cache is still valid
    if (_eventsCacheDate != null &&
        _eventsCacheDate!.year == DateTime.now().year &&
        _eventsCacheDate!.month == DateTime.now().month &&
        _eventsCache.containsKey(cacheKey)) {
      return _eventsCache[cacheKey]!;
    }

    final logs = _dailyLogs[normalizedDay];
    if (logs == null) return [];

    Set<String> events = {}; // Using Set to avoid duplicates
    for (var log in logs) {
      // Add 'log' marker only if there are moods, symptoms or stress level
      if (log.feelings.isNotEmpty ||
          log.symptoms.isNotEmpty ||
          log.stressLevel > 0) {
        events.add('log');
      }
      // Add 'journal' marker if there's a journal entry
      if (log.journal != null && log.journal!.isNotEmpty) {
        events.add('journal');
      }
    }

    final result = events.toList();

    // Cache the result
    _eventsCache[cacheKey] = result;
    _eventsCacheDate = DateTime.now();

    return result; // Convert Set back to List
  }

  void _deleteLog(DateTime date, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final key = _normalizeDate(date);
              final logToDelete = _dailyLogs[key]?[index];

              setState(() {
                _dailyLogs[key]?.removeAt(index);
                if (_dailyLogs[key]?.isEmpty ?? false) {
                  _dailyLogs.remove(key);
                }
              });

              _saveLogsDebounced();

              // Also delete from Supabase if the user is authenticated
              if (logToDelete != null) {
                try {
                  if (_supabaseService.isAuthenticated) {
                    // Format date for Supabase
                    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
                    await _supabaseService.deleteWellnessLog(
                        formattedDate, logToDelete.timestamp);
                  }
                } catch (e) {
                  print('Error deleting log from Supabase: $e');
                  // Don't show error to user as local deletion still worked
                }
              }

              Navigator.pop(context);

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log deleted successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDailyLog(DateTime selectedDate, List<String> selectedMoods,
      double stressLevel, List<String> selectedSymptoms,
      [DailyLog? existingLog, String? journal]) async {
    final normalizedDate = _normalizeDate(selectedDate);
    DailyLog? logToSync;

    print(
        '_saveDailyLog called, updating existing log: ${existingLog != null}');
    if (existingLog != null) {
      print(
          'Existing log ID: ${existingLog.id}, timestamp: ${existingLog.timestamp}');
    }

    setState(() {
      if (!_dailyLogs.containsKey(normalizedDate)) {
        _dailyLogs[normalizedDate] = [];
      }

      if (existingLog != null) {
        // Find and update existing log
        final index = _dailyLogs[normalizedDate]!
            .indexWhere((log) => log.timestamp == existingLog.timestamp);
        if (index != -1) {
          print('Updating existing log with ID: ${existingLog.id}');
          logToSync = DailyLog(
            feelings: selectedMoods,
            stressLevel: stressLevel,
            symptoms: selectedSymptoms,
            timestamp: existingLog.timestamp,
            journal: journal,
            id: existingLog.id, // Preserve the existing ID for update
          );
          _dailyLogs[normalizedDate]![index] = logToSync!;
          print(
              'Updated existing log in local storage at index $index, ID: ${logToSync!.id}');
        } else {
          print(
              'Warning: Could not find existing log to update in local storage');
        }
      } else {
        // Create new log
        print('Creating new log');
        logToSync = DailyLog(
          feelings: selectedMoods,
          stressLevel: stressLevel,
          symptoms: selectedSymptoms,
          timestamp: DateTime.now(),
          journal: journal,
        );
        _dailyLogs[normalizedDate]!.add(logToSync!);
      }
    });

    _saveLogsDebounced();

    // Sync with Supabase
    try {
      print(
          'Starting Supabase sync for ${existingLog != null ? 'EXISTING' : 'NEW'} log');
      if (logToSync != null) {
        print(
            'Log to sync - Has ID: ${logToSync!.id != null ? 'Yes: ${logToSync!.id}' : 'No'}, Timestamp: ${logToSync!.timestamp}');
        await logToSync!.syncWithSupabase();
        print('Supabase sync completed successfully');
      }

      // Create notifications for mood logs
      final DateTime notificationTime =
          (logToSync?.timestamp ?? DateTime.now()).toUtc();

      // Only create ONE notification per log entry - check what was logged
      bool hasHighStress = stressLevel >= 7;
      bool hasSymptoms =
          selectedSymptoms.isNotEmpty && !selectedSymptoms.contains('None');
      bool hasMoods = selectedMoods.isNotEmpty;

      // Priority: Create only ONE notification based on severity
      if (hasHighStress) {
        // High stress takes priority
        await _supabaseService.createNotificationWithTimestamp(
          title: 'High Stress Level Detected',
          message:
              'Your stress level was recorded as ${stressLevel.toInt()}/10. Consider using breathing exercises.',
          type: 'alert',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
          createdAt: notificationTime,
        );
      } else if (hasMoods) {
        // Check if negative mood
        final moodsList = selectedMoods.join(", ");
        final isNegativeMood = selectedMoods.any((mood) =>
            mood.toLowerCase().contains('anxious') ||
            mood.toLowerCase().contains('fearful') ||
            mood.toLowerCase().contains('angry') ||
            mood.toLowerCase().contains('sad') ||
            mood.toLowerCase().contains('pain') ||
            mood.toLowerCase().contains('confused'));

        if (isNegativeMood) {
          await _supabaseService.createNotificationWithTimestamp(
            title: 'Mood Pattern Alert',
            message:
                'You\'ve been feeling $moodsList. Would you like to try some calming exercises?',
            type: 'reminder',
            relatedScreen: 'calendar',
            relatedId: logToSync?.id,
            createdAt: notificationTime,
          );
        }
        // Don't send notification for positive moods - just save silently
      } else if (hasSymptoms) {
        // Only if no high stress or negative mood
        final symptomsList = selectedSymptoms.join(", ");
        await _supabaseService.createNotificationWithTimestamp(
          title: 'Anxiety Symptoms Logged',
          message: 'You reported experiencing: $symptomsList',
          type: 'log',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
          createdAt: notificationTime,
        );
      }
    } catch (e) {
      debugPrint('Error syncing with Supabase: $e');
    }
  }

  void _showFeelingsDialog([DailyLog? existingLog]) {
    if (_selectedDay == null) return;

    // Prevent logging for future dates (only for new logs, allow editing existing logs)
    if (existingLog == null && _isFutureDate(_selectedDay!)) {
      _showFutureDateError();
      return;
    }

    final List<String> moods = [
      'Happy',
      'Fearful',
      'Excited',
      'Angry',
      'Calm',
      'Pain',
      'Boredom',
      'Sad',
      'Awe',
      'Confused',
      'Anxious',
      'Relief',
      'Satisfied'
    ];

    Set<String> selectedMoods = Set<String>.from(existingLog?.feelings ?? []);
    Map<String, bool> selectedSymptoms = Map<String, bool>.from(symptoms);
    double stressLevel = existingLog?.stressLevel ?? 3.0;

    // Extract custom mood if it exists
    String customMoodText = "";
    if (existingLog != null) {
      for (String mood in existingLog.feelings) {
        if (mood.startsWith("Custom: ")) {
          customMoodText = mood.substring(8); // Remove "Custom: " prefix
          selectedMoods.remove(
              mood); // Remove from selected moods as we'll handle it separately
        }
      }

      for (final symptom in existingLog.symptoms) {
        selectedSymptoms[symptom] = true;
      }
    }

    void saveLog() {
      if (_selectedDay != null) {
        final selectedSymptomsList = selectedSymptoms.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

        // Only save if there are selected moods
        if (selectedMoods.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one mood')),
          );
          return;
        }

        // Show loading indicator during save
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // For update operations, don't navigate away immediately
        if (existingLog != null) {
          print('Updating existing log, will wait for completion');
          _saveDailyLog(
            _selectedDay!,
            selectedMoods.toList(),
            stressLevel,
            selectedSymptomsList,
            existingLog,
            existingLog.journal, // Preserve existing journal if updating
          ).then((_) {
            // Close loading indicator
            Navigator.pop(context);
            // Close feelings dialog
            Navigator.pop(context);

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Log updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }).catchError((error) {
            // Close loading indicator
            Navigator.pop(context);

            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating log: $error'),
                backgroundColor: Colors.red,
              ),
            );
          });
        } else {
          // For new logs
          _saveDailyLog(
            _selectedDay!,
            selectedMoods.toList(),
            stressLevel,
            selectedSymptomsList,
          ).then((_) {
            // Close loading indicator
            Navigator.pop(context);
            // Close feelings dialog
            Navigator.pop(context);

            // Show success message for new log
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Log saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }).catchError((error) {
            // Close loading indicator
            Navigator.pop(context);

            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving log: $error'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
      } else {
        Navigator.pop(context);
      }
    }

    void showSymptomsSelector() {
      bool showWarning = false;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildDragHandle(),
                    const SizedBox(height: 12),
                    _buildStepIndicator(current: 3),
                    const SizedBox(height: 12),
                    Text('Select Your Symptoms',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        )),
                    if (showWarning)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please select at least one symptom',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: selectedSymptoms.entries.map((entry) {
                          // Special handling for None option
                          if (entry.key == 'None') {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: entry.value
                                      ? Colors.teal[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: entry.value
                                        ? Colors.teal[700]
                                        : Colors.grey[800],
                                    fontWeight: entry.value
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                value: entry.value,
                                activeColor: Colors.teal[700],
                                onChanged: (bool? value) {
                                  setState(() {
                                    // If selecting None, unselect all others
                                    if (value == true) {
                                      selectedSymptoms.forEach((key, _) {
                                        selectedSymptoms[key] = false;
                                      });
                                      selectedSymptoms['None'] = true;
                                    } else {
                                      selectedSymptoms['None'] = false;
                                    }
                                  });
                                },
                              ),
                            );
                          }

                          // Special handling for Unidentified option
                          if (entry.key == 'Unidentified') {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: entry.value
                                      ? Colors.teal[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: entry.value
                                        ? Colors.teal[700]
                                        : Colors.grey[800],
                                    fontWeight: entry.value
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                value: entry.value,
                                activeColor: Colors.teal[700],
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      // If selecting Unidentified, can't select with other symptoms
                                      selectedSymptoms.forEach((key, _) {
                                        selectedSymptoms[key] = false;
                                      });
                                      selectedSymptoms['Unidentified'] = true;
                                    } else {
                                      selectedSymptoms['Unidentified'] = false;
                                    }
                                  });
                                },
                              ),
                            );
                          }

                          // Regular symptoms
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: entry.value
                                    ? Colors.teal[700]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                entry.key,
                                style: TextStyle(
                                  color: entry.value
                                      ? Colors.teal[700]
                                      : Colors.grey[800],
                                  fontWeight: entry.value
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              value: entry.value,
                              activeColor: Colors.teal[700],
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    // If selecting a regular symptom, unselect None and Unidentified
                                    selectedSymptoms['None'] = false;
                                    selectedSymptoms['Unidentified'] = false;
                                  }
                                  selectedSymptoms[entry.key] = value ?? false;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    _buildModalFooter(
                      onNext: () {
                        // Check if at least one symptom is selected
                        bool hasSelectedSymptom =
                            selectedSymptoms.values.any((value) => value);
                        if (!hasSelectedSymptom) {
                          setState(() {
                            showWarning = true;
                          });
                          return;
                        }
                        saveLog();
                      },
                      buttonText:
                          existingLog != null ? 'Update Log' : 'Save Log',
                      showDelete: existingLog != null,
                      onDelete: existingLog != null
                          ? () => _deleteLog(_selectedDay!, 0)
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    void showStressLevelSelector() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.55,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildDragHandle(),
                    const SizedBox(height: 12),
                    _buildStepIndicator(current: 2),
                    const SizedBox(height: 12),
                    Text('Rate Your Stress Level',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        )),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              stressLevel.round().toString(),
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Text('Low'),
                                Expanded(
                                  child: Slider(
                                    value: stressLevel,
                                    min: 0,
                                    max: 10,
                                    divisions: 10,
                                    activeColor: Colors.teal[700],
                                    inactiveColor: Colors.teal[100],
                                    label: stressLevel.round().toString(),
                                    onChanged: (value) {
                                      setState(() {
                                        stressLevel = value;
                                      });
                                    },
                                  ),
                                ),
                                const Text('High'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildModalFooter(
                      onNext: () {
                        Navigator.pop(context);
                        showSymptomsSelector();
                      },
                      buttonText: 'Next: Symptoms',
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    void showMoodSelector() {
      bool showWarning = false;
      // Controller for custom mood input
      final TextEditingController customMoodController =
          TextEditingController(text: customMoodText);
      // Flag to show custom mood input - set to true if we have a custom mood
      bool showCustomMoodInput = customMoodText.isNotEmpty;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildDragHandle(),
                    const SizedBox(height: 12),
                    _buildStepIndicator(current: 1),
                    const SizedBox(height: 12),
                    Text('Select Your Moods',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        )),
                    if (showWarning)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please select at least one mood',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Custom mood input button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          setState(
                              () => showCustomMoodInput = !showCustomMoodInput);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: showCustomMoodInput
                                ? const Color(0xFF3AA772)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  showCustomMoodInput ? Icons.close : Icons.add,
                                  color: showCustomMoodInput
                                      ? Colors.white
                                      : Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(
                                showCustomMoodInput
                                    ? 'Hide Custom Input'
                                    : "Can't find how you feel? Click here",
                                style: TextStyle(
                                  color: showCustomMoodInput
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Show text input if custom mood is selected
                    if (showCustomMoodInput)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: TextField(
                          controller: customMoodController,
                          decoration: InputDecoration(
                            hintText: 'Describe how you feel...',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!)),
                            prefixIcon: const Icon(Icons.edit,
                                color: Color(0xFF3AA772)),
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                      ),

                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: moods.length,
                          itemBuilder: (context, index) {
                            final mood = moods[index];
                            final isSelected = selectedMoods.contains(mood);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedMoods.remove(mood);
                                  } else {
                                    selectedMoods.add(mood);
                                  }
                                  if (selectedMoods.isNotEmpty)
                                    showWarning = false;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF3AA772),
                                            Color(0xFF2F8E6A)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3AA772)
                                        : Colors.grey.shade300,
                                    width: 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF3AA772)
                                                .withOpacity(0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getMoodIcon(mood),
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      mood,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    _buildModalFooter(
                      onNext: () {
                        // Check if either a predefined mood is selected or a custom mood is entered
                        if (selectedMoods.isEmpty &&
                            (customMoodController.text.isEmpty ||
                                !showCustomMoodInput)) {
                          setState(() {
                            showWarning = true;
                          });
                          return;
                        }

                        // If custom mood is entered, add it to selectedMoods
                        if (showCustomMoodInput &&
                            customMoodController.text.isNotEmpty) {
                          selectedMoods
                              .add("Custom: ${customMoodController.text}");
                        }

                        Navigator.pop(context);
                        showStressLevelSelector();
                      },
                      buttonText: 'Next: Stress Level',
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    // Start with the mood selector
    showMoodSelector();
  }

  // New reusable UI helpers
  Widget _buildDragHandle() => Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Widget _buildStepIndicator({required int current}) {
    const steps = [1, 2, 3];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((s) {
        final active = s == current;
        return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 8,
            width: active ? 34 : 8,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF3AA772) : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ));
      }).toList(),
    );
  }

  Widget _buildModalHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalFooter({
    required VoidCallback onNext,
    required String buttonText,
    bool showDelete = false,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showDelete && onDelete != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMoodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'fearful':
        return Icons.sentiment_very_dissatisfied;
      case 'excited':
        return Icons.mood;
      case 'angry':
        return Icons.mood_bad;
      case 'calm':
        return Icons.sentiment_satisfied;
      case 'pain':
        return Icons.healing;
      case 'boredom':
        return Icons.sentiment_neutral;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'awe':
        return Icons.star;
      case 'confused':
        return Icons.psychology;
      case 'anxious':
        return Icons.warning;
      case 'relief':
        return Icons.spa;
      case 'satisfied':
        return Icons.thumb_up;
      default:
        return Icons.mood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3AA772)),
        title: const Text(
          'Calendar Logs',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // Emphasized calendar view toggle button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF007AFF).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                _calendarFormat == CalendarFormat.month
                    ? Icons.view_week_rounded
                    : Icons.calendar_view_month_rounded,
                color: const Color(0xFF007AFF),
                size: 24,
              ),
              tooltip: _calendarFormat == CalendarFormat.month
                  ? 'Switch to Week View'
                  : 'Switch to Month View',
              onPressed: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildEnhancedCalendar(context),
          _buildCalendarLegend(),
          if (_selectedDay != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)} ${_selectedDay!.year}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildLogDetails(_selectedDay!),
            ),
          ],
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Journal Button
          FloatingActionButton(
            onPressed: () {
              if (_selectedDay == null) {
                setState(() {
                  _selectedDay = DateTime.now();
                  _focusedDay = DateTime.now();
                });
              }

              // Check if selected day is in the future
              if (_isFutureDate(_selectedDay!)) {
                _showFutureDateError();
                return;
              }

              _showJournalDialog();
            },
            backgroundColor: Colors.purple,
            heroTag: 'journalBtn',
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(Icons.edit_note_rounded, size: 28),
          ),
          const SizedBox(width: 16),
          // Log Entry Button
          FloatingActionButton(
            onPressed: () {
              if (_selectedDay == null) {
                setState(() {
                  _selectedDay = DateTime.now();
                  _focusedDay = DateTime.now();
                });
              }

              // Check if selected day is in the future
              if (_isFutureDate(_selectedDay!)) {
                _showFutureDateError();
                return;
              }

              _showFeelingsDialog();
            },
            backgroundColor: const Color(0xFF007AFF),
            heroTag: 'logBtn',
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  // --- Enhanced Calendar Section ---
  Widget _buildEnhancedCalendar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05), width: 1),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2021, 1, 1),
        lastDay: DateTime.now(), // Prevent future date selection
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableGestures: AvailableGestures.all,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          // Prevent selection of future dates
          if (_isFutureDate(selectedDay)) {
            _showFutureDateError();
            return;
          }

          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        eventLoader: _getEventsForDay,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
          leftChevronIcon: Icon(Icons.chevron_left_rounded,
              color: Color(0xFF3AA772), size: 30),
          rightChevronIcon: Icon(Icons.chevron_right_rounded,
              color: Color(0xFF3AA772), size: 30),
          headerPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: -0.2,
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: -0.2,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          isTodayHighlighted: true,
          todayDecoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3AA772), width: 1.6),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3AA772), Color(0xFF2F8E6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          defaultTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          weekendTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          cellMargin: const EdgeInsets.all(6),
          cellPadding: EdgeInsets.zero,
          markersAutoAligned: false,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _dayCell(context, day),
          todayBuilder: (context, day, focusedDay) =>
              _dayCell(context, day, isToday: true),
          selectedBuilder: (context, day, focusedDay) =>
              _dayCell(context, day, isSelected: true),
          markerBuilder: (context, date, events) =>
              _eventMarkers(context, date, events),
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day,
      {bool isToday = false, bool isSelected = false}) {
    final events = _getEventsForDay(day);
    final avgStress = _averageStressForDay(day);
    Color? stressColor;
    if (avgStress != null) {
      if (avgStress <= 3) {
        stressColor = const Color(0xFF34C759);
      } else if (avgStress <= 7) {
        stressColor = const Color(0xFFFF9500);
      } else {
        stressColor = const Color(0xFFFF3B30);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF3AA772), Color(0xFF2F8E6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Stress ring
          if (stressColor != null && !isSelected)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: stressColor, width: 1.6),
              ),
            ),
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? const Color(0xFF3AA772)
                        : const Color(0xFF1C1C1E),
              ),
            ),
          ),
          if (events.isNotEmpty)
            Positioned(
              bottom: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (events.contains('log'))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3AA772),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (events.contains('journal'))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventMarkers(BuildContext context, DateTime date, List events) {
    // We draw markers inside _dayCell now; return sized box to avoid default
    return const SizedBox.shrink();
  }

  double? _averageStressForDay(DateTime day) {
    final logs = _dailyLogs[_normalizeDate(day)];
    if (logs == null || logs.isEmpty) return null;
    final stressLogs = logs.where((l) => l.stressLevel > 0).toList();
    if (stressLogs.isEmpty) return null;
    final total = stressLogs.fold<double>(0, (sum, l) => sum + l.stressLevel);
    return total / stressLogs.length;
  }

  Widget _buildCalendarLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _legendItem(color: const Color(0xFF3AA772), label: 'Mood / Symptoms'),
          _legendItem(color: Colors.purple, label: 'Journal'),
          Row(
            children: [
              _stressDot(const Color(0xFF34C759)),
              _stressDot(const Color(0xFFFF9500)),
              _stressDot(const Color(0xFFFF3B30)),
              const SizedBox(width: 6),
              const Text(
                'Stress ring',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _stressDot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      );

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  Widget _buildLogDetails(DateTime date) {
    final logs = _dailyLogs[_normalizeDate(date)] ?? [];

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_rounded,
              size: 32,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'No entries yet',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
    }

    // Filter logs based on their type
    final moodLogs = logs
        .where((log) =>
            log.feelings.isNotEmpty ||
            log.symptoms.isNotEmpty ||
            log.stressLevel > 0)
        .toList();
    final journalLogs = logs
        .where((log) =>
            log.journal != null &&
            log.journal!.isNotEmpty &&
            log.feelings.isEmpty &&
            log.symptoms.isEmpty &&
            log.stressLevel == 0)
        .toList();

    return ListView(
      itemExtent: null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        ...moodLogs.map((log) => _buildLogCard(log, date, logs.indexOf(log))),
        ...journalLogs
            .map((log) => _buildJournalOnlyCard(log, date, logs.indexOf(log))),
      ],
    );
  }

  Widget _buildLogCard(DailyLog log, DateTime date, int index) {
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    Color getStressColor(double level) {
      if (level <= 3) {
        return const Color(0xFF34C759); // Low stress
      } else if (level <= 7) {
        return const Color(0xFFFF9500); // Medium stress
      } else {
        return const Color(0xFFFF3B30); // High stress
      }
    }

    final stressColor = getStressColor(log.stressLevel);

    // PERFORMANCE OPTIMIZATION: Wrap expensive widgets in RepaintBoundary
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and Stress Level Row
                  Row(
                    children: [
                      // Time Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stress Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              stressColor.withOpacity(0.1),
                              stressColor.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: stressColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: stressColor.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              log.stressLevel <= 3
                                  ? Icons.sentiment_satisfied_alt_rounded
                                  : log.stressLevel <= 7
                                      ? Icons.sentiment_neutral_rounded
                                      : Icons
                                          .sentiment_very_dissatisfied_rounded,
                              size: 18,
                              color: stressColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Stress ${log.stressLevel.toInt()}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: stressColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (log.feelings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Feelings',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: log.feelings.map((feeling) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF007AFF).withOpacity(0.1),
                                const Color(0xFF007AFF).withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            feeling,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF007AFF),
                              letterSpacing: -0.3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            if (log.symptoms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Symptoms',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: log.symptoms.map((symptom) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF3B30).withOpacity(0.1),
                                const Color(0xFFFF3B30).withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFF3B30).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            symptom,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFFF3B30),
                              letterSpacing: -0.3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalOnlyCard(DailyLog log, DateTime date, int index) {
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    // PERFORMANCE OPTIMIZATION: Wrap expensive widgets in RepaintBoundary
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Journal Entry',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (log.journal != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showFullJournalDialog(log),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.journal!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (log.journal!.length > 80 ||
                                log.journal!.split('\n').length > 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.read_more,
                                      size: 14,
                                      color: Colors.purple.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to read more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Share status indicator (read-only)
                    if (log.journalId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: log.sharedWithPsychologist
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: log.sharedWithPsychologist
                                ? Colors.green.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              log.sharedWithPsychologist
                                  ? Icons.visibility
                                  : Icons.lock_outline,
                              size: 16,
                              color: log.sharedWithPsychologist
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              log.sharedWithPsychologist
                                  ? 'Shared with psychologist'
                                  : 'Private journal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: log.sharedWithPsychologist
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Method to show full journal content in a dialog
  void _showFullJournalDialog(DailyLog log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade400,
                      Colors.purple.shade600,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Journal Entry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DateFormat('d MMMM yyyy, HH:mm')
                                .format(log.timestamp),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    log.journal ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              // Footer with share status
              if (log.journalId != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        log.sharedWithPsychologist
                            ? Icons.visibility
                            : Icons.lock_outline,
                        size: 16,
                        color: log.sharedWithPsychologist
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.sharedWithPsychologist
                            ? 'Shared with psychologist'
                            : 'Private journal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: log.sharedWithPsychologist
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Add a method to add or edit journal entries for existing logs
  void _addJournalToExistingLog(DailyLog log) {
    // Prevent editing logs for future dates
    if (_selectedDay != null && _isFutureDate(_selectedDay!)) {
      _showFutureDateError();
      return;
    }

    TextEditingController journalController =
        TextEditingController(text: log.journal);
    int charCount = log.journal?.length ?? 0;
    int wordCount = log.journal?.trim().isEmpty ?? true
        ? 0
        : log.journal!.trim().split(RegExp(r'\s+')).length;

    void updateCounts(String text) {
      charCount = text.length;
      wordCount =
          text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _buildModalHeader('Update Your Journal'),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.edit_rounded,
                                      size: 18, color: Colors.purple.shade700),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Update your thoughts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.4),
                                    width: 1.2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    TextField(
                                      controller: journalController,
                                      maxLines: null,
                                      expands: true,
                                      onChanged: (val) {
                                        setState(() {
                                          updateCounts(val);
                                        });
                                      },
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: InputDecoration(
                                        hintText: 'Write your thoughts here...',
                                        hintStyle: TextStyle(
                                            color: Colors.purple.shade200),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
                                                18, 18, 18, 50),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        height: 1.55,
                                      ),
                                    ),
                                    Positioned(
                                      left: 14,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$wordCount words',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 14,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.purple.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$charCount chars',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple.shade600,
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
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _updateJournal(log, journalController.text);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    wordCount > 0
                                        ? 'Save Journal ($wordCount words)'
                                        : 'Save Journal',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateJournal(DailyLog log, String journalText) {
    final normalizedDate = _normalizeDate(log.timestamp);

    // Check if the date exists in _dailyLogs
    if (_dailyLogs[normalizedDate] == null) {
      print('Warning: No logs found for date $normalizedDate');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to find the log to update'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final index = _dailyLogs[normalizedDate]!
        .indexWhere((l) => l.timestamp == log.timestamp);

    if (index != -1) {
      print(
          'Updating journal for log with ID: ${log.id}, timestamp: ${log.timestamp}');

      // Create updated log with preserved ID
      final updatedLog = DailyLog(
        feelings: log.feelings,
        stressLevel: log.stressLevel,
        symptoms: log.symptoms,
        timestamp: log.timestamp,
        journal: journalText.isEmpty ? null : journalText,
        id: log.id, // Preserve the ID for updating
      );

      setState(() {
        _dailyLogs[normalizedDate]![index] = updatedLog;
      });

      _saveLogsDebounced();

      // Also sync with Supabase
      _syncJournalUpdate(updatedLog);
    } else {
      print(
          'Warning: Could not find log to update journal at timestamp: ${log.timestamp}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to find the specific log to update'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Separate method for syncing journal updates to handle errors properly
  Future<void> _syncJournalUpdate(DailyLog updatedLog) async {
    try {
      print(
          'Syncing updated journal with Supabase. ID: ${updatedLog.id ?? "None"}, Timestamp: ${updatedLog.timestamp}');
      await updatedLog.syncWithSupabase();

      // Show success message based on whether journal was added, updated, or cleared
      if (mounted) {
        String message;
        if (updatedLog.journal == null || updatedLog.journal!.isEmpty) {
          message = 'Journal cleared successfully';
        } else {
          message = 'Journal updated successfully';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error syncing journal with Supabase: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating journal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New method for the standalone journal entry - Modern UI
  void _showJournalDialog() {
    if (_selectedDay == null) return;

    // Prevent logging for future dates
    if (_isFutureDate(_selectedDay!)) {
      _showFutureDateError();
      return;
    }

    TextEditingController journalController = TextEditingController();
    int wordCount = 0;

    void updateCounts(String text) {
      wordCount =
          text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildDragHandle(),
                    const SizedBox(height: 20),
                    // Header with date
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Write in Your Journal',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(_selectedDay!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Writing prompts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need inspiration? Try one of these:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                'What made me smile today?',
                                'What am I grateful for?',
                                'How am I feeling and why?',
                                'What challenged me today?',
                                'What did I learn?',
                                'What are my hopes?',
                              ].map((prompt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (journalController.text.isEmpty) {
                                        journalController.text =
                                            prompt + '\n\n';
                                        updateCounts(journalController.text);
                                        setState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.shade50,
                                            Colors.orange.shade100,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        prompt,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Text input area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              TextField(
                                controller: journalController,
                                maxLines: null,
                                expands: true,
                                onChanged: (val) {
                                  setState(() {
                                    updateCounts(val);
                                  });
                                },
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  hintText:
                                      'Express your thoughts, feelings, and experiences...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(20),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.6,
                                ),
                              ),
                              // Word count badge
                              Positioned(
                                left: 16,
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.text_fields_rounded,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$wordCount words',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          // Save for myself button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (journalController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please write something first'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                await _saveJournalEntry(
                                    journalController.text, false);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Save for Myself',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Share with psychologist button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (journalController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please write something first'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                await _saveJournalEntry(
                                    journalController.text, true);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.share_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Share with Psychologist',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Method to save a standalone journal entry
  Future<void> _saveJournalEntry(
      String journalText, bool sharedWithPsychologist) async {
    if (journalText.isEmpty) return;

    // If sharing, check for assigned psychologist first
    if (sharedWithPsychologist) {
      try {
        final psychologist = await _supabaseService.getAssignedPsychologist();
        if (psychologist == null) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No Psychologist Assigned'),
                content: const Text(
                    'You need to have an assigned psychologist to share your journals. Please contact support to get a psychologist assigned.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('Error checking psychologist: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final normalizedDate = _normalizeDate(_selectedDay!);
    DailyLog? logToSync;

    setState(() {
      if (!_dailyLogs.containsKey(normalizedDate)) {
        _dailyLogs[normalizedDate] = [];
      }

      // Create a journal-only entry
      logToSync = DailyLog(
        feelings: [], // Empty list for feelings
        stressLevel: 0, // Default stress level
        symptoms: [], // Empty list for symptoms
        timestamp: DateTime.now(),
        journal: journalText,
        sharedWithPsychologist: sharedWithPsychologist,
      );
      _dailyLogs[normalizedDate]!.add(logToSync!);
    });

    _saveLogsDebounced();

    // Save to the separate journals table in Supabase
    try {
      final journalResponse = await _supabaseService.saveJournal(
        content: journalText,
        date: _selectedDay,
        sharedWithPsychologist: sharedWithPsychologist,
      );

      // Update the log with the journal ID
      setState(() {
        logToSync!.journalId = journalResponse['id'];
      });

      _saveLogsDebounced();

      debugPrint(
          '✅ Journal saved to separate journals table: ${journalResponse['id']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sharedWithPsychologist
                ? 'Journal shared with psychologist successfully'
                : 'Journal saved privately'),
            backgroundColor:
                sharedWithPsychologist ? Colors.green : Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      print('Error saving journal to Supabase: $e');
      // Still show error since this is important functionality
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Journal saved locally but not synced: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
