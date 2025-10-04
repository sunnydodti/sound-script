import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  
  // Initialize recorder
  Future<bool> initRecorder() async {
    if (_isRecorderInitialized) return true;
    
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing recorder: $e');
      return false;
    }
  }
  
  // Initialize player
  Future<bool> initPlayer() async {
    if (_isPlayerInitialized) return true;
    
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      _isPlayerInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing player: $e');
      return false;
    }
  }
  
  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  // Check if permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
  
  // Start recording
  Future<String?> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }
    
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return null;
    }
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/recording_$timestamp.aac';
      
      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );
      
      return path;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }
  
  // Stop recording
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder!.stopRecorder();
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }
  
  // Get current recording duration
  Stream<Duration>? get recordingStream {
    return _recorder?.onProgress?.map((e) => e.duration);
  }
  
  // Play audio
  Future<bool> playAudio(String path) async {
    if (!_isPlayerInitialized) {
      await initPlayer();
    }
    
    try {
      await _player!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
        whenFinished: () {
          print('Playback finished');
        },
      );
      return true;
    } catch (e) {
      print('Error playing audio: $e');
      return false;
    }
  }
  
  // Stop playback
  Future<void> stopPlayback() async {
    try {
      await _player?.stopPlayer();
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }
  
  // Pause playback
  Future<void> pausePlayback() async {
    try {
      await _player?.pausePlayer();
    } catch (e) {
      print('Error pausing playback: $e');
    }
  }
  
  // Resume playback
  Future<void> resumePlayback() async {
    try {
      await _player?.resumePlayer();
    } catch (e) {
      print('Error resuming playback: $e');
    }
  }
  
  // Get player state
  bool get isPlaying => _player?.isPlaying ?? false;
  
  // Get playback position stream
  Stream<Duration>? get playbackStream {
    return _player?.onProgress?.map((e) => e.position);
  }
  
  // Dispose resources
  Future<void> dispose() async {
    try {
      await _recorder?.closeRecorder();
      await _player?.closePlayer();
      _isRecorderInitialized = false;
      _isPlayerInitialized = false;
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }
}
