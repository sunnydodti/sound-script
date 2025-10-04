import 'package:soundscript/models/transcript_segment.dart';

abstract class TranscriptionService {
  Future<String> uploadFile(String filePath);
  Future<String> submitTranscription(String uploadUrl);
  Future<Map<String, dynamic>> getTranscript(String transcriptId);
  Future<Map<String, dynamic>> transcribeAudio(
    String filePath, {
    Function(TranscriptionStatus, String)? onStatusUpdate,
  });
  String extractTranscriptText(Map<String, dynamic> result);
  List<TranscriptSegment> extractTranscriptSegments(Map<String, dynamic> result);
}

enum TranscriptionStatus {
  idle,
  uploading,
  uploaded,
  processing,
  completed,
  error,
}
