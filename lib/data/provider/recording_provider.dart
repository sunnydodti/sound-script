import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/recording.dart';
import '../../models/transcript_segment.dart';
import '../../service/audio_service.dart';
import '../../service/transcription_service.dart';
import '../constants.dart';

class RecordingProvider with ChangeNotifier {
  RecordingProvider() {
    _init();
  }

  final AudioService _audioService = AudioService();
  final TranscriptionService _transcriptionService = TranscriptionService();
  
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

  List<Recording> get recordings => List.unmodifiable(_recordings);
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
  
  // Stop recording
  Future<void> stopRecording() async {
    try {
      _durationTimer?.cancel();
      
      final path = await _audioService.stopRecording();
      if (path == null || _currentRecording == null) {
        _errorMessage = 'Failed to stop recording';
        notifyListeners();
        return;
      }
      
      _currentRecording!.filePath = path;
      _currentRecording!.duration = _recordingDuration;
      _currentRecording!.status = RecordingStatus.completed;
      _currentRecording!.modified = DateTime.now();
      
      _isRecording = false;
      notifyListeners();
      
      // Auto-save and transcribe
      await addRecording(_currentRecording!);
      await transcribeRecording(_currentRecording!);
      
    } catch (e) {
      _errorMessage = 'Error stopping recording: $e';
      _isRecording = false;
      notifyListeners();
    }
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
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
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
        
        // Check if file exists
        if (!await file.exists()) {
          _errorMessage = 'Selected file does not exist';
          notifyListeners();
          return;
        }
        
        // Create recording from file
        final recording = Recording()
          ..title = fileName.replaceAll(RegExp(r'\.(mp3|wav|aac|m4a|ogg|flac)$', caseSensitive: false), '')
          ..filePath = file.path
          ..status = RecordingStatus.completed
          ..created = DateTime.now()
          ..modified = DateTime.now();
        
        await addRecording(recording);
        await transcribeRecording(recording);
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
      recording.status = RecordingStatus.processing;
      notifyListeners();
      
      // Get transcript from service
      final transcript = await _transcriptionService.transcribeAudio(recording.filePath ?? '');
      
      recording.transcript = transcript;
      
      // Generate mock timestamps for synchronized playback
      // Split transcript into words and distribute evenly across duration
      if (transcript.isNotEmpty && recording.duration.inMilliseconds > 0) {
        final words = transcript.split(' ');
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
      
      recording.status = RecordingStatus.completed;
      recording.modified = DateTime.now();
      
      // Update in storage
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index != -1) {
        await updateRecording(index, recording);
      }
      
      _isProcessing = false;
      _successMessage = 'Transcription completed successfully!';
      notifyListeners();
      
      // Auto-clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        _successMessage = '';
        notifyListeners();
      });
    } catch (e) {
      recording.status = RecordingStatus.failed;
      _errorMessage = 'Transcription failed: $e';
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
  
  // Delete recording
  Future<void> deleteRecording(int index) async {
    if (index >= 0 && index < _recordings.length) {
      // Delete audio file
      final recording = _recordings[index];
      if (recording.filePath != null) {
        try {
          final file = File(recording.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting file: $e');
        }
      }
      
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
  
  // Save live transcription (with audio file)
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
  
  @override
  void dispose() {
    _durationTimer?.cancel();
    _recordingSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
