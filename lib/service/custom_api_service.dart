import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soundscript/data/api_config.dart';
import 'package:soundscript/models/transcript_segment.dart';
import 'package:soundscript/service/transcription_service_interface.dart';

/// Sound Script API Service
/// Connects to the Sound Script backend for audio transcription
/// No authentication required - open API
class CustomApiService implements TranscriptionService {
  final String _baseUrl = ApiConfig.apiBaseUrl;

  /// Log API calls with details
  void _logApiCall(String method, String url, {Map<String, dynamic>? body, Map<String, String>? headers}) {
    final bodyStr = body != null ? ' Body: ${json.encode(body)}' : '';
    print('🌐 $method $url$bodyStr');
  }

  /// Log API response
  void _logApiResponse(int statusCode, String body) {
    print('✅ $statusCode ${body.length > 100 ? body.substring(0, 100) + '...' : body}');
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
      };

  // Step 1: Upload audio file to your backend
  @override
  Future<String> uploadFile(String filePath, {List<int>? fileBytes}) async {
    try {
      List<int> bytes;
      
      if (fileBytes != null) {
        // Use provided bytes (passed from caller)
        print('📦 Using provided bytes: ${fileBytes.length} bytes');
        bytes = fileBytes;
      } else {
        // Check if it's a blob URL (web recording)
        if (filePath.startsWith('blob:')) {
          print('🌐 Fetching blob URL: $filePath');
          final response = await http.get(Uri.parse(filePath));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            throw Exception('Failed to fetch blob URL: ${response.statusCode}');
          }
        } else {
          // On mobile platforms, fileBytes should always be provided
          // This path should never be hit due to recording_provider passing fileBytes
          throw Exception('fileBytes parameter is required. File path: $filePath');
        }
      }

      final uploadUrl = '$_baseUrl/upload';
      final uploadHeaders = {'content-type': 'application/octet-stream'};
      
      _logApiCall('POST', uploadUrl, headers: uploadHeaders);
      print('📦 Body: Binary audio data (${bytes.length} bytes)');

      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: uploadHeaders,
        body: bytes,
      );

      _logApiResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['upload_url'];
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Upload error: $e');
    }
  }

  // Step 2: Submit transcription request to your backend
  @override
  Future<String> submitTranscription(String uploadUrl) async {
    try {
      final transcribeUrl = '$_baseUrl/transcribe';
      final requestBody = {
        'audio_url': uploadUrl,
        'language_code': 'en',
        'punctuate': true,
        'format_text': true,
      };

      _logApiCall('POST', transcribeUrl, headers: _headers, body: requestBody);

      final response = await http.post(
        Uri.parse(transcribeUrl),
        headers: _headers,
        body: json.encode(requestBody),
      );

      _logApiResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw Exception('Transcription submit failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Transcription submit error: $e');
      throw Exception('Transcription submit error: $e');
    }
  }

  // Step 3: Poll for transcript result from your backend
  @override
  Future<Map<String, dynamic>> getTranscript(String transcriptId) async {
    try {
      final transcriptUrl = '$_baseUrl/transcript/$transcriptId';
      
      _logApiCall('GET', transcriptUrl, headers: _headers);

      final response = await http.get(
        Uri.parse(transcriptUrl),
        headers: _headers,
      );

      _logApiResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Get transcript failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Get transcript error: $e');
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
