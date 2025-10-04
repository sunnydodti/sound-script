import 'package:flutter/material.dart';

class OnboardingHelper {
  static void showRecordingHint(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('Quick Tips'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TipItem(
                icon: Icons.mic,
                title: 'Record Audio',
                description: 'Tap "Start Recording" to begin. Speak clearly for best results.',
              ),
              TipItem(
                icon: Icons.folder_open,
                title: 'Import Files',
                description: 'Choose an existing audio file to transcribe.',
              ),
              TipItem(
                icon: Icons.text_fields,
                title: 'View Transcript',
                description: 'Tap any recording from the Home tab to view details and transcript.',
              ),
              TipItem(
                icon: Icons.edit,
                title: 'Edit & Share',
                description: 'Edit transcripts or share them directly from the details page.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class TipItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  
  const TipItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
