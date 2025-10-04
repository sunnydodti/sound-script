import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/provider/theme_provider.dart';
import 'data/provider/soundscript_provider.dart';
import 'service/startup_service.dart';

void main() async {
  await StartupService.init();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      // ChangeNotifierProvider(create: (_) => UrlProvider()),
    ],
    child: const SoundScript(),
  ));
}