import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// Platform-specific imports
import '../data/provider/recording_provider_stub.dart'
    if (dart.library.html) '../data/provider/recording_provider_web.dart'
    if (dart.library.io) '../data/provider/recording_provider_io.dart' as platform;

import '../data/provider/recording_provider.dart';
import '../data/theme.dart';
import '../models/recording.dart';
import '../models/transcript_segment.dart';
import '../service/audio_service.dart';
import '../widgets/mobile_wrapper.dart';

class DetailsPage extends StatefulWidget {
  final Recording recording;
  
  const DetailsPage({super.key, required this.recording});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isEditingTranscript = false;
  bool _isAudioAvailable = true; // Assume available until proven otherwise
  bool _isCheckingAudio = true; // Loading state
  late TextEditingController _transcriptController;
  
  // Playback progress
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  
  @override
  void initState() {
    super.initState();
    _checkAudioAvailability();
    _transcriptController = TextEditingController(
      text: widget.recording.transcript ?? '',
    );
    
    // Debug: Print segment info
    print('Total segments: ${widget.recording.transcriptSegments.length}');
    if (widget.recording.transcriptSegments.isNotEmpty) {
      print('First segment: ${widget.recording.transcriptSegments.first.text} (${widget.recording.transcriptSegments.first.startTimeMs}-${widget.recording.transcriptSegments.first.endTimeMs}ms)');
      print('Last segment: ${widget.recording.transcriptSegments.last.text} (${widget.recording.transcriptSegments.last.startTimeMs}-${widget.recording.transcriptSegments.last.endTimeMs}ms)');
    }
  }
  
