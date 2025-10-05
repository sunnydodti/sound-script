import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';

// Conditional imports for platform-specific code
import 'recording_provider_stub.dart'
    if (dart.library.html) 'recording_provider_web.dart'
    if (dart.library.io) 'recording_provider_io.dart' as platform;

import '../../models/recording.dart';
import '../../models/transcript_segment.dart';
import '../../service/audio_service.dart';
import '../../service/transcription_service_interface.dart';
import '../../service/transcription_service_factory.dart';
import '../constants.dart';

class RecordingProvider with ChangeNotifier {
  RecordingProvider() {
    _init();
  }

  final AudioService _audioService = AudioService();
  final TranscriptionService _transcriptionService = TranscriptionServiceFactory.getService();
  
  final List<Recording> _recordings = [];
  Recording? _currentRecording;
  Recording? _liveRecording; // For live transcription mode
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  StreamSubscription? _recordingSubscription;
  
  bool _isRecording = false;
  bool _isProcessing = false;
  String _errorMessage = '';
  String _successMessage = '';
  
  // Cache for web file bytes (keyed by recording ID)
  final Map<int, List<int>> _webFileBytes = {};

  List<Recording> get recordings {
    // Sort by creation date, newest first
    final sorted = List<Recording>.from(_recordings);
    sorted.sort((a, b) => b.created.compareTo(a.created));
    return List.unmodifiable(sorted);
  }
  
  Recording? get currentRecording => _currentRecording;
  Duration get recordingDuration => _recordingDuration;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  
  Future<void> _init() async {
    await _audioService.initRecorder();
    await loadRecordings();
  }

  Future<void> loadRecordings() async {
    final box = Hive.box(Constants.box);
    _recordings.clear();
    final recordingHistoryMap =
        box.get(Constants.recordingHistoryKey, defaultValue: {
      'recordings': [],
    });
    final recordingHistory = RecordingHistory.fromMap(
        Map<String, dynamic>.from(recordingHistoryMap));
    _recordings.addAll(recordingHistory.recordings);
    // Only add mock recordings in debug mode or when no recordings exist
    // _recordings.addAll(getMockRecordings());
    notifyListeners();
  }

