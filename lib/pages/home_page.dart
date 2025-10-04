import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/provider/recording_provider.dart';
import '../models/recording.dart';
import '../widgets/recording_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    RecordingProvider recordingProvider = context.watch<RecordingProvider>();
    
    // Filter recordings based on search query
    final filteredRecordings = recordingProvider.recordings.where((recording) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return recording.title.toLowerCase().contains(query) ||
             (recording.transcript?.toLowerCase().contains(query) ?? false);
    }).toList();
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search recordings...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Recordings list
        Expanded(
          child: filteredRecordings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.mic_none : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No recordings yet\nTap the Record tab to start'
                            : 'No recordings found',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => recordingProvider.loadRecordings(),
                  child: ListView.builder(
                    itemCount: filteredRecordings.length,
                    itemBuilder: (context, index) {
                      Recording recording = filteredRecordings[index];
                      return RecordingTile(
                        recording: recording,
                        searchQuery: _searchQuery,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
