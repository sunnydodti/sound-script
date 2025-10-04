import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soundscript/data/api_config.dart';
import 'package:soundscript/models/transcript_segment.dart';
import 'package:soundscript/service/transcription_service_interface.dart';

class AssemblyAiService implements TranscriptionService {
  final String _apiKey = ApiConfig.assemblyAiApiKey;
  final String _baseUrl = ApiConfig.assemblyAiBaseUrl;

  Map<String, String> get _headers => {
        'authorization': _apiKey,
        'content-type': 'application/json',
      };

  // Step 1: Upload audio file
  @override
  Future<String> uploadFile(String filePath, {List<int>? fileBytes}) async {
    try {
      List<int> bytes;
      
      if (fileBytes != null) {
        // Use provided bytes (for web or when bytes are already in memory)
        bytes = fileBytes;
      } else {
        // Check if it's a blob URL (web recording)
        if (filePath.startsWith('blob:')) {
          // Fetch blob URL using http package
          final response = await http.get(Uri.parse(filePath));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            throw Exception('Failed to fetch blob URL: ${response.statusCode}');
          }
        } else {
          // Read from file path (mobile)
          final file = File(filePath);
          bytes = await file.readAsBytes();
        }
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/upload'),
        headers: {
          'authorization': _apiKey,
          'content-type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['upload_url'];
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // Step 2: Submit transcription request
  @override
  Future<String> submitTranscription(String uploadUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transcript'),
        headers: _headers,
        body: json.encode({
          'audio_url': uploadUrl,
          'language_code': 'en',
          'punctuate': true,
          'format_text': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw Exception('Transcription submit failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Transcription submit error: $e');
    }
  }

  // Step 3: Poll for transcript result
  @override
  Future<Map<String, dynamic>> getTranscript(String transcriptId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transcript/$transcriptId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Get transcript failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Get transcript error: $e');
    }
  }

  // Complete flow: Upload + Transcribe + Poll
  @override
  Future<Map<String, dynamic>> transcribeAudio(
    String filePath, {
    List<int>? fileBytes,
    Function(TranscriptionStatus, String)? onStatusUpdate,
  }) async {
    try {
      // Step 1: Upload
      onStatusUpdate?.call(TranscriptionStatus.uploading, 'Uploading audio file...');
      final uploadUrl = await uploadFile(filePath, fileBytes: fileBytes);
      
      // Step 2: Submit
      onStatusUpdate?.call(TranscriptionStatus.uploaded, 'Submitting transcription request...');
      final transcriptId = await submitTranscription(uploadUrl);

      // Step 3: Poll for result
      onStatusUpdate?.call(TranscriptionStatus.processing, 'Processing transcription...');
      
      while (true) {
        await Future.delayed(const Duration(seconds: 3));
        
        final result = await getTranscript(transcriptId);
        final status = result['status'];

        if (status == 'completed') {
          onStatusUpdate?.call(TranscriptionStatus.completed, 'Transcription completed!');
          return result;
        } else if (status == 'error') {
          throw Exception('Transcription failed: ${result['error']}');
        }
        // Keep polling if status is 'queued' or 'processing'
      }
    } catch (e) {
      onStatusUpdate?.call(TranscriptionStatus.error, 'Error: $e');
      rethrow;
    }
  }

  // Extract transcript text
  @override
  String extractTranscriptText(Map<String, dynamic> result) {
    return result['text'] ?? '';
  }

  // Extract word-level timestamps (for synchronized playback)
  @override
  List<TranscriptSegment> extractTranscriptSegments(Map<String, dynamic> result) {
    final words = result['words'] as List?;
    if (words == null || words.isEmpty) {
      return [];
    }

    return words.map((word) {
      return TranscriptSegment(
        text: word['text'] ?? '',
        startTimeMs: word['start'] ?? 0,
        endTimeMs: word['end'] ?? 0,
      );
    }).toList();
  }
}
