import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/provider/recording_provider.dart';
import '../models/recording.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/mobile_wrapper.dart';
import '../widgets/my_appbar.dart';
import '../widgets/recording_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    RecordingProvider recordingProvider = context.watch<RecordingProvider>();
    return Column(
      children: [
        // Expanded(child: Text(recordingProvider.recordings.length.toString())),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => recordingProvider.loadRecordings(),
            child: ListView.builder(
              itemCount: recordingProvider.recordings.length,
              itemBuilder: (context, index) {
                Recording recording = recordingProvider.recordings[index];
                return RecordingTile(recording: recording);
              },
            ),
          ),
        ),
      ],
    );
  }
}
