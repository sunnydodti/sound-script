import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recording.dart';
import '../service/audio_service.dart';

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
  late TextEditingController _transcriptController;
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
    _transcriptController = TextEditingController(
      text: widget.recording.transcript ?? '',
    );
  }
  
  Future<void> _initPlayer() async {
    await _audioService.initPlayer();
    setState(() {
      _isInitialized = true;
    });
  }
  
  @override
  void dispose() {
    _audioService.stopPlayback();
    _audioService.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recording.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: ${_formatDate(widget.recording.created)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    if (widget.recording.duration.inSeconds > 0)
                      Text(
                        'Duration: ${_formatDuration(widget.recording.duration)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildStatusChip(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Audio Player
            if (widget.recording.filePath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            iconSize: 48,
                            onPressed: _isInitialized ? _togglePlayback : null,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            iconSize: 48,
                            onPressed: _isInitialized && _isPlaying ? _stopPlayback : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Transcript
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transcript',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.recording.transcript != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditingTranscript = !_isEditingTranscript;
                        if (!_isEditingTranscript) {
                          // Save changes
                          widget.recording.transcript = _transcriptController.text;
                          widget.recording.modified = DateTime.now();
                        }
                      });
                    },
                    icon: Icon(_isEditingTranscript ? Icons.check : Icons.edit),
                    label: Text(_isEditingTranscript ? 'Save' : 'Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.recording.transcript != null
                    ? _isEditingTranscript
                        ? TextField(
                            controller: _transcriptController,
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Edit transcript...',
                            ),
                            style: theme.textTheme.bodyLarge,
                          )
                        : SelectableText(
                            widget.recording.transcript!,
                            style: theme.textTheme.bodyLarge,
                          )
                    : widget.recording.status == RecordingStatus.processing
                        ? const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Transcribing audio...'),
                              ],
                            ),
                          )
                        : Text(
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
    );
  }
  
  Widget _buildStatusChip() {
    final theme = Theme.of(context);
    Color color;
    String label;
    
    switch (widget.recording.status) {
      case RecordingStatus.recording:
        color = theme.colorScheme.error;
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
        color = theme.colorScheme.error;
        label = 'Failed';
        break;
    }
    
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioService.pausePlayback();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (widget.recording.filePath != null) {
        final success = await _audioService.playAudio(widget.recording.filePath!);
        if (success) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    }
  }
  
  Future<void> _stopPlayback() async {
    await _audioService.stopPlayback();
    setState(() {
      _isPlaying = false;
    });
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Update title logic would go here
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _shareRecording() async {
    try {
      if (widget.recording.transcript != null && widget.recording.transcript!.isNotEmpty) {
        // Share transcript text
        await Share.share(
          '${widget.recording.title}\n\n${widget.recording.transcript}',
          subject: widget.recording.title,
        );
      } else if (widget.recording.filePath != null) {
        // Share audio file
        final file = File(widget.recording.filePath!);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(widget.recording.filePath!)],
            text: widget.recording.title,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to share')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing: $e')),
      );
    }
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
