// Database Backend Test for Flutter App
// Add this to your lib folder as database_test.dart and run it

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class DatabaseTestScreen extends StatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  _DatabaseTestScreenState createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends State<DatabaseTestScreen> {
  final List<String> testResults = [];
  bool isLoading = false;

  Future<void> runDatabaseTests() async {
    setState(() {
      isLoading = true;
      testResults.clear();
    });

    final supabase = Supabase.instance.client;

    try {
      // Test 1: Check auth connection
      testResults.add("🔍 Testing Supabase connection...");
      final user = supabase.auth.currentUser;
      if (user != null) {
        testResults.add("✅ Auth: Connected as ${user.email}");
      } else {
        testResults.add("⚠️ Auth: No user logged in");
      }

      // Test 2: Test user_profiles table
      testResults.add("\n🔍 Testing user_profiles table...");
      try {
        final profiles = await supabase
            .from('user_profiles')
            .select('id, first_name, last_name, role')
            .limit(5);
        testResults.add(
            "✅ user_profiles: Query successful (${profiles.length} records)");
      } catch (e) {
        testResults.add("❌ user_profiles: Error - $e");
      }

      // Test 3: Test anxiety_records table
      testResults.add("\n🔍 Testing anxiety_records table...");
      try {
        final records = await supabase
            .from('anxiety_records')
            .select('id, user_id, severity_level, timestamp')
            .limit(5);
        testResults.add(
            "✅ anxiety_records: Query successful (${records.length} records)");
      } catch (e) {
        testResults.add("❌ anxiety_records: Error - $e");
      }

      // Test 4: Test wellness_logs table
      testResults.add("\n🔍 Testing wellness_logs table...");
      try {
        final logs = await supabase
            .from('wellness_logs')
            .select('id, user_id, date, stress_level')
            .limit(5);
        testResults
            .add("✅ wellness_logs: Query successful (${logs.length} records)");
      } catch (e) {
        testResults.add("❌ wellness_logs: Error - $e");
      }

      // Test 5: Test psychologists table
      testResults.add("\n🔍 Testing psychologists table...");
      try {
        final psychologists = await supabase
            .from('psychologists')
            .select('id, first_name, last_name, specialization')
            .limit(5);
        testResults.add(
            "✅ psychologists: Query successful (${psychologists.length} records)");
      } catch (e) {
        testResults.add("❌ psychologists: Error - $e");
      }

      // Test 6: Test appointments table
      testResults.add("\n🔍 Testing appointments table...");
      try {
        final appointments = await supabase
            .from('appointments')
            .select('id, user_id, psychologist_id, appointment_date, status')
            .limit(5);
        testResults.add(
            "✅ appointments: Query successful (${appointments.length} records)");
      } catch (e) {
        testResults.add("❌ appointments: Error - $e");
      }

      // Test 7: Test notifications table
      testResults.add("\n🔍 Testing notifications table...");
      try {
        final notifications = await supabase
            .from('notifications')
            .select('id, user_id, title, message, is_read')
            .limit(5);
        testResults.add(
            "✅ notifications: Query successful (${notifications.length} records)");
      } catch (e) {
        testResults.add("❌ notifications: Error - $e");
      }

      // Test 8: Test if user can insert (if logged in)
      if (user != null) {
        testResults.add("\n🔍 Testing write permissions...");
        try {
          // Try to insert a test notification
          await supabase.from('notifications').insert({
            'user_id': user.id,
            'title': 'Database Test',
            'message': 'This is a test notification from the database test',
            'type': 'system'
          });
          testResults.add("✅ Write test: Can insert data");

          // Clean up - delete the test notification
          await supabase
              .from('notifications')
              .delete()
              .eq('user_id', user.id)
              .eq('title', 'Database Test');
          testResults.add("✅ Cleanup: Test data removed");
        } catch (e) {
          testResults.add("❌ Write test: Error - $e");
        }
      }

      testResults.add("\n🎉 Database backend test completed!");
    } catch (e) {
      testResults.add("❌ Critical error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Backend Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : runDatabaseTests,
              child: isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Testing...'),
                      ],
                    )
                  : const Text('Run Database Tests'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    testResults.isEmpty
                        ? 'Click "Run Database Tests" to start testing your backend...'
                        : testResults.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
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
}

// How to use this test:
// 1. Add this import to any screen: import 'database_test.dart';
// 2. Add a button to navigate to test:
/*
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DatabaseTestScreen()),
    );
  },
  child: Text('Test Database'),
)
*/

// Quick test function you can call from anywhere:
Future<void> quickDatabaseTest() async {
  final supabase = Supabase.instance.client;

  try {
    print("🔍 Testing database connection...");

    // Test basic connection
    final user = supabase.auth.currentUser;
    print(
        "Auth status: ${user != null ? 'Logged in as ${user.email}' : 'Not logged in'}");

    // Test each table
    final tables = [
      'user_profiles',
      'anxiety_records',
      'wellness_logs',
      'appointments',
      'notifications'
    ];

    for (String table in tables) {
      try {
        final result = await supabase.from(table).select('*').limit(1);
        print("✅ $table: OK (${result.length} records)");
      } catch (e) {
        print("❌ $table: Error - $e");
      }
    }

    print("🎉 Database test completed!");
  } catch (e) {
    print("❌ Critical error: $e");
  }
}
