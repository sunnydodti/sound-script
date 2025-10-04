class TranscriptSegment {
  final String text;
  final int startTimeMs; // Start time in milliseconds
  final int endTimeMs; // End time in milliseconds
  
  TranscriptSegment({
    required this.text,
    required this.startTimeMs,
    required this.endTimeMs,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
    };
  }
  
  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      text: map['text'] ?? '',
      startTimeMs: map['startTimeMs'] ?? 0,
      endTimeMs: map['endTimeMs'] ?? 0,
    );
  }
  
  // Get duration of this segment
  Duration get duration => Duration(milliseconds: endTimeMs - startTimeMs);
  
  // Get start time as Duration
  Duration get startTime => Duration(milliseconds: startTimeMs);
  
  // Get end time as Duration
  Duration get endTime => Duration(milliseconds: endTimeMs);
}
