import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/provider/theme_provider.dart';

class MyAppbar {
  static AppBar build(
    BuildContext context, {
    String title = 'Sound Script',
    bool back = false,
  }) {
    Icon icon = Theme.of(context).brightness == Brightness.light
        ? Icon(Icons.light_mode_outlined)
        : Icon(Icons.dark_mode_outlined);
    IconButton backButton = IconButton(
      onPressed: () {},
      icon: Icon(Icons.arrow_back_outlined),
    );
    return AppBar(
      title: Text(title),
      centerTitle: true,
      leading: back ? backButton : null,
      actions: [
        IconButton(
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            icon: icon),
      ],
    );
  }
}
