import 'package:flutter/foundation.dart';

class Constants {
  static String appDisplayName = 'Sound Script';

  static String box = 'sound_script_box';

  static String isDarkMode = 'isDarkMode';

  static final String _apiBase = 'url.persist.site';

  static String get apiBase {
    if (kDebugMode) {
      return 'https://url.persist.site';
      // return 'http://127.0.0.1:61131';
    }
    return 'https://$_apiBase';
  }

  static String indexKey = 'index';

  static String recordingHistoryKey = 'recording_history';
}
