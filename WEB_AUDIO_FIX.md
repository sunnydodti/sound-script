# Web Audio Recording Fix

## Problem
The flutter_sound_web package was throwing an assertion error:
```
Assertion failed: slotno == _slots.length is not true
NoSuchMethodError: tried to call a non-function, such as null: 'dart.global.newRecorderInstance'
```

This error occurred because:
1. Multiple `FlutterSoundRecorder()` instances were being created
2. flutter_sound_web maintains an internal **global** slot manager that breaks when multiple recorder instances exist
3. On hot reload/restart, the Dart singleton persists but the JavaScript context resets, causing initialization failures
4. Failed initialization attempts would trigger cleanup that created **new** recorder instances, causing the slot error

## Root Cause Analysis

### Primary Issue
In `lib/service/audio_service.dart`, the cleanup logic after failed initialization was creating new recorder instances:

```dart
// OLD CODE - BROKEN
try {
  _recorder ??= FlutterSoundRecorder();
  await _recorder!.openRecorder();
} catch (e) {
  await resetRecorder(); // <- This sets _recorder = null
  return false;
}

// On retry, _recorder is null, so ??= creates ANOTHER instance!
_recorder ??= FlutterSoundRecorder(); // <- SECOND INSTANCE = SLOT ERROR
```

### Secondary Issue  
Hot reload/restart creates a Dart/JavaScript state mismatch:
- **Dart singleton persists** across hot reloads (with stale recorder reference)
- **JavaScript context resets**, making `dart.global.newRecorderInstance` null
- Retry attempts create multiple recorder instances in the reset JS context

## Solution
**Fail-fast pattern with retry prevention:**

### 1. Track failure state
```dart
bool _recorderCreationFailed = false;
```

### 2. Prevent multiple creation attempts
```dart
// If creation has failed before, don't try again
if (_recorderCreationFailed) {
  print('⚠️ Recorder initialization previously failed. Please reload the page.');
  return false;
}
```

### 3. Single instance creation (no ??= operator)
```dart
try {
  // Create recorder instance - this should only happen ONCE per app lifecycle
  _recorder = FlutterSoundRecorder();
  await _recorder!.openRecorder();
  _isRecorderInitialized = true;
  return true;
} catch (e) {
  // Mark as failed to prevent retry (which would create another instance)
  _recorderCreationFailed = true;
  _isRecorderInitialized = false;
  
  // Keep _recorder object to block future creation attempts
  return false;
}
```

### 4. Detect bad state from hot reload
```dart
// If recorder exists but isn't initialized, something went wrong
if (_recorder != null && !_isRecorderInitialized) {
  print('⚠️ Recorder in bad state. Please reload the page.');
  _recorderCreationFailed = true;
  return false;
}
```

## Key Changes

### Before
- AudioService singleton ✓
- FlutterSoundRecorder created multiple times on retry ✗
- Cleanup logic caused new instance creation ✗
- No protection against hot reload issues ✗

### After
- AudioService singleton ✓
- FlutterSoundRecorder created exactly once ✓
- No cleanup that creates new instances ✓
- Fail-fast with clear user guidance ✓
- Hot reload detection ✓

## Testing

### First Launch (Fresh Page Load)
Run the app on Chrome:
```bash
flutter run -d chrome
```

The recorder should initialize successfully on first try. You'll see:
```
🎤 Creating FlutterSoundRecorder instance...
🎤 Opening recorder...
✅ Recorder initialized successfully
```

### After Hot Reload/Restart
If you see initialization errors, you'll get clear guidance:
```
⚠️ Recorder initialization previously failed. Please reload the page.
```

**Solution:** Press F5 or Ctrl+R in Chrome to fully reload the page. This resets the JavaScript context.

## Platform Compatibility
✅ Web (Chrome, Firefox, Safari)
✅ Android
✅ iOS
✅ Windows
✅ macOS
✅ Linux

## Known Limitations

### flutter_sound_web Package Issues
- **Global slot manager** persists across Dart hot reloads but not JS context reloads
- Creating multiple `FlutterSoundRecorder` instances breaks the slot manager
- No built-in recovery from failed initialization

### Workarounds Implemented
- **Fail-fast strategy**: Don't retry after failure (prevents multiple instances)
- **User guidance**: Clear messages to reload page when initialization fails
- **State tracking**: Prevent creation attempts after failure

### Required User Actions
- **Full page reload (F5)** required after hot reload if recorder fails to initialize
- **Microphone permissions** must be granted by user
- **HTTPS or localhost** required for microphone access

### Web Platform Constraints
- Recording quality depends on browser's MediaRecorder API
- Audio format support varies by browser
- Some browsers have stricter permission policies

## Related Files
- `lib/service/audio_service.dart` - Singleton audio service with reusable recorder/player
- `lib/data/provider/recording_provider.dart` - Uses AudioService singleton
- `lib/pages/details_page.dart` - Uses AudioService singleton
