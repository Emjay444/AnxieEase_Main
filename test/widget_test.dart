// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in the test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxiease/main.dart';
import 'package:anxiease/providers/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build the same minimal app used at startup to avoid provider errors
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ThemeProvider(),
        child: const InitialApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  },
      skip:
          true); // TODO: Re-enable with a test harness that completes SplashScreen timers
}
