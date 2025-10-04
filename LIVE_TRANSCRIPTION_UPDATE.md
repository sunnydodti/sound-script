# Live Transcription Updates

## Changes Made

### 1. Fixed Live Transcription Pausing Issue

**Problem**: Live transcription stopped recognizing speech after pauses.

**Solution**: Added continuous listening parameters to `speech_to_text`:
```dart
await _speechToText.listen(
  onResult: (result) { ... },
  listenFor: const Duration(minutes: 30),      // Allow 30-minute sessions
  pauseFor: const Duration(seconds: 5),        // Wait 5 seconds after pause
  partialResults: true,                        // Show results immediately
  cancelOnError: true,
  listenMode: stt.ListenMode.confirmation,     // Continue after pauses
);
```

**Key Parameters**:
- `listenFor`: Maximum listening duration (30 minutes)
- `pauseFor`: How long to wait before finalizing a phrase (5 seconds)
- `partialResults`: Display results as you speak
- `listenMode: confirmation`: Keeps listening after pauses instead of stopping

### 2. Added Save Options After Live Recording

**Feature**: When user clicks "Save Transcription", they now see a dialog with 2 options:

#### Option 1: Save As-Is
- **Icon**: Save icon
- **Benefits**:
  - Uses live transcription (instant)
  - No waiting time
  - No internet required
- **Limitations**:
  - May be less accurate than server transcription
  - Approximate word timestamps (evenly distributed)

#### Option 2: Server Transcription
- **Icon**: Cloud upload icon
- **Benefits**:
  - High accuracy transcription (AssemblyAI)
  - Precise word-level timestamps
  - Better punctuation and formatting
- **Limitations**:
  - Takes a few moments to process
  - Requires internet connection
  - Uses API quota

### 3. New Method in RecordingProvider

Added `saveLiveRecordingForServerTranscription()` method:
- Saves the audio file
- Sets status to `uploading`
- Triggers server transcription process
- Sets as `currentRecording` for transcription flow

## User Flow

### Before Changes
1. Start live recording
2. Stop recording
3. Click "Save Transcription"
4. Recording saved with live transcript (no choice)

### After Changes
1. Start live recording
2. Stop recording
3. Click "Save Transcription"
4. **Dialog appears with 2 options**:
   - **Save As-Is**: Instant save with live transcript
   - **Server Transcription**: Send to server for better accuracy
5. Recording saved based on user choice

## Technical Details

### Live Transcription Accuracy
- Uses device's native speech recognition
- Accuracy varies by:
  - Device capabilities
  - Microphone quality
  - Background noise
  - Speech clarity
  - Language/accent

### Server Transcription Accuracy
- Uses AssemblyAI API
- Professional-grade accuracy (~95%+)
- Better handling of:
  - Multiple speakers
  - Technical terms
  - Background noise
  - Accents

### Timestamp Comparison

**Live Transcription**:
```dart
// Evenly distributed across phrase duration
msPerWord = phraseDuration / numberOfWords
```

**Server Transcription**:
```dart
// Actual precise timestamps from API
{
  "text": "hello",
  "start": 0,
  "end": 500
}
```

## UI Changes

### Dialog Design
- Clean, modern Material 3 design
- Two bordered option cards
- Icons for visual clarity
- Bullet-point feature lists
- Cancel button for backing out

### After Selection
- Shows snackbar confirming action
- "View Transcription" button appears
- Can dismiss or view immediately
- Same UX as before, just with choice

## Testing Recommendations

1. **Test continuous listening**:
   - Speak, pause 2-3 seconds, continue speaking
   - Verify transcription continues after pauses

2. **Test Save As-Is**:
   - Record with live mode
   - Choose "Save As-Is"
   - Verify instant save with live transcript
   - Check word highlighting during playback

3. **Test Server Transcription**:
   - Record with live mode
   - Choose "Server Transcription"
   - Verify progress indicator shows
   - Check final transcript accuracy
   - Verify precise word timestamps during playback

4. **Compare accuracy**:
   - Same audio with both options
   - Compare transcript quality
   - Compare playback synchronization

## Benefits

1. **User Control**: Users choose accuracy vs. speed
2. **Flexibility**: Works offline (Save As-Is) or online (Server)
3. **Transparency**: Clear explanation of each option's pros/cons
4. **Better UX**: Continuous listening eliminates frustration with pauses
