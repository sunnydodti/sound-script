import 'package:soundscript/service/transcription_service_interface.dart';
import 'package:soundscript/service/custom_api_service.dart';

/// Factory for transcription service
/// Uses the custom Sound Script API
class TranscriptionServiceFactory {
  static TranscriptionService getService() {
    return CustomApiService();
  }
}
