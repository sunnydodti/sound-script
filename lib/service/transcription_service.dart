import 'dart:async';

class TranscriptionService {
  // Mock transcription - simulates API call
  Future<String> transcribeAudio(String audioPath) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return mock transcript
    return _getMockTranscript();
  }
  
  String _getMockTranscript() {
    final List<String> mockTranscripts = [
      "This is a sample transcription of your audio recording. The speech-to-text API would normally process the audio file and return the transcribed text here.",
      "Hello, this is a test recording. The transcription service is working correctly and converting speech to text in real-time.",
      "Meeting notes: Discussed project timeline and deliverables. Action items include completing the documentation by Friday and scheduling a follow-up meeting next week.",
      "Reminder to buy groceries: milk, bread, eggs, and coffee. Also need to pick up the dry cleaning before 6 PM today.",
      "Voice memo: Had a great idea for the new feature. Users should be able to search through their transcripts and edit them inline for better accuracy.",
      "Quick note: The quarterly report shows a 15% increase in user engagement. Marketing campaign was successful and we should continue with similar strategies.",
      "Personal diary entry: Today was a productive day. Completed all tasks on the to-do list and even had time for a walk in the park.",
      "Lecture notes: Professor discussed quantum mechanics fundamentals including wave-particle duality, Heisenberg uncertainty principle, and Schrodinger equation applications.",
    ];
    
    // Return random transcript
    return mockTranscripts[DateTime.now().millisecondsSinceEpoch % mockTranscripts.length];
  }
  
  // Simulate streaming transcription (bonus feature)
  Stream<String> transcribeAudioStreaming(String audioPath) async* {
    final fullTranscript = _getMockTranscript();
    final words = fullTranscript.split(' ');
    
    String partial = '';
    for (int i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      partial += (i == 0 ? '' : ' ') + words[i];
      yield partial;
    }
  }
}
