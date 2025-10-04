import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../../models/recording.dart';
import '../constants.dart';

class RecordingProvider with ChangeNotifier {
  RecordingProvider() {
    loadRecordings();
  }

  final List<Recording> _recordings = [];

  List<Recording> get recordings => List.unmodifiable(_recordings);

  Future<void> loadRecordings() async {
    final box = Hive.box(Constants.box);
    _recordings.clear();
    final recordingHistoryMap =
        box.get(Constants.recordingHistoryKey, defaultValue: {
      'recordings': [],
    });
    final recordingHistory = RecordingHistory.fromMap(
        Map<String, dynamic>.from(recordingHistoryMap));
    _recordings.addAll(recordingHistory.recordings);
    _recordings.addAll(getMockRecordings());
    notifyListeners();
  }

  Future<void> addRecording(Recording recording) async {
    final box = Hive.box(Constants.box);
    _recordings.add(recording);

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  Future<void> deleteUrl(int index) async {
    final box = Hive.box(Constants.box);
    _recordings.removeAt(index);

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  static Future<void> addNewUrl(Recording url) async {
    final box = Hive.box(Constants.box);
    final recordingHistoryMap =
        box.get(Constants.recordingHistoryKey, defaultValue: {
      'recordings': [],
    });
    final recordingHistory = RecordingHistory.fromMap(
        Map<String, dynamic>.from(recordingHistoryMap));
    recordingHistory.recordings.add(url);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
  }

  // update
  Future<void> updateRecording(int index, Recording recording) async {
    final box = Hive.box(Constants.box);
    _recordings[index] = recording;

    final recordingHistory = RecordingHistory(recordings: _recordings);
    await box.put(Constants.recordingHistoryKey, recordingHistory.toMap());
    notifyListeners();
  }

  List<Recording> getMockRecordings() {
    return [
      Recording(),
      Recording(),
      Recording(),
      Recording(),
      Recording(),
    ];
  }
}
