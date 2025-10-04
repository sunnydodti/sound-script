import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/provider/recording_provider.dart';
import '../data/theme.dart';

enum RecordingMode { normal, live, file }

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  String _lastSuccessMessage = '';
  RecordingMode _selectedMode = RecordingMode.normal;
  
  // Live transcription
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  String _liveTranscript = '';
  bool _isListening = false;
  List<Map<String, dynamic>> _liveSegments = []; // Store segments with timestamps
  DateTime? _liveStartTime;
  
  @override
  void initState() {
    super.initState();
    _initSpeech();
  }
  
  void _initSpeech() async {
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }
  
  void _startLiveListening() async {
    final recordingProvider = context.read<RecordingProvider>();
    
    // Start audio recording
    final started = await recordingProvider.startLiveRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start audio recording')),
        );
      }
      return;
    }
    
    _liveStartTime = DateTime.now();
    _liveSegments.clear();
    _liveTranscript = '';
    
    // Start speech recognition
    await _speechToText.listen(
      onResult: (result) {
        final now = DateTime.now();
        final elapsedMs = now.difference(_liveStartTime!).inMilliseconds;
        
        setState(() {
          _liveTranscript = result.recognizedWords;
          
          // If this is a final result, save it as a segment
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            // Estimate segment duration (500ms per segment as default)
            final segmentDuration = 500;
            final startMs = elapsedMs - segmentDuration;
            
            _liveSegments.add({
              'text': result.recognizedWords,
              'startTimeMs': startMs > 0 ? startMs : 0,
              'endTimeMs': elapsedMs,
            });
          }
        });
      },
    );
    setState(() => _isListening = true);
  }
  
  void _stopLiveListening() async {
    final recordingProvider = context.read<RecordingProvider>();
    
    // Stop audio recording
    await recordingProvider.stopLiveRecording();
    
    // Stop speech recognition
    await _speechToText.stop();
    setState(() => _isListening = false);
  }
  
  void _saveLiveTranscription(BuildContext context) async {
    if (_liveTranscript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcription to save')),
      );
      return;
    }
    
    final recordingProvider = context.read<RecordingProvider>();
    await recordingProvider.saveLiveTranscription(_liveTranscript, _liveSegments);
    
    setState(() {
      _liveTranscript = '';
      _liveSegments.clear();
      _liveStartTime = null;
    });
  }
  
  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }
  
  void _showFileRequirements(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('File Requirements'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supported Audio Formats:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• MP3\n• WAV\n• AAC\n• M4A\n• OGG\n• FLAC'),
            const SizedBox(height: 16),
            const Text(
              'File Size Limit:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Maximum 50 MB per file'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates, 
                    size: 20, 
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tip: Shorter files transcribe faster!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final recordingProvider = context.watch<RecordingProvider>();
    final theme = Theme.of(context);
    
    // Show success message as SnackBar
    if (recordingProvider.successMessage.isNotEmpty && 
        recordingProvider.successMessage != _lastSuccessMessage) {
      _lastSuccessMessage = recordingProvider.successMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(recordingProvider.successMessage),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              
              // Mode Selection Tabs
              if (!recordingProvider.isRecording && !_isListening) ...[
                SegmentedButton<RecordingMode>(
                  segments: const [
                    ButtonSegment<RecordingMode>(
                      value: RecordingMode.normal,
                      label: Text('Record'),
                      icon: Icon(Icons.fiber_manual_record),
                    ),
                    ButtonSegment<RecordingMode>(
                      value: RecordingMode.live,
                      label: Text('Live'),
                      icon: Icon(Icons.record_voice_over),
                    ),
                    ButtonSegment<RecordingMode>(
                      value: RecordingMode.file,
                      label: Text('File'),
                      icon: Icon(Icons.folder_open),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (Set<RecordingMode> newSelection) {
                    setState(() {
                      _selectedMode = newSelection.first;
                      _liveTranscript = '';
                    });
                  },
                ),
                const SizedBox(height: 32),
              ],
              
              // Content based on selected mode
              if (_selectedMode == RecordingMode.normal)
                _buildNormalRecordingMode(recordingProvider, theme)
              else if (_selectedMode == RecordingMode.live)
                _buildLiveTranscriptionMode(theme)
              else
                _buildFileSelectionMode(recordingProvider, theme),
              
              // Processing indicator
              if (recordingProvider.isProcessing) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Transcribing audio...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
              
              // Error message
              if (recordingProvider.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline, 
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recordingProvider.errorMessage,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => recordingProvider.clearError(),
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNormalRecordingMode(RecordingProvider provider, ThemeData theme) {
    if (provider.isRecording) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.mic, size: 80, color: recordingColor),
            const SizedBox(height: 24),
            Text('Recording...', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              _formatDuration(provider.recordingDuration),
              style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => provider.stopRecording(),
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: recordingColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: Column(
        children: [
          Icon(Icons.mic_none, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Ready to Record', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: provider.isProcessing ? null : () => provider.startRecording(),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Start Recording'),
            style: ElevatedButton.styleFrom(
              backgroundColor: recordingColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Audio will be saved and transcribed automatically',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLiveTranscriptionMode(ThemeData theme) {
    final recordingProvider = context.watch<RecordingProvider>();
    
    return Center(
      child: Column(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            size: 80,
            color: _isListening ? recordingColor : theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            _isListening ? 'Recording & Listening...' : 'Ready for Live Transcription',
            style: theme.textTheme.headlineSmall,
          ),
          if (_isListening && recordingProvider.isRecording) ...[
            const SizedBox(height: 16),
            Text(
              _formatDuration(recordingProvider.recordingDuration),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: recordingColor,
              ),
            ),
          ],
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _speechEnabled 
                ? (_isListening ? _stopLiveListening : _startLiveListening)
                : null,
            icon: Icon(_isListening ? Icons.stop : Icons.mic),
            label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
            style: ElevatedButton.styleFrom(
              backgroundColor: recordingColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          if (_liveTranscript.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              constraints: const BoxConstraints(minHeight: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Live Transcript',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _liveTranscript,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _saveLiveTranscription(context),
              icon: const Icon(Icons.save),
              label: const Text('Save Transcription'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ]
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Real-time transcription with audio recording. Play back with synchronized text!',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFileSelectionMode(RecordingProvider provider, ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.folder_open, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Select Audio File', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 48),
          OutlinedButton.icon(
            onPressed: provider.isProcessing ? null : () => provider.pickAudioFile(),
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose Audio File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _showFileRequirements(context),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text(
              'File Requirements (Max 50 MB)',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle, 
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Accepted: MP3, WAV, AAC, M4A, OGG, FLAC • Max 50 MB',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
