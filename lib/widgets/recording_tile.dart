import 'package:flutter/material.dart';

import '../models/recording.dart';

class RecordingTile extends StatelessWidget {
  final Recording recording;
  const RecordingTile({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(recording.title),
      onTap: navigateToRecordingScreen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: () {}, icon: Icon(Icons.edit)),
          IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
        ],
      )
    );
  }

  void navigateToRecordingScreen() {

  }
}