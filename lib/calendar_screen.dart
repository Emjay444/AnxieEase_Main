import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'services/supabase_service.dart';
import 'providers/notification_provider.dart';

class DailyLog {
  final List<String> feelings;
  final double stressLevel;
  final List<String> symptoms;
  final DateTime timestamp;
  final String? journal;
  String? id; // Added Supabase ID field

  DailyLog({
    required this.feelings,
    required this.stressLevel,
    required this.symptoms,
    required this.timestamp,
    this.journal,
    this.id,
  });

  Map<String, dynamic> toJson() => {
        'feelings': feelings,
        'stressLevel': stressLevel,
        'symptoms': symptoms,
        'timestamp': timestamp.toIso8601String(),
        'journal': journal,
        'id': id,
      };

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
        feelings: List<String>.from(json['feelings']),
        stressLevel: json['stressLevel'].toDouble(),
        symptoms: List<String>.from(json['symptoms']),
        timestamp: DateTime.parse(json['timestamp']),
        journal: json['journal'],
        id: json['id'],
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
  static const String LOGS_KEY = 'daily_logs';
  final SupabaseService _supabaseService = SupabaseService();

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
    final String? logsJson = prefs.getString(LOGS_KEY);

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

      // Save updated logs to local storage
      if (logsAdded > 0) {
        await _saveLogs();
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
    await prefs.setString(LOGS_KEY, jsonEncode(encoded));
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  List<String> _getEventsForDay(DateTime day) {
    final logs = _dailyLogs[_normalizeDate(day)];
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
    return events.toList(); // Convert Set back to List
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

              await _saveLogs();

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

    await _saveLogs();

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

      // Initialize notification variables
      bool notificationCreated = false;

      // Create notification for high stress levels
      if (stressLevel >= 7) {
        await _supabaseService.createNotification(
          title: 'High Stress Level Detected',
          message:
              'Your stress level was recorded as ${stressLevel.toInt()}/10. Consider using breathing exercises.',
          type: 'alert',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
        );
        notificationCreated = true;
      }

      // Create notification for anxiety symptoms if there are any
      if (selectedSymptoms.isNotEmpty && !selectedSymptoms.contains('None')) {
        final symptomsList = selectedSymptoms.join(", ");
        await _supabaseService.createNotification(
          title: 'Anxiety Symptoms Logged',
          message: 'You reported experiencing: $symptomsList',
          type: 'log',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
        );
        notificationCreated = true;
      }

      // Create notification for mood patterns - check for anxious or fearful moods
      if (selectedMoods.any((mood) =>
          mood.toLowerCase().contains('anxious') ||
          mood.toLowerCase().contains('fearful'))) {
        await _supabaseService.createNotification(
          title: 'Mood Pattern Alert',
          message:
              'You\'ve been feeling anxious or fearful. Would you like to try some calming exercises?',
          type: 'reminder',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
        );
        notificationCreated = true;
      }

      // Create notification for journal entry if it exists and has content
      if (journal != null && journal.isNotEmpty) {
        await _supabaseService.createNotification(
          title: 'Journal Entry Added',
          message: 'You\'ve added a new journal entry to your log.',
          type: 'log',
          relatedScreen: 'calendar',
          relatedId: logToSync?.id,
        );
        notificationCreated = true;
      }

      // Trigger notification refresh in NotificationProvider if needed
      if (notificationCreated && mounted) {
        // Find and refresh the notification provider
        final notificationProvider =
            Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.triggerNotificationRefresh();
        debugPrint('Triggered notification refresh after saving log');
      }
    } catch (e) {
      debugPrint('Error syncing with Supabase: $e');
    }
  }

