import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.mic,
                size: 64,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              'Sound Script',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Convert speech to text with ease',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Case Study Project',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Project Links
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Links',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.public),
                      title: const Text('Live Demo'),
                      subtitle: const Text('soundscript.persist.site'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://soundscript.persist.site'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('GitHub Pages'),
                      subtitle: const Text('sunnydodti.github.io/sound-script'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://sunnydodti.github.io/sound-script'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Source Code'),
                      subtitle: const Text('github.com/sunnydodti/sound-script'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://github.com/sunnydodti/sound-script'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Download'),
                      subtitle: const Text('Latest Release'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://github.com/sunnydodti/sound-script/releases/latest'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory),
                      title: const Text('All Releases'),
                      subtitle: const Text('View Release History'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://github.com/sunnydodti/sound-script/releases'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Developer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Developer',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: const Text(
                        'Sunny Dodti',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Software Developer'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.location_on, size: 20),
                      title: const Text('Mumbai, India'),
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.email, size: 20),
                      title: const Text('sunnydodti.dev@gmail.com'),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      dense: true,
                      onTap: () => _launchUrl('mailto:sunnydodti.dev@gmail.com'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Social Links
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Portfolio'),
                      subtitle: const Text('sunny.persist.site'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://sunny.persist.site'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('GitHub'),
                      subtitle: const Text('github.com/sunnydodti'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://github.com/sunnydodti'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: const Text('LinkedIn'),
                      subtitle: const Text('linkedin.com/in/sunnydodti'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _launchUrl('https://www.linkedin.com/in/sunnydodti'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Features
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Features',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.mic,
                      'Record Audio',
                      'Record high-quality audio with real-time duration tracking',
                    ),
                    _buildFeatureItem(
                      Icons.text_fields,
                      'Speech-to-Text',
                      'Automatically transcribe your recordings to text',
                    ),
                    _buildFeatureItem(
                      Icons.folder_open,
                      'Import Audio',
                      'Import existing audio files for transcription',
                    ),
                    _buildFeatureItem(
                      Icons.library_music,
                      'Audio Playback',
                      'Listen to your recordings with built-in player',
                    ),
                    _buildFeatureItem(
                      Icons.save,
                      'Local Storage',
                      'All recordings are saved locally on your device',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Copyright
            Text(
              'Sound Script | 2025 | Sunny Dodti',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
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
