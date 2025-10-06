import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  // Singleton pattern to avoid multiple flutter_sound instances
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();
  
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _recorderCreationFailed = false; // Track if creation has failed
  
  // Initialize recorder
  Future<bool> initRecorder() async {
    // If already initialized successfully, return true
    if (_isRecorderInitialized && _recorder != null) return true;
    
    // If creation has failed before, don't try again (would create multiple instances)
    if (_recorderCreationFailed) {
      print('⚠️ Recorder initialization previously failed. Please reload the page.');
      return false;
    }
    
    // If recorder exists but isn't initialized, something went wrong
    if (_recorder != null && !_isRecorderInitialized) {
      print('⚠️ Recorder in bad state. Please reload the page.');
      _recorderCreationFailed = true;
      return false;
    }
    
    try {
      // Create recorder instance - this should only happen ONCE per app lifecycle
      print('🎤 Creating FlutterSoundRecorder instance...');
      _recorder = FlutterSoundRecorder();
      
      print('🎤 Opening recorder...');
      await _recorder!.openRecorder();
      
      _isRecorderInitialized = true;
      _recorderCreationFailed = false;
      print('✅ Recorder initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing recorder: $e');
      print('⚠️ Please reload the page to reset the audio system.');
      
      // Mark as failed to prevent retry (which would create another instance)
      _recorderCreationFailed = true;
      _isRecorderInitialized = false;
      
      // Keep _recorder object to prevent ??= from creating another instance
      return false;
    }
  }
  
  // Initialize player
  Future<bool> initPlayer() async {
    if (_isPlayerInitialized && _player != null) return true;
    
    try {
      // Only create if it doesn't exist
      _player ??= FlutterSoundPlayer();
      
      // Only open if not already opened
      if (!_isPlayerInitialized) {
        await _player!.openPlayer();
        
        // Set default subscription duration for progress updates
        await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
        
        _isPlayerInitialized = true;
      }
      return true;
    } catch (e) {
      print('Error initializing player: $e');
      _isPlayerInitialized = false;
      return false;
    }
  }
  
  // Request microphone permission
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      // Web: Check HTTPS and browser support
      try {
        print('🌐 Web: Checking microphone access...');
        
        // Check if we're on HTTPS (required for production microphone access)
        final isSecure = Uri.base.scheme == 'https' || Uri.base.host == 'localhost';
        if (!isSecure) {
          print('❌ Web: Microphone requires HTTPS in production. Current: ${Uri.base.scheme}://${Uri.base.host}');
          return false;
        }
        
        // Check if MediaDevices API is available
        if (!kIsWeb) return true; // This is for web only
        
        print('✅ Web: HTTPS check passed. Browser will handle permission request.');
        return true;
      } catch (e) {
        print('❌ Web: Error checking permissions: $e');
        return false;
      }
    }
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  // Check if permission is granted
  Future<bool> hasPermission() async {
    if (kIsWeb) {
      // Web: Browser will handle permission
      return true;
    }
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
  
  // Start recording
  Future<String?> startRecording() async {
    print('🎤 Starting recording...');
    
    if (!_isRecorderInitialized) {
      print('🎤 Initializing recorder...');
      final success = await initRecorder();
      if (!success) {
        print('❌ Failed to initialize recorder');
        return null;
      }
    }
    
    if (!await hasPermission()) {
      print('🎤 Requesting microphone permission...');
      final granted = await requestPermission();
      if (!granted) {
        print('❌ Microphone permission denied');
        return null;
      }
    }

    try {
      String path;
      
      if (kIsWeb) {
        // Web: Use a simple identifier, actual data is stored in browser memory
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        path = 'recording_$timestamp.webm';
        
        print('🌐 Web: Starting recording with path: $path');
        
        await _recorder!.startRecorder(
          toFile: path,
          codec: Codec.opusWebM, // Web-compatible codec
          audioSource: AudioSource.microphone,
        );
        
        print('✅ Web: Recording started successfully');
      } else {
        // Mobile: Use file system
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        path = '${dir.path}/recording_$timestamp.aac';
        
        print('📱 Mobile: Starting recording with path: $path');
        
        await _recorder!.startRecorder(
          toFile: path,
          codec: Codec.aacADTS,
          audioSource: AudioSource.microphone,
        );
        
        print('✅ Mobile: Recording started successfully');
      }
      
      return path;
    } catch (e) {
      print('❌ Error starting recording: $e');
      if (kIsWeb) {
        print('💡 Web recording troubleshooting:');
        print('   - Ensure site is served over HTTPS');
        print('   - Check browser console for permission errors');
        print('   - Try allowing microphone in browser settings');
        print('   - Current URL: ${Uri.base}');
      }
      return null;
    }
  }  // Stop recording
  Future<String?> stopRecording() async {
    print('🛑 Stopping recording...');
    try {
      final path = await _recorder!.stopRecorder();
      print('✅ Recording stopped successfully. Path: $path');
      return path;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      if (kIsWeb) {
        print('💡 Web recording stop issues may indicate permission or codec problems');
      }
      return null;
    }
  }
  
  // Get current recording duration
  Stream<Duration>? get recordingStream {
    return _recorder?.onProgress?.map((e) => e.duration);
  }
  
  // Play audio
  Future<bool> playAudio(String path, {Function? whenFinished}) async {
    print('▶️ Starting playback: $path');
    
    if (!_isPlayerInitialized) {
      print('🔧 Initializing player...');
      await initPlayer();
    }
    
    try {
      await _player!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
        whenFinished: () {
          print('🏁 Playback finished');
          whenFinished?.call();
        },
      );
      
      print('✅ Player started successfully');
      print('🔊 Progress stream available: ${_player!.onProgress != null}');
      return true;
    } catch (e) {
      print('❌ Error playing audio: $e');
      if (kIsWeb) {
        print('💡 Web playback troubleshooting:');
        print('   - Check if audio format is supported');
        print('   - Ensure audio file exists');
        print('   - Browser may block autoplay');
      }
      return false;
    }
  }
  
  // Stop playback
  Future<void> stopPlayback() async {
    print('⏹️ Stopping playback...');
    try {
      await _player?.stopPlayer();
      print('✅ Playback stopped');
    } catch (e) {
      print('❌ Error stopping playback: $e');
    }
  }
  
  // Pause playback
  Future<void> pausePlayback() async {
    print('⏸️ Pausing playback...');
    try {
      await _player?.pausePlayer();
      print('✅ Playback paused');
    } catch (e) {
      print('❌ Error pausing playback: $e');
    }
  }
  
  // Resume playback
  Future<void> resumePlayback() async {
    print('▶️ Resuming playback...');
    try {
      await _player?.resumePlayer();
      print('✅ Playback resumed');
    } catch (e) {
      print('❌ Error resuming playback: $e');
    }
  }
  
  // Get player state
  bool get isPlaying => _player?.isPlaying ?? false;
  
  // Get playback position stream
  Stream<Duration>? get playbackStream {
    return _player?.onProgress?.map((e) => e.position);
  }
  
  // Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      await _player?.seekToPlayer(position);
    } catch (e) {
      print('Error seeking: $e');
    }
  }
  
  // Get audio file duration from metadata
  Future<Duration?> getAudioDuration(String path) async {
    if (!_isPlayerInitialized) {
      await initPlayer();
    }
    
    try {
      // Start player to get duration, then immediately stop
      await _player!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
      );
      
      // Wait briefly for player to load metadata
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Get duration from player state
      final progress = await _player!.getProgress();
      final totalDuration = progress['duration'];
      
      // Stop immediately
      await _player!.stopPlayer();
      
      return totalDuration;
    } catch (e) {
      print('Error getting audio duration: $e');
      return null;
    }
  }
  
  // Get current playback duration
  Future<Duration?> getCurrentDuration() async {
    try {
      if (_player != null && _player!.isPlaying) {
        final progress = await _player!.getProgress();
        return progress['duration'];
      }
      return null;
    } catch (e) {
      print('Error getting current duration: $e');
      return null;
    }
  }
  
  // Dispose resources
  Future<void> dispose() async {
    try {
      await _recorder?.closeRecorder();
      await _player?.closePlayer();
      _recorder = null;
      _player = null;
      _isRecorderInitialized = false;
      _isPlayerInitialized = false;
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }
}
