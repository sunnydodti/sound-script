import 'package:flutter/material.dart';

MaterialColor accentColor = Colors.blue;

// Recording/Mic color - consistent throughout the app
Color recordingColor = Colors.red.shade600;

ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.light(
    primary: accentColor,
    surface: accentColor.shade50,
    surfaceContainerLow: accentColor.shade100,
  ),
  useMaterial3: true,
);

ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.dark(
    primary: accentColor,
    surface: Colors.grey.shade900,
    surfaceContainerLow: accentColor.shade100.withAlpha(20),
  ),
  useMaterial3: true,
);
