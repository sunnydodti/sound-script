import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../constants.dart';
import '../theme.dart';

class ThemeProvider extends ChangeNotifier {
  Box box = Hive.box(Constants.box);
  bool _isDarkMode = true;
  ThemeData _theme = darkTheme;

  ThemeProvider() {
    _isDarkMode = box.get(Constants.isDarkMode, defaultValue: true);
    _theme = _isDarkMode ? darkTheme : lightTheme;
  }

  ThemeData get theme => _theme;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    box.put(Constants.isDarkMode, _isDarkMode);
    _theme = _isDarkMode ? darkTheme : lightTheme;
    notifyListeners();
  }
}
