import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/recording.dart';
import '../pages/details_page.dart';
import '../data/provider/recording_provider.dart';

class RecordingTile extends StatelessWidget {
  final Recording recording;
  const RecordingTile({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.mic,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
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
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: _buildStatusIcon(recording.status),
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
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToRecordingScreen(context),
      ),
    );
  }

  Widget _buildStatusIcon(RecordingStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case RecordingStatus.recording:
        icon = Icons.fiber_manual_record;
        color = Colors.red;
        break;
      case RecordingStatus.uploading:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        break;
      case RecordingStatus.processing:
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case RecordingStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case RecordingStatus.failed:
        icon = Icons.error;
        color = Colors.red;
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}