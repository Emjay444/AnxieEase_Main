import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'calendar_screen.dart';
import 'utils/logger.dart';
import 'services/supabase_service.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  String selectedPeriod = 'Weekly'; // Default selected period
  final List<String> periods = ['Weekly', 'Monthly'];

  Map<DateTime, List<DailyLog>> _dailyLogs = {};
  static const String logsKey = 'daily_logs';
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _hasData = false;
  bool _isConnected = false;

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
    _checkConnectionStatus();
    _loadLogs();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() {
      _isConnected = _supabaseService.isAuthenticated;
    });
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? logsJson = prefs.getString(logsKey);

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

          // Process Supabase logs
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
            final existingLogIndex = _dailyLogs[normalizedDate]!.indexWhere(
                (existingLog) =>
                    existingLog.timestamp.toString() ==
                    dailyLog.timestamp.toString());

            if (existingLogIndex == -1) {
              // Add new log if it doesn't exist locally
              _dailyLogs[normalizedDate]!.add(dailyLog);
            }
          }

          setState(() {
            _isConnected = true;
          });

          Logger.info(
              'Successfully loaded ${supabaseLogs.length} logs from Supabase');
        } catch (e) {
          setState(() {
            _isConnected = false;
          });
          Logger.error('Error loading logs from Supabase', e);
          // Continue with local data if Supabase fetch fails
        }
      }

      // Process data for charts
      _processLogsData();

      // Check if we have any data
      setState(() {
        _hasData = _dailyLogs.isNotEmpty;
      });
    } catch (e) {
      Logger.error('Error loading logs', e);
      // Initialize with sample data if there's an error
      _initializeSampleData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

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
      _initializeSampleData();
      return;
    }

    // Get dates for weekly and monthly ranges
    final now = DateTime.now();
    final weekStart =
        _normalizeDate(now.subtract(Duration(days: now.weekday - 1)));
    final monthStart = _normalizeDate(DateTime(now.year, now.month, 1));

    // Maps to count occurrences
    Map<String, int> symptomCounts = {};
    Map<String, int> moodCounts = {};

    // Maps to store daily aggregated data
    Map<DateTime, double> weeklyMoodScores = {};
    Map<DateTime, double> weeklyStressLevels = {};
    Map<DateTime, int> weeklySymptomCounts = {};

    Map<int, double> monthlyMoodScores = {};
    Map<int, double> monthlyStressLevels = {};
    Map<int, int> monthlySymptomCounts = {};

    // Process all logs
    _dailyLogs.forEach((date, logs) {
      // For each day's logs
      int totalPositiveMoods = 0;
      int totalNegativeMoods = 0;
      double totalStress = 0;
      Set<String> daySymptoms = {};

      for (var log in logs) {
        // Count symptoms
        for (var symptom in log.symptoms) {
          if (symptom != 'None') {
            symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
            daySymptoms.add(symptom);
          }
        }

        // Count moods
        for (var mood in log.feelings) {
          moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;

          // Categorize mood
          if (moodCategories[mood] == 'Positive') {
            totalPositiveMoods++;
          } else if (moodCategories[mood] == 'Negative') {
            totalNegativeMoods++;
          }
        }

        // Add stress level
        totalStress += log.stressLevel;
      }

      // Calculate mood score (0-10 scale)
      double moodScore = 5.0; // Neutral default
      if (totalPositiveMoods > 0 || totalNegativeMoods > 0) {
        int total = totalPositiveMoods + totalNegativeMoods;
        // Scale from 0-10 where 10 is all positive, 0 is all negative
        moodScore = (totalPositiveMoods / total) * 10;
      }

      // Calculate average stress level
      double avgStress = logs.isNotEmpty ? totalStress / logs.length : 0;

      // Weekly data
      if (date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart)) {
        int weekday =
            date.weekday % 7; // 0 = Sunday, 6 = Saturday (adjusted for display)

        weeklyMoodScores[date] = moodScore;
        weeklyStressLevels[date] = avgStress;
        weeklySymptomCounts[date] = daySymptoms.length;
      }

      // Monthly data
      if (date.isAfter(monthStart) || date.isAtSameMomentAs(monthStart)) {
        int day = date.day - 1; // 0-based day of month

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
      DateTime day = weekStart.add(Duration(days: i));
      weeklyMoodSpots.add(FlSpot(i.toDouble(), weeklyMoodScores[day] ?? 5.0));
      weeklyStressSpots
          .add(FlSpot(i.toDouble(), weeklyStressLevels[day] ?? 0.0));
      weeklySymptomSpots.add(
          FlSpot(i.toDouble(), weeklySymptomCounts[day]?.toDouble() ?? 0.0));
    }

    // Create monthly data points
    List<FlSpot> monthlyMoodSpots = [];
    List<FlSpot> monthlyStressSpots = [];
    List<FlSpot> monthlySymptomSpots = [];

    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < daysInMonth; i++) {
      monthlyMoodSpots.add(FlSpot(i.toDouble(), monthlyMoodScores[i] ?? 5.0));
      monthlyStressSpots
          .add(FlSpot(i.toDouble(), monthlyStressLevels[i] ?? 0.0));
      monthlySymptomSpots.add(
          FlSpot(i.toDouble(), monthlySymptomCounts[i]?.toDouble() ?? 0.0));
    }

    // Update state with processed data
    setState(() {
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

      // Get top 5 moods
      topMoods = moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topMoods.length > 5) topMoods = topMoods.sublist(0, 5);
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
        return {
          'minX': 0.0,
          'maxX': 30.0,
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
    final chartProps = getChartProperties(selectedPeriod);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Wellness Insights',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _isConnected
                ? const Icon(Icons.cloud_done, color: Color(0xFF4CAF50))
                : const Icon(Icons.cloud_off, color: Colors.grey),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6200EE)),
            onPressed: () async {
              await _refreshData();
            },
          ),
        ],
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
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => const CalendarScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Log'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6200EE),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Period selector
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: periods.map((period) {
                                bool isSelected = selectedPeriod == period;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedPeriod = period;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF6200EE)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      period,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Metrics Cards
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _buildMetricCard(
                                  title: 'Mood Score',
                                  value: moodData[selectedPeriod]!.isNotEmpty
                                      ? moodData[selectedPeriod]!.last.y
                                      : 5.0,
                                  data: moodData[selectedPeriod]!,
                                  color: const Color(0xFF4CAF50), // Green for mood
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
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
                                  value: stressData[selectedPeriod]!.isNotEmpty
                                      ? stressData[selectedPeriod]!.last.y
                                      : 0.0,
                                  data: stressData[selectedPeriod]!,
                                  color:
                                      const Color(0xFFFF5722), // Orange for stress
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                  unit: '/10',
                                  minY: 0,
                                  maxY: 10,
                                  chartProps: chartProps,
                                  description: 'Higher score indicates more stress',
                                ),
                                const SizedBox(height: 16),
                                _buildMetricCard(
                                  title: 'Symptom Count',
                                  value: symptomsData[selectedPeriod]!.isNotEmpty
                                      ? symptomsData[selectedPeriod]!.last.y
                                      : 0.0,
                                  data: symptomsData[selectedPeriod]!,
                                  color:
                                      const Color(0xFF2196F3), // Blue for symptoms
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
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
                                const SizedBox(height: 16),
                                _buildTopItemsCard(
                                  title: 'Top Moods',
                                  items: topMoods,
                                  color: const Color(0xFF4CAF50),
                                ),
                                const SizedBox(height: 16),
                                _buildTopItemsCard(
                                  title: 'Top Symptoms',
                                  items: topSymptoms,
                                  color: const Color(0xFF2196F3),
                                ),
                                const SizedBox(height: 24),
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
    // Calculate statistics
    double average = data.isEmpty
        ? 0.0
        : data.map((spot) => spot.y).reduce((a, b) => a + b) / data.length;

    double maxValue = data.isEmpty
        ? 0.0
        : data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    double minValue = data.isEmpty
        ? 0.0
        : data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);

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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
                              if (index >= 0 &&
                                  index < timeLabels[selectedPeriod]!.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    timeLabels[selectedPeriod]![index],
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
                          color: color,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
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
              _buildStatItem('Avg', average.toStringAsFixed(1), unit, color),
              _buildStatItem('Max', maxValue.toStringAsFixed(1), unit, color),
              _buildStatItem('Min', minValue.toStringAsFixed(1), unit, color),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: items.map((item) {
                    // Find the maximum count to calculate percentage
                    final maxCount = items.first.value.toDouble();
                    final percentage =
                        maxCount > 0 ? (item.value / maxCount) * 100 : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.key,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${item.value} times',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
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
}
