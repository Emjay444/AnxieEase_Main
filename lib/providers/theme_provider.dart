import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  final bool _isDarkMode = false;
  static const String _themeKey = 'isDarkMode';

  bool get isDarkMode => false;

  ThemeProvider() {
    // No need to load theme preference
  }

  Future<void> toggleTheme() async {
    // Do nothing - we always use light theme
    notifyListeners();
  }

  ThemeData get themeData {
    return _lightTheme;
  }

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: const Color(0xFF3AA772),
    scaffoldBackgroundColor: Colors.grey[50],
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3AA772),
      secondary: Color(0xFF2D9254),
      surface: Colors.white,
      error: Color(0xFFFF6B6B),
    ),
    cardColor: Colors.white,
    dividerColor: Colors.grey[200],
    unselectedWidgetColor: Colors.grey[600],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey[800],
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF3AA772),
      unselectedItemColor: Colors.grey[600],
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(color: Colors.grey[800]),
      bodyLarge: TextStyle(color: Colors.grey[800]),
      bodyMedium: TextStyle(color: Colors.grey[600]),
    ),
    brightness: Brightness.light,
  );
}
