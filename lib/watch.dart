import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  _WatchScreenState createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late DatabaseReference _metricsRef;
  bool isDeviceWorn = false;
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();

    // Get the NotificationService from Provider
    _notificationService =
        Provider.of<NotificationService>(context, listen: false);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    // Reference to your metrics (only for device worn status)
    _metricsRef =
        FirebaseDatabase.instance.ref().child('devices/AnxieEase001/Metrics');

    // Listen only for device worn status
    _metricsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            if (data.containsKey('isDeviceWorn')) {
              isDeviceWorn = data['isDeviceWorn'] as bool? ?? false;
            }
          });
        } catch (e) {
          debugPrint('Error parsing Firebase data: $e');
        }
      }
    });

    // Listen to NotificationService changes for heart rate updates
    _notificationService.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild when heart rate changes
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _notificationService.removeListener(_updateUI);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get heart rate from NotificationService
    double heartRate = _notificationService.currentHeartRate.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Health Monitor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        _controller.reset();
                        _controller.forward();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        // Heart Rate Card (Larger and centered)
                        SizedBox(
                          height: 220,
                          child: Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.88,
                              child: _buildStatCard(
                                title: 'Heart Rate',
                                value: heartRate.toStringAsFixed(0),
                                unit: 'BPM',
                                icon: Icons.favorite,
                                color: const Color(0xFFFF5252),
                                progress: (heartRate / 100).clamp(0.0, 1.0),
                                range: '60-100',
                                isLarge: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Second row with Device Status and Battery
                        SizedBox(
                          height: 170,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Device Status',
                                  value: isDeviceWorn ? 'Worn' : 'Not Worn',
                                  unit: '',
                                  icon: Icons.watch,
                                  color: const Color(0xFF9C27B0),
                                  progress: isDeviceWorn ? 1.0 : 0.0,
                                  range: 'Status',
                                  isLarge: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Battery',
                                  value: '85',
                                  unit: '%',
                                  icon: Icons.battery_charging_full,
                                  color: const Color(0xFF4CAF50),
                                  progress: 0.85,
                                  range: '0-100',
                                  isLarge: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required double progress,
    required String range,
    bool isLarge = false,
  }) {
    // Determine if this is a status card with long value text
    bool isStatusValue = title == 'Device Status';

    // Choose font size based on value length and card type
    double valueFontSize =
        isLarge ? 46 : (isStatusValue ? 22 : 30); // Reduced from 26 to 22

    return FadeTransition(
      opacity: _animation,
      child: LayoutBuilder(builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(isLarge ? 20 : 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icon and range
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isLarge ? 10 : 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isLarge ? 30 : 22,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      range,
                      style: TextStyle(
                        color: color,
                        fontSize: isLarge ? 13 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Spacing
              SizedBox(height: isLarge ? 20 : 12),

              // Title
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF2C3E50),
                  fontSize: isLarge ? 18 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Spacing
              SizedBox(height: isLarge ? 8 : 5),

              // Value and unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: valueFontSize, // Use calculated font size
                        fontWeight: isStatusValue
                            ? FontWeight.w600
                            : FontWeight.bold, // Lighter weight for status
                        height: 0.9,
                        letterSpacing: isStatusValue
                            ? -0.5
                            : 0, // Tighter letter spacing for status
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: isLarge ? 16 : 12,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),

              // Spacing - smaller to fit everything
              SizedBox(height: isLarge ? 14 : 10),

              // Progress bar
              Stack(
                children: [
                  Container(
                    height: isLarge ? 8 : 5,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: isLarge ? 8 : 5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
