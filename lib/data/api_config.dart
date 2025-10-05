import 'package:flutter/foundation.dart';

class ApiConfig {
  // API configuration
  static const bool isDevelopment = kDebugMode; // Toggle for dev/prod
  
  static String get apiBaseUrl {
    if (isDevelopment) {
      // return 'https://soundscript-api.dodtisunny.workers.dev/api/v1';
      return 'http://127.0.0.1:8787/api/v1';
    } else {
      return 'https://soundscript-api.dodtisunny.workers.dev/api/v1';
    }
  }
}
