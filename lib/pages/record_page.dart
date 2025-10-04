import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/provider/recording_provider.dart';
import '../data/theme.dart';
import '../models/recording.dart';
import 'details_page.dart';

enum RecordingMode { normal, live, file }

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  String _lastSuccessMessage = '';
  RecordingMode _selectedMode = RecordingMode.normal;
  RecordingStatus? _lastRecordingStatus;
  bool _showCompletedStatus = false;
  bool _dismissedViewButton = true; // Start hidden, only show after transcription completes
  Recording? _completedRecording; // Store the recording that just completed
  
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
    
    // Reset button state when starting new recording
    setState(() {
      _dismissedViewButton = true;
      _completedRecording = null;
    });
    
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
    
    // Start speech recognition with continuous listening
    await _speechToText.listen(
      onResult: (result) {
        final now = DateTime.now();
        final elapsedMs = now.difference(_liveStartTime!).inMilliseconds;
        
        setState(() {
          _liveTranscript = result.recognizedWords;
          
          // If this is a final result, save it as word-level segments (like API format)
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            // Split phrase into individual words
            final words = result.recognizedWords.split(' ');
            
            // Estimate total phrase duration (time since last segment or 1 second default)
            final lastEndMs = _liveSegments.isNotEmpty 
                ? _liveSegments.last['endTimeMs'] as int
                : 0;
            final phraseStartMs = lastEndMs;
            final phraseDurationMs = elapsedMs - phraseStartMs;
            
            // Distribute time evenly across words
            final msPerWord = words.isNotEmpty ? phraseDurationMs / words.length : 0;
            
            // Add each word as a separate segment (matching API format)
            for (int i = 0; i < words.length; i++) {
              final wordStartMs = (phraseStartMs + (i * msPerWord)).round();
              final wordEndMs = (phraseStartMs + ((i + 1) * msPerWord)).round();
              
              _liveSegments.add({
                'text': words[i],
                'startTimeMs': wordStartMs,
                'endTimeMs': wordEndMs > elapsedMs ? elapsedMs : wordEndMs,
              });
            }
          }
        });
      },
      listenFor: const Duration(minutes: 5), // Maximum 5-minute listening sessions
      pauseFor: const Duration(seconds: 5), // Wait 5 seconds after pause before finalizing
      partialResults: true, // Show partial results immediately
      onSoundLevelChange: null,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation, // Continue listening after pauses
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
  
  void _showTranscriptionOptions(BuildContext context) async {
    final theme = Theme.of(context);
    
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Transcription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how to save your recording:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            
            // Option 1: Save as-is
            InkWell(
              onTap: () => Navigator.pop(context, 'save_as_is'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.save_alt, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Save As-Is',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Uses live transcription (may be less accurate)\n'
                      '• Instant save\n'
                      '• Approximate word timestamps',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Option 2: Server transcription
            InkWell(
              onTap: () => Navigator.pop(context, 'server_transcribe'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_upload, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Server Transcription',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• High accuracy transcription\n'
                      '• Precise word-level timestamps\n'
                      '• Takes a few moments to process',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (choice == null || !mounted) return;
    
    final recordingProvider = context.read<RecordingProvider>();
    
    if (choice == 'save_as_is') {
      // Save with live transcription
      await recordingProvider.saveLiveTranscription(_liveTranscript, _liveSegments);
      
      // Get the saved recording
      if (recordingProvider.recordings.isNotEmpty) {
        final savedRecording = recordingProvider.recordings.first;
        
        setState(() {
          _liveTranscript = '';
          _liveSegments.clear();
          _liveStartTime = null;
          _completedRecording = savedRecording;
          _dismissedViewButton = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording saved with live transcription')),
          );
        }
      }
    } else if (choice == 'server_transcribe') {
      // Save audio first, then transcribe on server
      await recordingProvider.saveLiveRecordingForServerTranscription();
      
      // Clear live transcript state
      setState(() {
        _liveTranscript = '';
        _liveSegments.clear();
        _liveStartTime = null;
      });
      
      // Get the saved recording and trigger transcription
      if (recordingProvider.currentRecording != null) {
        // Trigger server transcription (this will show the status updates)
        await recordingProvider.transcribeCurrentRecording();
        
        // Note: Don't set _completedRecording here - let the status change handler
        // in build() handle it when transcription completes, just like normal/file modes
      }
    }
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
    
    // Track status changes for current recording
    final currentRecording = recordingProvider.currentRecording;
    if (currentRecording != null && _lastRecordingStatus != currentRecording.status) {
      // Status changed
      if (_lastRecordingStatus != null) {
        // Check if transcription just completed
        if (_lastRecordingStatus == RecordingStatus.processing && 
            currentRecording.status == RecordingStatus.completed) {
          // Show completed status for 2 seconds, then show snackbar and hide status
          setState(() {
            _showCompletedStatus = true;
          });
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              // Store reference to the completed recording before resetting
              final completedRec = currentRecording;
              
              // Reset current recording to return to default view
              recordingProvider.resetCurrentRecording();
              
              setState(() {
                _showCompletedStatus = false;
                _dismissedViewButton = false; // Show the button in default view
                _lastRecordingStatus = null;
                _completedRecording = completedRec; // Store the completed recording
              });
              
              // Show success snackbar with action button
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Transcription completed successfully!'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(recording: currentRecording),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          });
        }
      }
      _lastRecordingStatus = currentRecording.status;
    }
    
    // Show success message as SnackBar (for other cases)
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
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: theme.colorScheme.primaryContainer,
                  ),
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
              
              // Error message (only show if not in recording complete state)
              if (recordingProvider.errorMessage.isNotEmpty &&
                  !(_selectedMode == RecordingMode.normal && 
                    recordingProvider.currentRecording != null &&
                    !recordingProvider.isRecording)) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: recordingColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: recordingColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline, 
                        color: recordingColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recordingProvider.errorMessage,
                          style: TextStyle(
                            color: recordingColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => recordingProvider.clearError(),
                        color: recordingColor,
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
    // Show recording complete UI - include all transcription statuses
    if (provider.currentRecording != null && 
        !provider.isRecording && 
        provider.currentRecording!.filePath != null) {
      // Show the complete UI for all post-recording states
      final status = provider.currentRecording!.status;
      final hasTranscript = provider.currentRecording!.transcript != null;
      
      // Show UI if:
      // - Still transcribing (uploading/processing)
      // - Failed
      // - Completed but no transcript yet
      // - Completed with transcript but showing completion animation (_showCompletedStatus)
      if (status == RecordingStatus.uploading ||
          status == RecordingStatus.processing ||
          status == RecordingStatus.failed ||
          (status == RecordingStatus.completed && (!hasTranscript || _showCompletedStatus))) {
        return _buildRecordingCompleteUI(provider, theme);
      }
    }
    
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
            onPressed: provider.isProcessing ? null : () {
              setState(() {
                _dismissedViewButton = true; // Hide button when starting new recording
                _completedRecording = null; // Clear the completed recording reference
              });
              provider.startRecording();
            },
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
                    'After recording, you can play it back and transcribe',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // View Transcription button (only show after a transcription completes, unless dismissed)
          if (!_dismissedViewButton && _completedRecording != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to the newly completed recording
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(recording: _completedRecording!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('View Transcription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _dismissedViewButton = true; // Dismiss the button
                      _completedRecording = null; // Clear the completed recording reference
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildRecordingCompleteUI(RecordingProvider provider, ThemeData theme) {
    final recording = provider.currentRecording!;
    final isPlaying = provider.isPlayingPreview;
    final isTranscribing = recording.status == RecordingStatus.uploading || 
                           recording.status == RecordingStatus.processing;
    final isFromFile = _selectedMode == RecordingMode.file;
    
    return Center(
      child: Column(
        children: [
          // Icon based on status
          Icon(
            recording.status == RecordingStatus.failed
                ? Icons.error_outline
                : isTranscribing
                    ? Icons.hourglass_empty
                    : Icons.check_circle_outline,
            size: 80,
            color: recording.status == RecordingStatus.failed
                ? recordingColor
                : isTranscribing
                    ? theme.colorScheme.primary
                    : Colors.green,
          ),
          const SizedBox(height: 24),
          
          // Title
          Text(
            recording.status == RecordingStatus.failed
                ? 'Transcription Failed'
                : isTranscribing
                    ? 'Processing...'
                    : isFromFile
                        ? 'File Selected!'
                        : 'Recording Complete!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Duration: ${_formatDuration(recording.duration)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          
          // Status indicator (prominent) - show for all statuses except completed (unless just completed)
          if (recording.status != RecordingStatus.completed || _showCompletedStatus) ...[
            const SizedBox(height: 24),
            
            // Progress indicator showing all steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Step 1: Upload
                  _buildProgressStep(
                    '1',
                    'Upload',
                    recording.status == RecordingStatus.uploading,
                    _isStepCompleted(recording.status, RecordingStatus.uploading),
                    theme,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _isStepCompleted(recording.status, RecordingStatus.uploading)
                          ? Colors.green
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  // Step 2: Transcribe
                  _buildProgressStep(
                    '2',
                    'Transcribe',
                    recording.status == RecordingStatus.processing,
                    _isStepCompleted(recording.status, RecordingStatus.processing),
                    theme,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _isStepCompleted(recording.status, RecordingStatus.processing)
                          ? Colors.green
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  // Step 3: Complete
                  _buildProgressStep(
                    '3',
                    'Done',
                    recording.status == RecordingStatus.completed && _showCompletedStatus,
                    recording.status == RecordingStatus.completed,
                    theme,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: recording.status == RecordingStatus.failed
                    ? recordingColor.withOpacity(0.15)
                    : recording.status == RecordingStatus.completed
                        ? Colors.green.withOpacity(0.1)
                        : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: recording.status == RecordingStatus.failed
                      ? recordingColor.withOpacity(0.3)
                      : recording.status == RecordingStatus.completed
                          ? Colors.green.withOpacity(0.3)
                          : theme.colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  if (recording.status == RecordingStatus.uploading) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading Audio File',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sending your recording to the server...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (recording.status == RecordingStatus.processing) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transcribing Audio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Converting speech to text. This may take a moment...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (recording.status == RecordingStatus.failed) ...[
                    Icon(
                      Icons.error_outline,
                      color: recordingColor,
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transcription Failed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: recordingColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: recordingColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (recording.status == RecordingStatus.completed && _showCompletedStatus) ...[
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transcription Completed!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your audio has been successfully transcribed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Playback controls (only show when not transcribing)
          if (!isTranscribing) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          iconSize: 64,
                          color: theme.colorScheme.primary,
                          onPressed: () => provider.togglePreviewPlayback(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPlaying ? 'Playing...' : 'Preview Recording',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Action buttons (only show when not transcribing)
          if (!isTranscribing) ...[
            // Transcribe button (only show if not failed and no transcript)
            if (recording.status != RecordingStatus.failed && recording.transcript == null)
              ElevatedButton.icon(
                onPressed: provider.isProcessing 
                    ? null 
                    : () => provider.transcribeCurrentRecording(),
                icon: const Icon(Icons.transcribe),
                label: const Text('Transcribe Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  minimumSize: const Size(200, 50),
                ),
              ),
            
            // Retry button for failed transcriptions
            if (!kIsWeb && recording.status == RecordingStatus.failed)
              ElevatedButton.icon(
                onPressed: () => provider.transcribeCurrentRecording(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Transcription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  minimumSize: const Size(200, 50),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // New recording button
            OutlinedButton.icon(
              onPressed: () {
                provider.resetCurrentRecording();
                // Reset local state tracking
                setState(() {
                  _lastRecordingStatus = null;
                  _showCompletedStatus = false;
                  _dismissedViewButton = true; // Hide button when resetting
                  _completedRecording = null; // Clear the completed recording reference
                });
              },
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(_selectedMode == RecordingMode.file ? 'Select Another File' : 'Record Again'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLiveTranscriptionMode(ThemeData theme) {
    final recordingProvider = context.watch<RecordingProvider>();
    
    // If user chose server transcription, show the recording complete UI with status updates
    if (recordingProvider.currentRecording != null && 
        recordingProvider.currentRecording!.filePath != null &&
        _liveTranscript.isEmpty) {
      final status = recordingProvider.currentRecording!.status;
      final hasTranscript = recordingProvider.currentRecording!.transcript != null;
      
      if (status == RecordingStatus.uploading ||
          status == RecordingStatus.processing ||
          status == RecordingStatus.failed ||
          (status == RecordingStatus.completed && (!hasTranscript || _showCompletedStatus))) {
        return _buildRecordingCompleteUI(recordingProvider, theme);
      }
    }
    
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
            if (!_isListening) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showTranscriptionOptions(context),
                icon: const Icon(Icons.save),
                label: const Text('Save Transcription'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
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
          
          // View Transcription button (only show after saving, unless dismissed)
          if (!_dismissedViewButton && _completedRecording != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to the saved live recording
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(recording: _completedRecording!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('View Transcription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _dismissedViewButton = true; // Dismiss the button
                      _completedRecording = null; // Clear the completed recording reference
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFileSelectionMode(RecordingProvider provider, ThemeData theme) {
    // Show recording complete UI if file is selected
    if (provider.currentRecording != null && 
        provider.currentRecording!.filePath != null) {
      final status = provider.currentRecording!.status;
      final hasTranscript = provider.currentRecording!.transcript != null;
      
      if (status == RecordingStatus.uploading ||
          status == RecordingStatus.processing ||
          status == RecordingStatus.failed ||
          (status == RecordingStatus.completed && (!hasTranscript || _showCompletedStatus))) {
        return _buildRecordingCompleteUI(provider, theme);
      }
    }
    
    return Center(
      child: Column(
        children: [
          Icon(Icons.folder_open, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Select Audio File', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 48),
          OutlinedButton.icon(
            onPressed: provider.isProcessing ? null : () {
              setState(() {
                _dismissedViewButton = true; // Hide button when selecting new file
                _completedRecording = null; // Clear the completed recording reference
              });
              provider.pickAudioFile();
            },
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
          
          // View Transcription button (only show after a transcription completes, unless dismissed)
          if (!_dismissedViewButton && _completedRecording != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to the newly completed recording
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(recording: _completedRecording!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('View Transcription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _dismissedViewButton = true; // Dismiss the button
                      _completedRecording = null; // Clear the completed recording reference
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                ),
              ],
            ),
          ],
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
  
  // Helper to check if a step is completed
  bool _isStepCompleted(RecordingStatus currentStatus, RecordingStatus stepStatus) {
    // Check if a particular step has been completed based on current status
    
    // Uploading step is completed if we're at processing or completed
    if (stepStatus == RecordingStatus.uploading) {
      return currentStatus == RecordingStatus.processing || 
             currentStatus == RecordingStatus.completed;
    }
    
    // Processing step is completed if we're at completed
    if (stepStatus == RecordingStatus.processing) {
      return currentStatus == RecordingStatus.completed;
    }
    
    return false;
  }
  
  // Build progress step indicator
  Widget _buildProgressStep(
    String number,
    String label,
    bool isActive,
    bool isCompleted,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
            border: Border.all(
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : isActive
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        number,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isCompleted || isActive
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withOpacity(0.5),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
