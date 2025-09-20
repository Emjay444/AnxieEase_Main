import 'package:flutter/material.dart';
import 'package:anxiease/services/supabase_service.dart';
import 'package:anxiease/database_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Starting AnxieEase Database Backend Test...");
  const separator = '==================================================';
  print(separator);

  try {
    // Initialize Supabase
    print("🔧 Initializing Supabase...");
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    print("✅ Supabase initialized successfully");

    // Run quick database test
    print("\n🔍 Running database connectivity test...");
    await quickDatabaseTest();

    print("\n$separator");
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
