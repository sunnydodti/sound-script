import 'package:soundscript/service/transcription_service_interface.dart';
import 'package:soundscript/service/assembly_ai_service.dart';
import 'package:soundscript/service/custom_api_service.dart';

/// Factory to switch between AssemblyAI and Custom API
/// Change this to switch the entire app's transcription provider
class TranscriptionServiceFactory {
  // Toggle this to switch between AssemblyAI and your custom API
  static const bool _useCustomApi = false; // Set to true when your API is ready

  static TranscriptionService getService() {
    if (_useCustomApi) {
      return CustomApiService(); // Your custom API wrapper
    } else {
      return AssemblyAiService(); // Direct AssemblyAI integration
    }
  }
}
