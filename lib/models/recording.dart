import 'transcript_segment.dart';

class Recording {

  int id = DateTime.now().millisecondsSinceEpoch;

  String title = 'Recording_${DateTime.now().toIso8601String()}';
  String? filePath;
  String? transcript;
  List<TranscriptSegment> transcriptSegments = []; // Timestamped segments
  Duration duration = Duration.zero;
  
  DateTime created = DateTime.now();
  DateTime modified = DateTime.now();
  
  RecordingStatus status = RecordingStatus.recording;
  // tomap and from map methods
  
  Recording();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (filePath != null)  'filePath': filePath,
      if (transcript != null)  'transcript': transcript,
      'transcriptSegments': transcriptSegments.map((seg) => seg.toMap()).toList(),
      'duration': duration.inMilliseconds,
      'created': created.toIso8601String(),
      'modified': modified.toIso8601String(),
      'status': status.index,
    };
  }

  Recording.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    title = map['title'] ?? 'Recording_${DateTime.now().toIso8601String()}';
    filePath = map['filePath'];
    transcript = map['transcript'];
    transcriptSegments = (map['transcriptSegments'] as List?)
        ?.map((item) => TranscriptSegment.fromMap(Map<String, dynamic>.from(item)))
        .toList() ?? [];
    duration = Duration(milliseconds: map['duration'] ?? 0);
    created = DateTime.parse(map['created']);
    modified = DateTime.parse(map['modified']);
    status = RecordingStatus.values[map['status']];
  }

}

class RecordingHistory {
  List<Recording> recordings = [];

  RecordingHistory({required this.recordings});

  factory RecordingHistory.fromMap(Map<dynamic, dynamic> map) {
    return RecordingHistory(
      recordings: (map['recordings'] as List)
          .map((item) => Recording.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recordings': recordings.map((url) => url.toMap()).toList(),
    };
  }
}


enum RecordingStatus { recording, uploading, processing, completed, failed }