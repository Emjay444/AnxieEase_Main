import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'utils/logger.dart';
import 'services/supabase_service.dart';
import 'package:intl/intl.dart';

class DailyLog {
  final List<String> feelings; // Moods
  final double stressLevel;
  final List<String> symptoms;
  final DateTime timestamp;
  final String? journal;
  final String? id; // Supabase record ID

  DailyLog({
    required this.feelings,
    required this.stressLevel,
    required this.symptoms,
    required this.timestamp,
    this.journal,
    this.id,
  });

  // Create from Hive JSON
  factory DailyLog.fromJson(Map<dynamic, dynamic> json) {
    return DailyLog(
      feelings: List<String>.from(json['feelings'] ?? []),
      stressLevel: (json['stressLevel'] ?? 5.0).toDouble(),
      symptoms: List<String>.from(json['symptoms'] ?? []),
      timestamp: DateTime.parse(json['timestamp']),
      journal: json['journal'],
      id: json['id'],
    );
  }

  // Convert to JSON for Hive
  Map<String, dynamic> toJson() {
    return {
      'feelings': feelings,
      'stressLevel': stressLevel,
      'symptoms': symptoms,
      'timestamp': timestamp.toIso8601String(),
      'journal': journal,
      'id': id,
    };
  }

  // Convert to JSON for Supabase
  Map<String, dynamic> toSupabaseJson() {
    return {
      'date': DateFormat('yyyy-MM-dd').format(timestamp),
      'feelings': feelings,
      'stress_level': stressLevel,
      'symptoms': symptoms,
      'timestamp': timestamp.toIso8601String(),
      'journal': journal ?? '',
    };
  }
}

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  String selectedMonth =
      DateFormat('MMMM yyyy').format(DateTime.now()); // Default current month
  int selectedYear = DateTime.now().year; // Default current year
  String selectedPeriod = 'Monthly'; // 'Weekly' or 'Monthly'
  List<String> availableMonths = [];
  List<int> availableYears = [];

  Map<DateTime, List<DailyLog>> _dailyLogs = {};
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _hasData = false;

  // Performance optimization: Cache processed chart data
  String? _lastProcessedKey;
  Map<String, List<FlSpot>>? _cachedMoodData;
  Map<String, List<FlSpot>>? _cachedStressData;
  Map<String, List<FlSpot>>? _cachedSymptomsData;
  List<MapEntry<String, int>>? _cachedTopSymptoms;
  List<MapEntry<String, int>>? _cachedTopMoods;

  // Get user-specific key for SharedPreferences
  String get _userSpecificLogsKey {
    final userId = _supabaseService.client.auth.currentUser?.id ?? 'guest';
    return 'daily_logs_$userId';
  }

  // Mood categories for grouping similar moods
  final Map<String, String> moodCategories = {
    'Happy': 'Positive',
    'Excited': 'Positive',
    'Calm': 'Positive',
    'Relief': 'Positive',
    'Satisfied': 'Positive',
    'Fearful': 'Negative',
    'Angry': 'Negative',
    'Pain': 'Negative',
    'Boredom': 'Negative',
    'Sad': 'Negative',
    'Confused': 'Negative',
    'Anxious': 'Negative',
    'Awe': 'Neutral',
    'Custom': 'Neutral', // Add custom mood as a neutral category
  };

  // Data for charts
  Map<String, List<FlSpot>> moodData = {
    'Weekly': [],
    'Monthly': [],
  };

  Map<String, List<FlSpot>> stressData = {
    'Weekly': [],
    'Monthly': [],
  };

  Map<String, List<FlSpot>> symptomsData = {
    'Weekly': [],
    'Monthly': [],
  };

  // Top symptoms and moods
  List<MapEntry<String, int>> topSymptoms = [];
  List<MapEntry<String, int>> topMoods = [];

  // Labels for different time periods
  final Map<String, List<String>> timeLabels = {
    'Weekly': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    'Monthly': ['1', '5', '10', '15', '20', '25', '30'],
  };

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _checkConnectionStatus();
    _loadLogs();
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    availableMonths = [];
    availableYears = [];

    // Generate all months from January of last year to current month
    final startDate = DateTime(now.year - 1, 1, 1);
    DateTime currentDate = startDate;

    while (currentDate.isBefore(now) ||
        currentDate.month == now.month && currentDate.year == now.year) {
      availableMonths.add(DateFormat('MMMM yyyy').format(currentDate));

      // Add year to availableYears if not already present
      if (!availableYears.contains(currentDate.year)) {
        availableYears.add(currentDate.year);
      }

      // Move to next month
      if (currentDate.month == 12) {
        currentDate = DateTime(currentDate.year + 1, 1, 1);
      } else {
        currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
      }
    }

    // Sort years in descending order (newest first)
    availableYears.sort((a, b) => b.compareTo(a));

    // Set default to current month and year
    selectedMonth = DateFormat('MMMM yyyy').format(now);
    selectedYear = now.year;
  }

  Future<void> _checkConnectionStatus() async {
    // no-op for UI; kept for potential future use
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to load from SharedPreferences
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

      // If user is authenticated, also try to fetch from Supabase
      if (_supabaseService.isAuthenticated) {
        try {
          final List<Map<String, dynamic>> supabaseLogs =
              await _supabaseService.getWellnessLogs();

          Logger.info('Loaded ${supabaseLogs.length} logs from Supabase');

          // Count logs before adding Supabase logs
          int totalLogsBefore = 0;
          _dailyLogs.forEach((_, logs) {
            totalLogsBefore += logs.length;
          });
          Logger.info(
              'Total logs before adding Supabase logs: $totalLogsBefore');

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
            // Compare not just timestamps but also the content to detect duplicates
            bool isDuplicate = false;
            for (final existingLog in _dailyLogs[normalizedDate]!) {
              // Compare feelings, symptoms, and stress level to detect same log with different timestamps
              if (_areLogsSimilar(existingLog, dailyLog)) {
                isDuplicate = true;
                Logger.info(
                    'Detected duplicate log based on content similarity');
                break;
              }
            }

            if (!isDuplicate) {
              // Add new log if it doesn't exist locally
              _dailyLogs[normalizedDate]!.add(dailyLog);
              logsAdded++;
            }
          }

          // Count logs after adding Supabase logs
          int totalLogsAfter = 0;
          _dailyLogs.forEach((_, logs) {
            totalLogsAfter += logs.length;
          });

          Logger.info('Added $logsAdded new logs from Supabase');
          Logger.info('Total logs after adding Supabase logs: $totalLogsAfter');

          // keep data-only change; no UI indicator anymore

          Logger.info(
              'Successfully loaded ${supabaseLogs.length} logs from Supabase');
        } catch (e) {
          // keep data-only change; no UI indicator anymore
          Logger.error('Error loading logs from Supabase', e);
          // Continue with local data if Supabase fetch fails
        }
      }

      // Process data for charts
      _processLogsData();

      // Check if we have any real data (not just empty placeholders)
      bool hasRealData = false;
      for (var logs in _dailyLogs.values) {
        if (logs.isNotEmpty) {
          hasRealData = true;
          break;
        }
      }

      setState(() {
        _hasData = hasRealData;
      });
    } catch (e) {
      Logger.error('Error loading logs', e);
      // Don't initialize with sample data on error
      setState(() {
        _hasData = false;
        moodData = {'Weekly': [], 'Monthly': []};
        stressData = {'Weekly': [], 'Monthly': []};
        symptomsData = {'Weekly': [], 'Monthly': []};
        topSymptoms = [];
        topMoods = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  // Helper method to determine if two logs are likely the same entry
  // even if they have different timestamps
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

  // ignore: unused_element
  void _initializeSampleData() {
    // Sample data for mood (scale 0-10, where higher is more positive mood)
    moodData = {
      'Weekly': [
        const FlSpot(0, 7.0),
        const FlSpot(1, 6.0),
        const FlSpot(2, 8.0),
        const FlSpot(3, 7.5),
        const FlSpot(4, 6.5),
        const FlSpot(5, 8.0),
        const FlSpot(6, 7.0),
      ],
      'Monthly': [
        const FlSpot(0, 7.0),
        const FlSpot(5, 6.5),
        const FlSpot(10, 7.0),
        const FlSpot(15, 8.0),
        const FlSpot(20, 7.5),
        const FlSpot(25, 6.0),
        const FlSpot(30, 7.0),
      ],
    };

    // Sample data for stress levels (scale 0-10)
    stressData = {
      'Weekly': [
        const FlSpot(0, 3.0),
        const FlSpot(1, 4.0),
        const FlSpot(2, 2.0),
        const FlSpot(3, 3.5),
        const FlSpot(4, 5.0),
        const FlSpot(5, 2.5),
        const FlSpot(6, 3.0),
      ],
      'Monthly': [
        const FlSpot(0, 3.0),
        const FlSpot(5, 4.0),
        const FlSpot(10, 3.5),
        const FlSpot(15, 2.0),
        const FlSpot(20, 3.0),
        const FlSpot(25, 4.5),
        const FlSpot(30, 3.0),
      ],
    };

    // Sample data for symptom count
    symptomsData = {
      'Weekly': [
        const FlSpot(0, 1.0),
        const FlSpot(1, 2.0),
        const FlSpot(2, 0.0),
        const FlSpot(3, 1.0),
        const FlSpot(4, 3.0),
        const FlSpot(5, 1.0),
        const FlSpot(6, 0.0),
      ],
      'Monthly': [
        const FlSpot(0, 1.0),
        const FlSpot(5, 2.0),
        const FlSpot(10, 1.0),
        const FlSpot(15, 0.0),
        const FlSpot(20, 1.0),
        const FlSpot(25, 2.0),
        const FlSpot(30, 1.0),
      ],
    };

    // Sample top symptoms
    topSymptoms = [
      const MapEntry('Headache', 5),
      const MapEntry('Rapid heartbeat', 4),
      const MapEntry('Fatigue', 3),
      const MapEntry('Dizziness', 2),
      const MapEntry('Muscle tension', 1),
    ];

    // Sample top moods
    topMoods = [
      const MapEntry('Anxious', 6),
      const MapEntry('Happy', 5),
      const MapEntry('Calm', 4),
      const MapEntry('Fearful', 3),
      const MapEntry('Excited', 2),
    ];
  }

  void _processLogsData() {
    if (_dailyLogs.isEmpty) {
      // Don't show sample data, just initialize with empty data
      setState(() {
        _hasData = false;
        moodData = {'Weekly': [], 'Monthly': []};
        stressData = {'Weekly': [], 'Monthly': []};
        symptomsData = {'Weekly': [], 'Monthly': []};
        topSymptoms = [];
        topMoods = [];
      });
      return;
    }

    // PERFORMANCE OPTIMIZATION: Check if we can use cached data
    final currentKey = '$selectedPeriod-$selectedMonth-$selectedYear';
    if (_lastProcessedKey == currentKey &&
        _cachedMoodData != null &&
        _cachedStressData != null &&
        _cachedSymptomsData != null) {
      // Use cached data instead of recalculating
      setState(() {
        _hasData = true;
        moodData = _cachedMoodData!;
        stressData = _cachedStressData!;
        symptomsData = _cachedSymptomsData!;
        topSymptoms = _cachedTopSymptoms ?? [];
        topMoods = _cachedTopMoods ?? [];
      });
      return;
    }

    // Get dates for weekly and monthly ranges
    final now = DateTime.now();
    Logger.info('Current date: ${now.toString()}, Day of week: ${now.weekday}');
    final weekStart =
        _normalizeDate(now.subtract(Duration(days: now.weekday - 1)));
    Logger.info('Week start date: ${weekStart.toString()}');

    // Parse selected month for filtering
    DateTime monthStart;
    if (selectedMonth.isNotEmpty) {
      try {
        final monthDate = DateFormat('MMMM yyyy').parse(selectedMonth);
        monthStart =
            _normalizeDate(DateTime(monthDate.year, monthDate.month, 1));
      } catch (e) {
        monthStart = _normalizeDate(DateTime(now.year, now.month, 1));
      }
    } else {
      monthStart = _normalizeDate(DateTime(now.year, now.month, 1));
    }
    Logger.info('Month start date: ${monthStart.toString()}');

    // Create a list of all unique logs to completely avoid duplicates
    final List<DailyLog> allLogs = [];

    // First pass - gather all logs across all dates
    _dailyLogs.forEach((date, logs) {
      allLogs.addAll(logs);
    });

    // Deduplicate logs by comparing content instead of just timestamps
    final List<DailyLog> uniqueLogs = [];
    for (final log in allLogs) {
      bool isDuplicate = false;
      for (final uniqueLog in uniqueLogs) {
        if (_areLogsSimilar(log, uniqueLog)) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        uniqueLogs.add(log);
      }
    }

    Logger.info('Total logs before deduplication: ${allLogs.length}');
    Logger.info(
        'Total unique logs after content-based deduplication: ${uniqueLogs.length}');

    // Maps to count occurrences - count each symptom/mood only once
    Map<String, int> symptomCounts = {};
    Map<String, int> moodCounts = {};

    // Filter logs by selected month for symptoms and moods counting
    List<DailyLog> filteredLogsForCounts = uniqueLogs.where((log) {
      final logDate = _normalizeDate(log.timestamp);
      // Monthly - filter by selected month
      final selectedMonthDate = selectedMonth.isNotEmpty
          ? DateFormat('MMMM yyyy').parse(selectedMonth)
          : DateTime(now.year, now.month, 1);
      final monthEnd =
          DateTime(selectedMonthDate.year, selectedMonthDate.month + 1, 0);
      return (logDate.isAfter(monthStart) ||
              logDate.isAtSameMomentAs(monthStart)) &&
          logDate.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    // Process filtered logs to count symptoms and moods
    for (var log in filteredLogsForCounts) {
      // Count symptoms - each unique log counts a symptom only once
      for (var symptom in log.symptoms) {
        if (symptom != 'None') {
          symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
        }
      }

      // Count moods - each unique log counts a mood only once
      for (var mood in log.feelings) {
        // Consolidate all custom moods under a single "Custom" entry
        if (mood.startsWith('Custom:')) {
          moodCounts['Custom'] = (moodCounts['Custom'] ?? 0) + 1;
        } else {
          moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
        }
      }
    }

    // Maps to store daily aggregated data by weekday (0-6) and day of month (0-30)
    Map<int, double> weeklyMoodScores = {};
    Map<int, double> weeklyStressLevels = {};
    Map<int, int> weeklySymptomCounts = {};

    Map<int, double> monthlyMoodScores = {};
    Map<int, double> monthlyStressLevels = {};
    Map<int, int> monthlySymptomCounts = {};

    // Create a map to organize unique logs by date for charts
    Map<DateTime, List<DailyLog>> uniqueLogsByDate = {};

    // Distribute unique logs to their respective dates
    for (var log in uniqueLogs) {
      final date = _normalizeDate(log.timestamp);
      if (!uniqueLogsByDate.containsKey(date)) {
        uniqueLogsByDate[date] = [];
      }
      uniqueLogsByDate[date]!.add(log);
    }

    // Process logs by date for charts
    uniqueLogsByDate.forEach((date, uniqueLogsForDay) {
      Logger.info(
          'Processing date: ${date.toString()}, with ${uniqueLogsForDay.length} logs');
      // For each day's logs
      int totalPositiveMoods = 0;
      int totalNegativeMoods = 0;
      double totalStress = 0;
      Set<String> daySymptoms = {};

      // Now process only unique logs for this day
      for (var log in uniqueLogsForDay) {
        // Gather symptoms for this day
        for (var symptom in log.symptoms) {
          if (symptom != 'None') {
            daySymptoms.add(symptom);
          }
        }

        // Categorize mood
        for (var mood in log.feelings) {
          if (moodCategories[mood] == 'Positive') {
            totalPositiveMoods++;
          } else if (moodCategories[mood] == 'Negative') {
            totalNegativeMoods++;
          }
        }

        // Add stress level
        totalStress += log.stressLevel;
        Logger.info(
            'Added stress level: ${log.stressLevel}, total now: $totalStress');
      }

      // Calculate mood score (0-10 scale)
      double moodScore = 5.0; // Neutral default
      if (totalPositiveMoods > 0 || totalNegativeMoods > 0) {
        int total = totalPositiveMoods + totalNegativeMoods;
        // Scale from 0-10 where 10 is all positive, 0 is all negative
        moodScore = (totalPositiveMoods / total) * 10;
      }

      // Calculate average stress level
      double avgStress = uniqueLogsForDay.isNotEmpty
          ? totalStress / uniqueLogsForDay.length
          : 0;

      Logger.info(
          'Calculated avgStress=$avgStress from totalStress=$totalStress divided by ${uniqueLogsForDay.length} logs');
      Logger.info(
          'Symptoms for this day: ${daySymptoms.length} (${daySymptoms.join(", ")})');

      // Weekly data
      if (date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart)) {
        int weekday =
            date.weekday % 7; // 0 = Sunday, 6 = Saturday (adjusted for display)

        Logger.info(
            'Date ${date.toString()} weekday=${date.weekday}, adjusted weekday=$weekday');

        // Store the data for each day of the week
        weeklyMoodScores[weekday] = moodScore;
        weeklyStressLevels[weekday] = avgStress;
        weeklySymptomCounts[weekday] = daySymptoms.length;
      }

      // Monthly data - filter by selected month
      final selectedMonthDate = selectedMonth.isNotEmpty
          ? DateFormat('MMMM yyyy').parse(selectedMonth)
          : DateTime(now.year, now.month, 1);
      final monthEnd =
          DateTime(selectedMonthDate.year, selectedMonthDate.month + 1, 0);

      if ((date.isAfter(monthStart) || date.isAtSameMomentAs(monthStart)) &&
          date.isBefore(monthEnd.add(const Duration(days: 1)))) {
        int day = date.day - 1; // 0-based day of month

        // Store the data for each day of the month
        monthlyMoodScores[day] = moodScore;
        monthlyStressLevels[day] = avgStress;
        monthlySymptomCounts[day] = daySymptoms.length;
      }
    });

    // Convert to FlSpot lists for charts
    List<FlSpot> weeklyMoodSpots = [];
    List<FlSpot> weeklyStressSpots = [];
    List<FlSpot> weeklySymptomSpots = [];

    // Create weekly data points (Sunday to Saturday)
    for (int i = 0; i < 7; i++) {
      // Add all days, use 0 for days without data to maintain continuity
      weeklyMoodSpots.add(FlSpot(i.toDouble(), weeklyMoodScores[i] ?? 0.0));
      weeklyStressSpots.add(FlSpot(i.toDouble(), weeklyStressLevels[i] ?? 0.0));
      weeklySymptomSpots
          .add(FlSpot(i.toDouble(), weeklySymptomCounts[i]?.toDouble() ?? 0.0));
    }

    // Create monthly data points
    List<FlSpot> monthlyMoodSpots = [];
    List<FlSpot> monthlyStressSpots = [];
    List<FlSpot> monthlySymptomSpots = [];

    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < daysInMonth; i++) {
      // Add all days, use 0 for days without data to maintain continuity
      monthlyMoodSpots.add(FlSpot(i.toDouble(), monthlyMoodScores[i] ?? 0.0));
      monthlyStressSpots
          .add(FlSpot(i.toDouble(), monthlyStressLevels[i] ?? 0.0));
      monthlySymptomSpots.add(
          FlSpot(i.toDouble(), monthlySymptomCounts[i]?.toDouble() ?? 0.0));
    }

    // Update state with processed data
    setState(() {
      _hasData = true; // We have real data
      moodData = {
        'Weekly': weeklyMoodSpots,
        'Monthly': monthlyMoodSpots,
      };

      stressData = {
        'Weekly': weeklyStressSpots,
        'Monthly': monthlyStressSpots,
      };

      symptomsData = {
        'Weekly': weeklySymptomSpots,
        'Monthly': monthlySymptomSpots,
      };

      // Get top 5 symptoms
      topSymptoms = symptomCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topSymptoms.length > 5) topSymptoms = topSymptoms.sublist(0, 5);

      Logger.info(
          'Top symptoms: ${topSymptoms.map((e) => '${e.key}: ${e.value}').join(', ')}');

      // Get top 5 moods
      topMoods = moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topMoods.length > 5) topMoods = topMoods.sublist(0, 5);

      Logger.info(
          'Top moods: ${topMoods.map((e) => '${e.key}: ${e.value}').join(', ')}');

      // PERFORMANCE OPTIMIZATION: Cache the results
      _lastProcessedKey = '$selectedPeriod-$selectedMonth-$selectedYear';
      _cachedMoodData = moodData;
      _cachedStressData = stressData;
      _cachedSymptomsData = symptomsData;
      _cachedTopSymptoms = topSymptoms;
      _cachedTopMoods = topMoods;
    });
  }

  Map<String, dynamic> getChartProperties(String period) {
    switch (period) {
      case 'Weekly':
        return {
          'minX': 0.0,
          'maxX': 6.0,
          'interval': 1.0,
        };
      case 'Monthly':
        final now = DateTime.now();
        final selectedMonthDate = selectedMonth.isNotEmpty
            ? DateFormat('MMMM yyyy').parse(selectedMonth)
            : DateTime(now.year, now.month, 1);
        final daysInMonth =
            DateTime(selectedMonthDate.year, selectedMonthDate.month + 1, 0)
                .day;
        return {
          'minX': 0.0,
          'maxX': (daysInMonth - 1).toDouble(),
          'interval': 5.0,
        };
    }
    return {
      'minX': 0.0,
      'maxX': 6.0,
      'interval': 1.0,
    };
  }

  Future<void> _refreshData() async {
    setState(() {
      _dailyLogs.clear(); // Clear existing data
      _hasData = false;
      // Clear cache when refreshing data
      _lastProcessedKey = null;
      _cachedMoodData = null;
      _cachedStressData = null;
      _cachedSymptomsData = null;
      _cachedTopSymptoms = null;
      _cachedTopMoods = null;
    });
    await _loadLogs(); // Reload data from both sources
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> chartProps = getChartProperties(selectedPeriod);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading:
            false, // prevent auto back arrow on first visit
        foregroundColor: Colors.black, // ensure icons are visible on white bg
        title: const Text(
          'Wellness Insights',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // No actions per request (removed cloud and refresh)
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: !_hasData
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart_outlined,
                                    size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 24),
                                Text(
                                  'No wellness data available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Add logs in the Calendar to see your insights',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Add top spacing so floating label isn't clipped
                          const SizedBox(height: 24),

                          // Period toggle (Weekly/Monthly)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPeriod = 'Weekly';
                                      });
                                      _processLogsData();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedPeriod == 'Weekly'
                                            ? const Color(0xFF6200EE)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Weekly',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: selectedPeriod == 'Weekly'
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPeriod = 'Monthly';
                                      });
                                      _processLogsData();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedPeriod == 'Monthly'
                                            ? const Color(0xFF6200EE)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Monthly',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: selectedPeriod == 'Monthly'
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Filters Row (Year and Month - only show for Monthly)
                          if (selectedPeriod == 'Monthly')
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  // Year selector
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: selectedYear,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Year',
                                        labelStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF6200EE)),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      items: availableYears.map((int year) {
                                        return DropdownMenuItem<int>(
                                          value: year,
                                          child: Text(
                                            year.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (int? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            selectedYear = newValue;
                                            // Update selected month to first month of selected year if current selection is invalid
                                            final currentMonthDate =
                                                DateFormat('MMMM yyyy')
                                                    .parse(selectedMonth);
                                            if (currentMonthDate.year !=
                                                selectedYear) {
                                              selectedMonth =
                                                  DateFormat('MMMM yyyy')
                                                      .format(DateTime(
                                                          selectedYear, 1, 1));
                                            }
                                          });
                                          _processLogsData();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Month selector
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: selectedMonth,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Month',
                                        labelStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF6200EE)),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      items: availableMonths
                                          .where((month) =>
                                              DateFormat('MMMM yyyy')
                                                  .parse(month)
                                                  .year ==
                                              selectedYear)
                                          .map((String month) {
                                        return DropdownMenuItem<String>(
                                          value: month,
                                          child: Text(
                                            DateFormat('MMMM').format(
                                                DateFormat('MMMM yyyy')
                                                    .parse(month)),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            selectedMonth = newValue;
                                          });
                                          _processLogsData();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Metrics Cards
                          Expanded(
                            child: ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                // Move Top Items to the top
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTopItemsCard(
                                        title: 'Top Moods',
                                        items: topMoods,
                                        color: const Color(0xFF4CAF50),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTopItemsCard(
                                        title: 'Top Symptoms',
                                        items: topSymptoms,
                                        color: const Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Main Charts
                                _buildMetricCard(
                                  title: 'Mood Score',
                                  value: moodData[selectedPeriod]!.isEmpty
                                      ? 0.0
                                      : _findValueForToday(
                                          moodData[selectedPeriod]!,
                                          DateTime.now().weekday % 7),
                                  data: moodData[selectedPeriod]!,
                                  color:
                                      const Color(0xFF4CAF50), // Green for mood
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF8BC34A)
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                  unit: '/10',
                                  minY: 0,
                                  maxY: 10,
                                  chartProps: chartProps,
                                  description:
                                      'Higher score indicates more positive mood',
                                ),
                                const SizedBox(height: 16),
                                _buildMetricCard(
                                  title: 'Stress Level',
                                  value: stressData[selectedPeriod]!.isEmpty
                                      ? 0.0
                                      : _findValueForToday(
                                          stressData[selectedPeriod]!,
                                          DateTime.now().weekday % 7),
                                  data: stressData[selectedPeriod]!,
                                  color: const Color(
                                      0xFFFF5722), // Orange for stress
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFFF9800)
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                  unit: '/10',
                                  minY: 0,
                                  maxY: 10,
                                  chartProps: chartProps,
                                  description:
                                      'Higher score indicates more stress',
                                ),
                                const SizedBox(height: 16),
                                _buildMetricCard(
                                  title: 'Symptom Count',
                                  value: symptomsData[selectedPeriod]!.isEmpty
                                      ? 0.0
                                      : _findValueForToday(
                                          symptomsData[selectedPeriod]!,
                                          DateTime.now().weekday % 7),
                                  data: symptomsData[selectedPeriod]!,
                                  color: const Color(
                                      0xFF2196F3), // Blue for symptoms
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2196F3),
                                      Color(0xFF03A9F4)
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                  unit: '',
                                  minY: 0,
                                  maxY: 10,
                                  chartProps: chartProps,
                                  description:
                                      'Number of symptoms reported each day',
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required List<FlSpot> data,
    required Color color,
    required Gradient gradient,
    required String unit,
    required double minY,
    required double maxY,
    required Map<String, dynamic> chartProps,
    String? description,
  }) {
    // Filter out zero values (days without data) for statistics calculation
    final nonZeroData = data.where((spot) => spot.y > 0).toList();

    // Calculate statistics from non-zero data only
    double average = nonZeroData.isEmpty
        ? 0.0
        : nonZeroData.map((spot) => spot.y).reduce((a, b) => a + b) /
            nonZeroData.length;

    double maxValue = nonZeroData.isEmpty
        ? 0.0
        : nonZeroData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    double minValue = nonZeroData.isEmpty
        ? 0.0
        : nonZeroData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                color.withAlpha(25), // Using withAlpha instead of withOpacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'No data available for this period',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                '${touchedSpot.y.toStringAsFixed(1)}$unit',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: title == 'Symptom Count' ? 2 : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200],
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: title == 'Symptom Count' ? 2 : 2,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: chartProps['interval'],
                            getTitlesWidget: (value, meta) {
                              final int index = value.toInt();
                              final labels = timeLabels[selectedPeriod]!;
                              if (index >= 0 && index < labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[index],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: chartProps['minX'],
                      maxX: chartProps['maxX'],
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: data,
                          isCurved: true,
                          curveSmoothness:
                              0.35, // Smooth curve like the reference
                          preventCurveOverShooting: true,
                          color: color,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(
                              show: false), // Hide dots for clean look
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                color.withAlpha(
                                    51), // Using withAlpha instead of withOpacity
                                color.withAlpha(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Min', minValue.toStringAsFixed(1), unit, color),
              _buildStatItem('Avg', average.toStringAsFixed(1), unit, color),
              _buildStatItem('Max', maxValue.toStringAsFixed(1), unit, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value$unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTopItemsCard({
    required String title,
    required List<MapEntry<String, int>> items,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'No data',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: items.take(3).map((item) {
                    // Show only top 3 in compact view
                    // Find the maximum count to calculate percentage
                    final maxCount = items.first.value.toDouble();
                    final percentage =
                        maxCount > 0 ? (item.value / maxCount) * 100 : 0.0;

                    // Modify display name for custom moods
                    String displayName = item.key;
                    if (displayName.startsWith('Custom:')) {
                      displayName = 'Custom';
                    }

                    // Truncate long names
                    if (displayName.length > 12) {
                      displayName = '${displayName.substring(0, 12)}...';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.value}x',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  double _findValueForToday(List<FlSpot> data, int weekday) {
    // First try to find an exact match for today's weekday
    for (final spot in data) {
      if (spot.x == weekday.toDouble() && spot.y > 0) {
        Logger.info(
            'Found exact match for weekday $weekday with value ${spot.y}');
        return spot.y;
      }
    }

    // If no exact match, calculate the average from available non-zero data
    final nonZeroData = data.where((spot) => spot.y > 0).toList();
    if (nonZeroData.isNotEmpty) {
      final average =
          nonZeroData.map((spot) => spot.y).reduce((a, b) => a + b) /
              nonZeroData.length;
      Logger.info('Using average of non-zero data points: $average');
      return average;
    }

    // Default fallback - return 0.0 when no data exists
    Logger.info('No data found, using default value 0.0');
    return 0.0;
  }
}
