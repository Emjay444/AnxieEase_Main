import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxiease/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Quick test function
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
        print("✅ $table: OK (${result.length} records visible)");
      } catch (e) {
        print("❌ $table: Error - $e");
      }
    }

    print("🎉 Database test completed!");
  } catch (e) {
    print("❌ Critical error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Starting AnxieEase Database Backend Test...");
  print("=" * 50);

  try {
    // Initialize Supabase
    print("🔧 Initializing Supabase...");
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    print("✅ Supabase initialized successfully");

    // Run quick database test
    print("\n🔍 Running database connectivity test...");
    await quickDatabaseTest();

    print("\n${"=" * 50}");
    print("🎉 Test completed! Check results above.");
    print("💡 To run a comprehensive test:");
    print("   1. Copy comprehensive_database_test.sql");
    print("   2. Paste it in your Supabase Dashboard > SQL Editor");
    print("   3. Run the query to see detailed results");
  } catch (e) {
    print("❌ Test failed: $e");
    print("\n💡 Troubleshooting tips:");
    print("   1. Check your internet connection");
    print("   2. Verify Supabase credentials in supabase_service.dart");
    print("   3. Ensure your Supabase project is active");
  }
}
