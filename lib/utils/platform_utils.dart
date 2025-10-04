import 'package:flutter/foundation.dart';

class PlatformUtils {
  /// Check if running on web
  static bool get isWeb => kIsWeb;
  
  /// Check if running on mobile (Android or iOS)
  static bool get isMobile => !kIsWeb;
  
  /// Check if file operations are supported
  static bool get supportsFileOperations => !kIsWeb;
  
  /// Check if local file system is available
  static bool get hasFileSystem => !kIsWeb;
  
  /// Check if recording to file is supported
  static bool get supportsFileRecording => !kIsWeb;
  
  /// Get a web-safe message for unsupported features
  static String getUnsupportedMessage(String feature) {
    return 'Cannot $feature on web platform. Please use the mobile app for full functionality.';
  }
  
  /// Show if a feature is available on current platform
  static bool isFeatureAvailable(String feature) {
    if (kIsWeb) {
      // List features not available on web
      const webUnsupportedFeatures = [
        'file_recording',
        'file_deletion',
        'file_picker',
      ];
      return !webUnsupportedFeatures.contains(feature);
    }
    return true;
  }
}
