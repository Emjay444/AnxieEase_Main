import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
  double heartRate = 0;
  double temperature = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    // Reference to your metrics
    _metricsRef = FirebaseDatabase.instance
        .ref()
        .child('devices/AnxieEase001/Metrics');

    // Listen for changes
    _metricsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        // Debug print to see the actual data structure
        print('Firebase data: ${event.snapshot.value}');
        
        try {
          // Handle data based on its structure
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          
          setState(() {
            // Convert various number formats to double safely
            if (data.containsKey('heartRate')) {
              var hrValue = data['heartRate'];
              heartRate = (hrValue is num) 
                  ? hrValue.toDouble() 
                  : double.tryParse(hrValue.toString()) ?? 0;
            }
            
            if (data.containsKey('temperature')) {
              var tempValue = data['temperature'];
              temperature = (tempValue is num) 
                  ? tempValue.toDouble() 
                  : double.tryParse(tempValue.toString()) ?? 0;
            }
            
            // Print the values after processing for debugging
            print('Processed heartRate: $heartRate');
            print('Processed temperature: $temperature');
          });
        } catch (e) {
          print('Error parsing Firebase data: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        
                        // You can also refresh data manually here
                        _metricsRef.get().then((snapshot) {
                          if (snapshot.exists && snapshot.value != null) {
                            try {
                              final data = snapshot.value as Map<dynamic, dynamic>;
                              setState(() {
                                if (data.containsKey('heartRate')) {
                                  var hrValue = data['heartRate'];
                                  heartRate = (hrValue is num) 
                                      ? hrValue.toDouble() 
                                      : double.tryParse(hrValue.toString()) ?? 0;
                                }
                                
                                if (data.containsKey('temperature')) {
                                  var tempValue = data['temperature'];
                                  temperature = (tempValue is num) 
                                      ? tempValue.toDouble() 
                                      : double.tryParse(tempValue.toString()) ?? 0;
                                }
                              });
                            } catch (e) {
                              print('Error refreshing data: $e');
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            final items = [
                              {
                                'title': 'Heart Rate',
                                'value': heartRate.toStringAsFixed(0),
                                'unit': 'BPM',
                                'icon': Icons.favorite,
                                'color': const Color(0xFFFF5252),
                                'progress': (heartRate / 100).clamp(0.0, 1.0),
                                'range': '60-100',
                              },
                              {
                                'title': 'SpO2',
                                'value': '98',
                                'unit': '%',
                                'icon': Icons.water_drop,
                                'color': const Color(0xFF2196F3),
                                'progress': 0.98,
                                'range': '95-100',
                              },
                              {
                                'title': 'Battery',
                                'value': '85',
                                'unit': '%',
                                'icon': Icons.battery_charging_full,
                                'color': const Color(0xFF4CAF50),
                                'progress': 0.85,
                                'range': '0-100',
                              },
                              {
                                'title': 'Temperature',
                                'value': temperature.toStringAsFixed(1),
                                'unit': '°C',
                                'icon': Icons.thermostat,
                                'color': const Color(0xFFFFA726),
                                'progress': ((temperature - 35) / 3).clamp(0.0, 1.0),
                                'range': '35-38',
                              },
                            ];

                            return _buildStatCard(
                              title: items[index]['title'] as String,
                              value: items[index]['value'] as String,
                              unit: items[index]['unit'] as String,
                              icon: items[index]['icon'] as IconData,
                              color: items[index]['color'] as Color,
                              progress: items[index]['progress'] as double,
                              range: items[index]['range'] as String,
                            );
                          },
                        ),
                      ),
                    ],
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
  }) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(_animation),
                  child: Container(
                    height: 6,
                    width: MediaQuery.of(context).size.width * progress * 0.3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
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
      ),
    );
  }
}