  Future<void> addRecording(Recording recording) async {
    final box = Hive.box(Constants.box);
    _recordings.add(recording);

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  Future<void> deleteUrl(int index) async {
    final box = Hive.box(Constants.box);
    _recordings.removeAt(index);

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  static Future<void> addNewUrl(Recording url) async {
    final box = Hive.box(Constants.box);
    final recordingHistoryMap =
        box.get(Constants.recordingHistoryKey, defaultValue: {
      'recordings': [],
    });
    final recordingHistory = RecordingHistory.fromMap(
        Map<String, dynamic>.from(recordingHistoryMap));
    recordingHistory.recordings.add(url);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
  }

  // update
  Future<void> updateRecording(int index, Recording recording) async {
    final box = Hive.box(Constants.box);
    _recordings[index] = recording;

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  List<Recording> getMockRecordings() {
    return [
      Recording(),
      Recording(),
      Recording(),
      Recording(),
      Recording(),
    ];
  }
  
  // Start recording
  Future<void> startRecording() async {
    try {
      _errorMessage = '';
      
      // Check and request permission
      if (!await _audioService.hasPermission()) {
        final granted = await _audioService.requestPermission();
        if (!granted) {
          _errorMessage = 'Microphone permission denied';
          notifyListeners();
          return;
        }
      }
      
      // Start recording
      final path = await _audioService.startRecording();
      if (path == null) {
        _errorMessage = 'Failed to start recording';
        notifyListeners();
        return;
      }
      
      // Create new recording object
      _currentRecording = Recording()
        ..filePath = path
        ..status = RecordingStatus.recording
        ..created = DateTime.now();
      
      _isRecording = true;
      _recordingDuration = Duration.zero;
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error starting recording: $e';
      notifyListeners();
    }
  }
  
  // Stop recording (does not auto-transcribe)
  Future<void> stopRecording({bool autoTranscribe = false}) async {
    try {
      _durationTimer?.cancel();
      
      final path = await _audioService.stopRecording();
      if (path == null || _currentRecording == null) {
        _errorMessage = 'Failed to stop recording';
        notifyListeners();
        return;
      }
      
      // Store the path directly (blob URL on web, file path on mobile)
      _currentRecording!.filePath = path;
      _currentRecording!.duration = _recordingDuration;
      _currentRecording!.status = RecordingStatus.completed;
      _currentRecording!.modified = DateTime.now();
      
      _isRecording = false;
      notifyListeners();
      
      // Save recording
      await addRecording(_currentRecording!);
      
      // Optionally auto-transcribe
      if (autoTranscribe) {
        await transcribeRecording(_currentRecording!);
      }
      
    } catch (e) {
      _errorMessage = 'Error stopping recording: $e';
      _isRecording = false;
      notifyListeners();
    }
  }
  
  // Manual transcribe for current recording
  Future<void> transcribeCurrentRecording() async {
    if (_currentRecording != null && _currentRecording!.filePath != null) {
      await transcribeRecording(_currentRecording!);
    }
  }
  
  // Reset current recording to start fresh
  void resetCurrentRecording() {
    _currentRecording = null;
    _recordingDuration = Duration.zero;
    notifyListeners();
  }
  
  // Preview playback for current recording
  bool _isPlayingPreview = false;
  bool get isPlayingPreview => _isPlayingPreview;
  
  Future<void> togglePreviewPlayback() async {
    if (_currentRecording == null || _currentRecording!.filePath == null) return;
    
    if (_isPlayingPreview) {
      await _audioService.stopPlayback();
      _isPlayingPreview = false;
    } else {
      final success = await _audioService.playAudio(
        _currentRecording!.filePath!,
        whenFinished: () {
          _isPlayingPreview = false;
          notifyListeners();
        },
      );
      _isPlayingPreview = success;
    }
    notifyListeners();
  }
  
  // Pick audio file from device
  Future<void> pickAudioFile() async {
    try {
      _errorMessage = '';
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'],
        allowMultiple: false,
      );
      
      if (result != null) {
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        
        // Validate file size (50 MB limit)
        const maxSizeInBytes = 50 * 1024 * 1024; // 50 MB
        if (fileSize > maxSizeInBytes) {
          _errorMessage = 'File size exceeds 50 MB limit. Selected file is ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
          notifyListeners();
          return;
        }
        
        // Validate file extension
        final extension = fileName.split('.').last.toLowerCase();
        final allowedExtensions = ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'];
        if (!allowedExtensions.contains(extension)) {
          _errorMessage = 'Invalid file type. Please select an audio file (MP3, WAV, AAC, M4A, OGG, FLAC)';
          notifyListeners();
          return;
        }
        
        String? filePath;
        Duration? duration;
        List<int>? webBytes;
        
        if (kIsWeb) {
          // Web: Create blob URL from file bytes
          final bytes = result.files.single.bytes;
          if (bytes == null) {
            _errorMessage = 'Unable to read file bytes';
            notifyListeners();
            return;
          }
          
          webBytes = bytes;
          
          // Create blob URL (temporary, will not persist after refresh)
          filePath = platform.createBlobUrl(bytes);
          if (filePath == null) {
            _errorMessage = 'Unable to create blob URL';
            notifyListeners();
            return;
          }
          print('Created blob URL for picked file');
          
          // For web, we'll estimate duration or set a default
          duration = Duration.zero;
        } else {
          // Mobile: Use actual file path
          if (result.files.single.path == null) {
            _errorMessage = 'Unable to access file';
            notifyListeners();
            return;
          }
          
          filePath = result.files.single.path!;
          
          // Check if file exists
          if (!await platform.fileExists(filePath)) {
            _errorMessage = 'Selected file does not exist';
            notifyListeners();
            return;
          }
          duration = await _audioService.getAudioDuration(filePath);
        }
        
        // Create recording from file
        _currentRecording = Recording()
          ..title = fileName.replaceAll(RegExp(r'\.(mp3|wav|aac|m4a|ogg|flac|webm)$', caseSensitive: false), '')
          ..filePath = filePath
          ..duration = duration ?? Duration.zero
          ..status = RecordingStatus.completed
          ..created = DateTime.now()
          ..modified = DateTime.now();
        
        // On web, cache the bytes with the recording ID
        if (kIsWeb && webBytes != null) {
          _webFileBytes[_currentRecording!.id] = webBytes;
        }
        
        await addRecording(_currentRecording!);
        // Don't auto-transcribe, let user preview first
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error picking file: $e';
      notifyListeners();
    }
  }
  
  // Transcribe recording
  Future<void> transcribeRecording(Recording recording) async {
    try {
      _isProcessing = true;
      notifyListeners();
      
      // Get file bytes based on platform
      List<int>? bytes;
      if (kIsWeb) {
        // On web, use cached bytes from picked files
        bytes = _webFileBytes[recording.id];
      } else {
        // On mobile/desktop, read file from path
        if (recording.filePath != null) {
          print('📂 Reading file from path: ${recording.filePath}');
          bytes = await platform.readFileBytes(recording.filePath!);
          print('✅ Read ${bytes.length} bytes from file');
        }
      }
      
      // Get transcript result from service with status callbacks
      final result = await _transcriptionService.transcribeAudio(
        recording.filePath ?? '',
        fileBytes: bytes,
        onStatusUpdate: (status, message) async {
          print('Transcription status: $status - $message');
          
          // Update recording status based on transcription service status
          switch (status) {
            case TranscriptionStatus.uploading:
              recording.status = RecordingStatus.uploading;
              break;
            case TranscriptionStatus.uploaded:
              recording.status = RecordingStatus.uploading;
              break;
            case TranscriptionStatus.processing:
              recording.status = RecordingStatus.processing;
              break;
            case TranscriptionStatus.completed:
              recording.status = RecordingStatus.completed;
              break;
            case TranscriptionStatus.error:
              recording.status = RecordingStatus.failed;
              break;
            default:
              break;
          }
          
          // Persist status updates to storage immediately
          recording.modified = DateTime.now();
          final index = _recordings.indexWhere((r) => r.id == recording.id);
          if (index != -1) {
            await updateRecording(index, recording);
          }
          
          notifyListeners();
        },
      );
      
      // Extract transcript text
      final transcriptText = _transcriptionService.extractTranscriptText(result);
      recording.transcript = transcriptText;
      
      // Try to get word-level timestamps from API
      final segments = _transcriptionService.extractTranscriptSegments(result);
      
      if (segments.isNotEmpty) {
        // Use API-provided timestamps
        recording.transcriptSegments = segments;
      } else if (transcriptText.isNotEmpty && recording.duration.inMilliseconds > 0) {
        // Fallback: Generate evenly distributed timestamps
        final words = transcriptText.split(' ');
        final totalDurationMs = recording.duration.inMilliseconds;
        final msPerWord = totalDurationMs / words.length;
        
        recording.transcriptSegments = [];
        int currentTimeMs = 0;
        
        for (final word in words) {
          final startMs = currentTimeMs;
          final endMs = (currentTimeMs + msPerWord).round();
          
          recording.transcriptSegments.add(
            TranscriptSegment(
              text: word,
              startTimeMs: startMs,
              endTimeMs: endMs > totalDurationMs ? totalDurationMs : endMs,
            ),
          );
          
          currentTimeMs = endMs;
        }
      }
      
      // Only set to completed if not already failed
      if (recording.status != RecordingStatus.failed) {
        recording.status = RecordingStatus.completed;
      }
      recording.modified = DateTime.now();
      
      // Update in storage
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index != -1) {
        await updateRecording(index, recording);
      }
      
      _isProcessing = false;
      
      // Only show success message if actually completed
      if (recording.status == RecordingStatus.completed) {
        _successMessage = 'Transcription completed successfully!';
        
        // Auto-clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          _successMessage = '';
          notifyListeners();
        });
      }
      
      notifyListeners();
    } catch (e) {
      recording.status = RecordingStatus.failed;
      recording.modified = DateTime.now();
      
      // Persist the failed status to storage
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index != -1) {
        await updateRecording(index, recording);
      }
      
      _errorMessage = 'Transcription failed: $e';
      notifyListeners();
    } finally {
      // Always ensure processing flag is reset
      _isProcessing = false;
      notifyListeners();
    }
  }
  
  // Update recording title
  Future<void> updateRecordingTitle(int index, String newTitle) async {
    if (index >= 0 && index < _recordings.length) {
      _recordings[index].title = newTitle;
      _recordings[index].modified = DateTime.now();
      await updateRecording(index, _recordings[index]);
    }
  }
  
  // Delete recording by ID (more reliable than index)
  Future<void> deleteRecordingById(int recordingId) async {
    final index = _recordings.indexWhere((r) => r.id == recordingId);
    if (index != -1) {
      await deleteRecording(index);
    }
  }
  
  // Delete recording
  Future<void> deleteRecording(int index) async {
    if (index >= 0 && index < _recordings.length) {
      // Delete audio file (only on mobile)
      final recording = _recordings[index];
      if (recording.filePath != null && !kIsWeb) {
        try {
          await platform.deleteFile(recording.filePath!);
        } catch (e) {
          print('Error deleting file: $e');
        }
      }
      // On web, files are stored in browser memory and cleaned up automatically
      
      await deleteUrl(index);
    }
  }
  
  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  
  // Clear success message
  void clearSuccess() {
    _successMessage = '';
    notifyListeners();
  }
  
  // Start live recording (with audio)
  Future<bool> startLiveRecording() async {
    try {
      _errorMessage = '';
      
      // Check and request permission
      if (!await _audioService.hasPermission()) {
        final granted = await _audioService.requestPermission();
        if (!granted) {
          _errorMessage = 'Microphone permission denied';
          notifyListeners();
          return false;
        }
      }
      
      // Start recording
      final path = await _audioService.startRecording();
      if (path == null) {
        _errorMessage = 'Failed to start recording';
        notifyListeners();
        return false;
      }
      
      // Create new recording object for live mode
      _liveRecording = Recording()
        ..filePath = path
        ..status = RecordingStatus.recording
        ..created = DateTime.now();
      
      _isRecording = true;
      _recordingDuration = Duration.zero;
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
      });
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error starting live recording: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Stop live recording
  Future<void> stopLiveRecording() async {
    try {
      _durationTimer?.cancel();
      
      final path = await _audioService.stopRecording();
      
      if (_liveRecording != null && path != null) {
        _liveRecording!.filePath = path;
        _liveRecording!.duration = _recordingDuration;
      }
      
      _isRecording = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error stopping live recording: $e';
      _isRecording = false;
      notifyListeners();
    }
  }
  
  // Save live transcription (with audio file) - for "Save As-Is" option
  Future<void> saveLiveTranscription(String transcript, List<Map<String, dynamic>> segments) async {
    try {
      if (_liveRecording == null) {
        _errorMessage = 'No live recording found';
        notifyListeners();
        return;
      }
      
      // Update the live recording with transcript data
      _liveRecording!
        ..title = 'Live_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}'
        ..transcript = transcript
        ..transcriptSegments = segments.map((seg) => TranscriptSegment.fromMap(seg)).toList()
        ..status = RecordingStatus.completed
        ..modified = DateTime.now();
      
      await addRecording(_liveRecording!);
      _successMessage = 'Live transcription saved with audio!';
      
      // Clear live recording reference
      _liveRecording = null;
      _recordingDuration = Duration.zero;
      
      // Clear success message after 3 seconds
      Timer(const Duration(seconds: 3), () {
        _successMessage = '';
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save transcription: $e';
      notifyListeners();
    }
  }
  
  // Save live recording for server transcription - for "Server Transcription" option
  Future<void> saveLiveRecordingForServerTranscription() async {
    try {
      if (_liveRecording == null) {
        _errorMessage = 'No live recording found';
        notifyListeners();
        return;
      }
      
      // Save the recording with basic info, no transcript yet
      _liveRecording!
        ..title = 'Live_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}'
        ..status = RecordingStatus.uploading // Will start transcription process
        ..modified = DateTime.now();
      
      await addRecording(_liveRecording!);
      
      // Set as current recording for transcription
      _currentRecording = _liveRecording;
      
      // Clear live recording reference
      _liveRecording = null;
      _recordingDuration = Duration.zero;
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save recording: $e';
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _durationTimer?.cancel();
    _recordingSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
