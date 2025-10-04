import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/constants.dart';
import 'data/provider/theme_provider.dart';

class SoundScript extends StatelessWidget {
  const SoundScript({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.appDisplayName,
      theme: context.watch<ThemeProvider>().theme,
      home: Placeholder(),
    );
  }
}