  Future<void> _checkAudioAvailability() async {
    if (widget.recording.filePath == null) {
      setState(() {
        _isAudioAvailable = false;
        _isCheckingAudio = false;
      });
      return;
    }
    
    try {
      // Try to initialize player and load the audio
      await _audioService.initPlayer();
      
      // Try to get audio duration - if this fails, audio is not available
      final duration = await _audioService.getAudioDuration(widget.recording.filePath!);
      
      if (duration != null) {
        // Audio is available
        setState(() {
          _isAudioAvailable = true;
          _isInitialized = true;
          _totalDuration = duration;
          _isCheckingAudio = false;
        });
      } else {
        // Could not load audio, fallback to recorded duration
        setState(() {
          _isAudioAvailable = false;
          _totalDuration = widget.recording.duration;
          _isCheckingAudio = false;
        });
      }
    } catch (e) {
      print('Error checking audio availability: $e');
      setState(() {
        _isAudioAvailable = false;
        _totalDuration = widget.recording.duration;
        _isCheckingAudio = false;
      });
    }
  }
  

  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _audioService.stopPlayback();
    _audioService.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MobileWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recording Details'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditTitleDialog,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareRecording,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Status - Compact
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recording.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(widget.recording.created),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(widget.recording.duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusChip(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Show loading indicator while checking audio
              if (_isCheckingAudio && widget.recording.filePath != null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              
              // Web Warning - Show before player when audio is available
              if (!_isCheckingAudio && _isAudioAvailable && kIsWeb && widget.recording.filePath != null)
                Card(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Note: Audio will not be available after page refresh due to browser restrictions. However, the transcript will remain available.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (!_isCheckingAudio && _isAudioAvailable && kIsWeb && widget.recording.filePath != null)
                const SizedBox(height: 8),
              
              // Audio Player - Show when available
              if (!_isCheckingAudio && _isAudioAvailable && widget.recording.filePath != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        // Playback controls - centered
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              iconSize: 28,
                              onPressed: _isInitialized ? _skipBackward : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              ),
                              iconSize: 56,
                              onPressed: _isInitialized ? _togglePlayback : null,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              iconSize: 28,
                              onPressed: _isInitialized ? _skipForward : null,
                            ),
                          ],
                        ),
                        // Slider with time labels
                        Row(
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: theme.textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Slider(
                                value: _currentPosition.inMilliseconds.toDouble().clamp(
                                  0.0,
                                  _totalDuration.inMilliseconds.toDouble() > 0
                                      ? _totalDuration.inMilliseconds.toDouble()
                                      : 1.0,
                                ),
                                max: _totalDuration.inMilliseconds.toDouble() > 0
                                    ? _totalDuration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  setState(() {
                                    _currentPosition = Duration(milliseconds: value.toInt());
                                  });
                                },
                                onChangeEnd: (value) {
                                  _audioService.seekTo(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Audio Unavailable Warning - Show when not available
              if (!_isCheckingAudio && !_isAudioAvailable && widget.recording.filePath != null)
                Card(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Audio Playback Unavailable',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The audio file is no longer available because the page was refreshed. The audio data was stored temporarily in browser memory and was lost on reload.\n\nThe transcript is still available below.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Live Scrolling Words (only during playback)
              if (_isPlaying && widget.recording.transcriptSegments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildLiveScrollingWords(theme),
                ),
              
              const SizedBox(height: 12),
              
              // Transcript header - compact
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transcript',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.recording.transcript != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copyTranscriptText,
                            tooltip: 'Copy Text',
                          ),
                          IconButton(
                            icon: Icon(_isEditingTranscript ? Icons.check : Icons.edit),
                            onPressed: () async {
                          if (_isEditingTranscript) {
                            // Get provider and find the recording
                            final provider = context.read<RecordingProvider>();
                            final recordings = provider.recordings;
                            final index = recordings.indexWhere((r) => r.id == widget.recording.id);
                            
                            if (index != -1) {
                              // Get the actual recording from provider
                              final recording = recordings[index];
                              
                              // Update transcript from edited segments
                              if (widget.recording.transcriptSegments.isNotEmpty) {
                                recording.transcript = widget.recording.transcriptSegments
                                    .map((s) => s.text)
                                    .join(' ');
                                recording.transcriptSegments = widget.recording.transcriptSegments;
                              } else {
                                recording.transcript = _transcriptController.text;
                              }
                              
                              recording.modified = DateTime.now();
                              
                              // Update in storage
                              await provider.updateRecording(index, recording);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transcript updated successfully'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                          
                          setState(() {
                            _isEditingTranscript = !_isEditingTranscript;
                          });
                        },
                        tooltip: _isEditingTranscript ? 'Save' : 'Edit',
                      ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              
              // Full Transcript
              if (widget.recording.transcript != null)
                _isEditingTranscript
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Edit individual words. Timestamps are preserved.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (widget.recording.transcriptSegments.isNotEmpty)
                                _buildEditableSegments(theme)
                              else
                                TextField(
                                  controller: _transcriptController,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Edit transcript...',
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      )
                    : widget.recording.transcriptSegments.isNotEmpty
                        ? _buildFullTranscript(theme)
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                widget.recording.transcript!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          )
              else if (widget.recording.status == RecordingStatus.processing)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Transcribing audio...'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No transcript available',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Live scrolling words display (3-4 words at a time)
  Widget _buildLiveScrollingWords(ThemeData theme) {
    final currentMs = _currentPosition.inMilliseconds;
    final segments = widget.recording.transcriptSegments;
    
    // Find active segment index
    int activeSegmentIndex = -1;
    for (int i = 0; i < segments.length; i++) {
      if (currentMs >= segments[i].startTimeMs && currentMs <= segments[i].endTimeMs) {
        activeSegmentIndex = i;
        break;
      }
    }
    
    if (activeSegmentIndex == -1) {
      return const SizedBox(height: 50);
    }
    
    // Get 3-4 words: 1 before, current, 2 after
    final startIndex = (activeSegmentIndex - 1).clamp(0, segments.length - 1);
    final endIndex = (activeSegmentIndex + 2).clamp(0, segments.length - 1);
    
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int i = startIndex; i <= endIndex; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: i == activeSegmentIndex
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                    fontSize: i == activeSegmentIndex ? 24 : 18,
                    fontWeight: i == activeSegmentIndex ? FontWeight.bold : FontWeight.normal,
                  ),
                  child: Text(segments[i].text),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Full transcript with wrap layout
  Widget _buildFullTranscript(ThemeData theme) {
    final currentMs = _currentPosition.inMilliseconds;
    final segments = widget.recording.transcriptSegments;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: segments.map((segment) {
          final isActive = _isPlaying && 
              currentMs >= segment.startTimeMs && 
              currentMs <= segment.endTimeMs;
          
          return Text(
            '${segment.text} ',
            style: TextStyle(
              color: isActive 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.normal,
              backgroundColor: isActive 
                ? theme.colorScheme.primary.withOpacity(0.1)
                : null,
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildEditableSegments(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.recording.transcriptSegments.asMap().entries.map((entry) {
        final index = entry.key;
        final segment = entry.value;
        
        return IntrinsicWidth(
          child: TextField(
            controller: TextEditingController(text: segment.text),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
            onChanged: (value) {
              // Update the segment text in real-time
              widget.recording.transcriptSegments[index] = TranscriptSegment(
                text: value,
                startTimeMs: segment.startTimeMs,
                endTimeMs: segment.endTimeMs,
              );
            },
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildStatusChip() {
    final theme = Theme.of(context);
    Color color;
    String label;
    
    switch (widget.recording.status) {
      case RecordingStatus.recording:
        color = recordingColor;
        label = 'Recording';
        break;
      case RecordingStatus.uploading:
        color = theme.colorScheme.tertiary;
        label = 'Uploading';
        break;
      case RecordingStatus.processing:
        color = theme.colorScheme.primary;
        label = 'Processing';
        break;
      case RecordingStatus.completed:
        color = Colors.green; // Keep green for success
        label = 'Completed';
        break;
      case RecordingStatus.failed:
        color = recordingColor;
        label = 'Failed';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioService.pausePlayback();
      _positionSubscription?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (widget.recording.filePath != null) {
        final success = await _audioService.playAudio(
          widget.recording.filePath!,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _currentPosition = Duration.zero;
              });
              _positionSubscription?.cancel();
            }
          },
        );
        if (success) {
          setState(() {
            _isPlaying = true;
          });
          
          // Cancel any existing subscription
          await _positionSubscription?.cancel();
          
          // Subscribe to playback position updates
          _positionSubscription = _audioService.playbackStream?.listen(
            (position) {
              if (mounted) {
                setState(() {
                  _currentPosition = position;
                });
              }
            },
            onError: (error) {
              print('Playback stream error: $error');
            },
            onDone: () {
              print('Playback finished');
            },
          );
        } else {
          print('Failed to start playback');
        }
      }
    }
  }
  
  Future<void> _skipForward() async {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    if (newPosition < _totalDuration) {
      setState(() {
        _currentPosition = newPosition;
      });
      await _audioService.seekTo(newPosition);
    }
  }
  
  Future<void> _skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    setState(() {
      _currentPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    });
    await _audioService.seekTo(_currentPosition);
  }
  
  void _showEditTitleDialog() {
    final controller = TextEditingController(text: widget.recording.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Recording Title',
            border: OutlineInputBorder(),
          ),
          autofocus: !kIsWeb, // Auto-focus on mobile/desktop, not on web to avoid pointer issues
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != widget.recording.title) {
                try {
                  // Find the recording index in the provider
                  final provider = Provider.of<RecordingProvider>(context, listen: false);
                  final index = provider.recordings.indexWhere((r) => r.id == widget.recording.id);
                  
                  if (index != -1) {
                    await provider.updateRecordingTitle(index, newTitle);
                    if (mounted) {
                      // Update the local widget's recording title for immediate UI update
                      setState(() {
                        widget.recording.title = newTitle;
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title updated successfully')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating title: $e')),
                    );
                  }
                }
              }
              controller.dispose();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _shareRecording() async {
    if (widget.recording.transcript == null || widget.recording.transcript!.isEmpty) {
      // If no transcript, share audio file
      if (widget.recording.filePath != null) {
        try {
          if (kIsWeb) {
            // Web: Can't share files easily, just show message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio sharing not available on web. Please use the transcript.')),
              );
            }
          } else {
            // Mobile: Share audio file
            if (await platform.fileExists(widget.recording.filePath!)) {
              await Share.shareXFiles(
                [XFile(widget.recording.filePath!)],
                text: widget.recording.title,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error sharing: $e')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to share')),
          );
        }
      }
      return;
    }
    
    // Show share options dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Transcript'),
        content: const Text('How would you like to share the transcript?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _shareTextOnly();
            },
            child: const Text('Text Only'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareWithTimestamps();
            },
            child: const Text('With Timestamps'),
          ),
        ],
      ),
    );
  }
  
  void _shareTextOnly() async {
    try {
      final transcript = widget.recording.transcript ?? '';
      if (transcript.isNotEmpty) {
        await Share.share(
          '${widget.recording.title}\n\n$transcript',
          subject: widget.recording.title,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }
  
  void _shareWithTimestamps() async {
    try {
      if (widget.recording.transcriptSegments.isEmpty) {
        // No segments, share text only
        _shareTextOnly();
        return;
      }
      
      // Build formatted transcript with timestamps
      final buffer = StringBuffer();
      buffer.writeln(widget.recording.title);
      buffer.writeln();
      
      for (final segment in widget.recording.transcriptSegments) {
        final timestamp = _formatTimestamp(segment.startTimeMs);
        buffer.writeln('[$timestamp] ${segment.text}');
      }
      
      await Share.share(
        buffer.toString(),
        subject: widget.recording.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }
  
  void _copyTranscriptText() async {
    try {
      final transcript = widget.recording.transcript ?? '';
      if (transcript.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: transcript));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcript copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error copying: $e')),
        );
      }
    }
  }

  String _formatTimestamp(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
