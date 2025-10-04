import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:pwa_install/pwa_install.dart';

import '../data/constants.dart';

class StartupService {
    static Future<void> init() async {
    await _init();
  }

  static Future<void> _init() async {
    await _initHive();
    await _initDB();
    await _initPWA();
  }

  static Future<void> _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox(Constants.box);
  }

  static Future<void> _initDB() async {
    // Box initialization complete
  }

  static Future _initPWA() async {
    PWAInstall().setup(installCallback: () {
      debugPrint('PWA INSTALLED!');
    });
  }
}