  void _showFeelingsDialog([DailyLog? existingLog]) {
    if (_selectedDay == null) return;

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
            existingLog?.journal, // Preserve existing journal if updating
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
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _buildModalHeader('Select Your Symptoms'),
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
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
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
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _buildModalHeader('Rate Your Stress Level'),
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
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _buildModalHeader('Select Your Moods'),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  showCustomMoodInput = !showCustomMoodInput;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showCustomMoodInput
                                    ? const Color(0xFF3AA772)
                                    : Colors.grey[200],
                                foregroundColor: showCustomMoodInput
                                    ? Colors.white
                                    : Colors.grey[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(showCustomMoodInput
                                  ? "Hide Custom Input"
                                  : "Can't find how you feel? Click here"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Show text input if custom mood is selected
                    if (showCustomMoodInput)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: TextField(
                          controller: customMoodController,
                          decoration: InputDecoration(
                            hintText: "Describe how you feel...",
                            fillColor: Colors.grey[100],
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.edit,
                                color: Color(0xFF3AA772)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          maxLines: 2,
                        ),
                      ),

                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
                                // Clear warning when a mood is selected
                                if (selectedMoods.isNotEmpty) {
                                  showWarning = false;
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3AA772)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3AA772)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getMoodIcon(mood),
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    mood,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF007AFF),
              size: 22,
            ),
            onSelected: (String value) {
              if (value == 'clear_all') {
                _showClearAllDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Logs'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _calendarFormat == CalendarFormat.month
                  ? Icons.view_week_rounded
                  : Icons.calendar_view_month_rounded,
              color: const Color(0xFF007AFF),
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2021, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: _getEventsForDay,
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                markerSize: 8,
                markersMaxCount: 2,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.map((event) {
                      if (event == 'log') {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).primaryColor,
                          ),
                        );
                      } else if (event == 'journal') {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(
                            Icons.edit,
                            size: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        );
                      }
                      return Container();
                    }).toList(),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                  letterSpacing: -0.5,
                ),
                leftChevronIcon: Icon(Icons.chevron_left_rounded,
                    color: Color(0xFF007AFF), size: 28),
                rightChevronIcon: Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF007AFF), size: 28),
                headerPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
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

    return Container(
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        letterSpacing: -0.3,
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
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stress Level',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stressColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            log.stressLevel <= 3
                                ? Icons.sentiment_satisfied_rounded
                                : log.stressLevel <= 7
                                    ? Icons.sentiment_neutral_rounded
                                    : Icons.sentiment_dissatisfied_rounded,
                            size: 14,
                            color: stressColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${log.stressLevel.toInt()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: stressColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Edit Button
                GestureDetector(
                  onTap: () => _showFeelingsDialog(log),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Button
                GestureDetector(
                  onTap: () => _deleteLog(date, index),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (log.feelings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feelings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: log.feelings.map((feeling) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          feeling,
                          style: const TextStyle(
                            fontSize: 13,
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Symptoms',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: log.symptoms.map((symptom) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          symptom,
                          style: const TextStyle(
                            fontSize: 13,
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
    );
  }

  Widget _buildJournalOnlyCard(DailyLog log, DateTime date, int index) {
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
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
                const Spacer(),
                // Edit Button
                GestureDetector(
                  onTap: () => _addJournalToExistingLog(log),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Button
                GestureDetector(
                  onTap: () => _deleteLog(date, index),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (log.journal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                child: Text(
                  log.journal!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add a method to add or edit journal entries for existing logs
  void _addJournalToExistingLog(DailyLog log) {
    TextEditingController journalController =
        TextEditingController(text: log.journal);

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
                height: MediaQuery.of(context).size.height * 0.8,
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
                            Text(
                              'How are you feeling today?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TextField(
                                controller: journalController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  hintText: 'Write your thoughts here...',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.purple),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
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
                              ),
                              child: const Text(
                                'Save Journal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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

      _saveLogs();

      // Also sync with Supabase
      try {
        print(
            'Syncing updated journal with Supabase. ID: ${log.id ?? "None"}, Timestamp: ${log.timestamp}');
        updatedLog.syncWithSupabase();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error syncing journal with Supabase: $e');

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating journal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print(
          'Warning: Could not find log to update journal at timestamp: ${log.timestamp}');
    }
  }

  // New method for the standalone journal entry
  void _showJournalDialog() {
    if (_selectedDay == null) return;

    TextEditingController journalController = TextEditingController();

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
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _buildModalHeader('Write in Your Journal'),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: Colors.purple.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)} ${_selectedDay!.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'What\'s on your mind today?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TextField(
                                controller: journalController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  hintText: 'Write your thoughts here...',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.purple.shade700),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
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
                                _saveJournalEntry(journalController.text);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade700,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Save Journal Entry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
  Future<void> _saveJournalEntry(String journalText) async {
    if (journalText.isEmpty) return;

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
      );
      _dailyLogs[normalizedDate]!.add(logToSync!);
    });

    await _saveLogs();

    // Sync with Supabase
    try {
      await logToSync!.syncWithSupabase();
    } catch (e) {
      print('Error syncing journal with Supabase: $e');
      // Don't show error to user, as local storage still worked
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Journal entry saved successfully'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text(
            'This will permanently delete all your wellness logs from both your device and the cloud. This action cannot be undone.\n\nAre you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Clearing all data...'),
          ],
        ),
      ),
    );

    try {
      // 1. Clear local storage (SharedPreferences)
      setState(() {
        _dailyLogs.clear();
      });
      await _saveLogs();

      // 2. Clear data from Supabase (if user is authenticated)
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.clearAllWellnessLogs();
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All logs cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Refresh the UI
      setState(() {});
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing logs: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('Error clearing all data: $e');
    }
  }
}
