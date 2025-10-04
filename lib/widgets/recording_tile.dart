import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/theme.dart';
import '../models/recording.dart';
import '../pages/details_page.dart';
import '../data/provider/recording_provider.dart';

class RecordingTile extends StatelessWidget {
  final Recording recording;
  final String searchQuery;
  
  const RecordingTile({
    super.key, 
    required this.recording,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    // Check where the match is
    final query = searchQuery.toLowerCase();
    final titleMatches = query.isNotEmpty && recording.title.toLowerCase().contains(query);
    final transcriptMatches = query.isNotEmpty && 
        (recording.transcript?.toLowerCase().contains(query) ?? false);
    
    return Dismissible(
      key: Key(recording.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: recordingColor,
        child: const Icon(
          Icons.delete, 
          color: Colors.white, 
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmationDialog(context);
      },
      onDismissed: (direction) {
        final index = recordingProvider.recordings.indexOf(recording);
        if (index != -1) {
          recordingProvider.deleteRecording(index);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${recording.title} deleted')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.mic,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: titleMatches
            ? _buildHighlightedText(recording.title, query, theme)
            : Text(
                recording.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(recording.created),
              style: theme.textTheme.bodySmall,
            ),
            if (recording.duration.inSeconds > 0)
              Text(
                'Duration: ${_formatDuration(recording.duration)}',
                style: theme.textTheme.bodySmall,
              ),
            if (transcriptMatches && !titleMatches)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildTranscriptPreview(recording.transcript!, query, theme),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: _buildStatusIcon(recording.status, theme),
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteConfirmation(context, recordingProvider);
            } else if (value == 'edit') {
              _showEditDialog(context, recordingProvider);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Title'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: recordingColor),
                  const SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: recordingColor)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToRecordingScreen(context),
      ),
      ),
    );
  }
  
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete "${recording.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: recordingColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildStatusIcon(RecordingStatus status, ThemeData theme) {
    IconData icon;
    Color color;
    
    switch (status) {
      case RecordingStatus.recording:
        icon = Icons.fiber_manual_record;
        color = recordingColor;
        break;
      case RecordingStatus.uploading:
        icon = Icons.cloud_upload;
        color = theme.colorScheme.tertiary;
        break;
      case RecordingStatus.processing:
        icon = Icons.hourglass_empty;
        color = theme.colorScheme.primary;
        break;
      case RecordingStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green; // Keep green as it's universally recognized for success
        break;
      case RecordingStatus.failed:
        icon = Icons.error;
        color = recordingColor;
        break;
    }
    
    return Icon(icon, color: color);
  }

  void _navigateToRecordingScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(recording: recording),
      ),
    );
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
  
  void _showEditDialog(BuildContext context, RecordingProvider provider) {
    final controller = TextEditingController(text: recording.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Recording Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final index = provider.recordings.indexOf(recording);
              if (index != -1 && controller.text.isNotEmpty) {
                provider.updateRecordingTitle(index, controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation(BuildContext context, RecordingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete "${recording.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final index = provider.recordings.indexOf(recording);
              if (index != -1) {
                provider.deleteRecording(index);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: recordingColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHighlightedText(String text, String query, ThemeData theme) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ));
      
      start = index + query.length;
    }
    
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodyLarge,
        children: spans,
      ),
    );
  }
  
  Widget _buildTranscriptPreview(String transcript, String query, ThemeData theme) {
    final lowerTranscript = transcript.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerTranscript.indexOf(lowerQuery);
    
    if (index == -1) return const SizedBox.shrink();
    
    // Extract context around the match (50 chars before and after)
    final start = (index - 50).clamp(0, transcript.length);
    final end = (index + query.length + 50).clamp(0, transcript.length);
    
    String preview = transcript.substring(start, end);
    if (start > 0) preview = '...$preview';
    if (end < transcript.length) preview = '$preview...';
    
    // Find the query position in the preview
    final previewLower = preview.toLowerCase();
    final queryIndex = previewLower.indexOf(lowerQuery);
    
    final spans = <TextSpan>[];
    if (queryIndex != -1) {
      // Text before match
      if (queryIndex > 0) {
        spans.add(TextSpan(text: preview.substring(0, queryIndex)));
      }
      
      // Highlighted match
      spans.add(TextSpan(
        text: preview.substring(queryIndex, queryIndex + query.length),
        style: TextStyle(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ));
      
      // Text after match
      if (queryIndex + query.length < preview.length) {
        spans.add(TextSpan(
          text: preview.substring(queryIndex + query.length),
        ));
      }
    } else {
      spans.add(TextSpan(text: preview));
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
          children: spans,
        ),
      ),
    );
  }
}