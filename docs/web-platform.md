# Web Platform Compatibility - SoundScript

## Overview
This document outlines all the changes made to ensure SoundScript works on both mobile (Android/iOS) and web platforms.

## Platform Detection

### PlatformUtils (`lib/utils/platform_utils.dart`)
Created a utility class for platform detection and feature availability:
- `isWeb`: Check if running on web
- `isMobile`: Check if running on mobile
- `supportsFileOperations`: Check if file operations are supported
- `hasFileSystem`: Check if local file system is available
- `supportsFileRecording`: Check if recording to file is supported

## Key Platform-Specific Implementations

### 1. Audio Service (`lib/service/audio_service.dart`)
**Web Adaptations:**
- Uses `Codec.opusWebM` for web recordings (instead of `Codec.aacADTS`)
- Recordings are stored in browser memory (not file system)
- Path is a simple identifier string on web (e.g., `recording_1234567.webm`)
- Permissions handled automatically by browser

**Code Example:**
```dart
if (kIsWeb) {
  // Web: Use browser memory
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  path = 'recording_$timestamp.webm';
  
  await _recorder!.startRecorder(
    toFile: path,
    codec: Codec.opusWebM,
    audioSource: AudioSource.microphone,
  );
} else {
  // Mobile: Use file system
  final dir = await getApplicationDocumentsDirectory();
  path = '${dir.path}/recording_$timestamp.aac';
  ...
}
```

### 2. Recording Provider (`lib/data/provider/recording_provider.dart`)
**Web Adaptations:**

#### File Deletion:
- On mobile: Deletes actual file from disk
- On web: Skips file deletion (browser handles cleanup)

```dart
if (recording.filePath != null && !kIsWeb) {
  final file = File(recording.filePath!);
  if (await file.exists()) {
    await file.delete();
  }
}
```

#### File Picker:
- Web: Uses file name as path identifier
- Mobile: Uses actual file system path
- Both: Validate file size (50 MB max) and extensions

```dart
if (kIsWeb) {
  filePath = fileName;
  duration = Duration.zero;
} else {
  final file = File(result.files.single.path!);
  filePath = file.path;
  duration = await _audioService.getAudioDuration(file.path);
}
```

### 3. Details Page (`lib/pages/details_page.dart`)
**Web Adaptations:**

#### File Sharing:
- Web: Shows message that audio sharing is not available
- Mobile: Shares audio file using native share sheet

```dart
if (kIsWeb) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Audio sharing not available on web. Please use the transcript.')),
  );
} else {
  final file = File(widget.recording.filePath!);
  await Share.shareXFiles([XFile(widget.recording.filePath!)], ...);
}
```

#### Transcript Sharing:
- Works on both platforms
- Options: Text only or with timestamps
- Uses native share on mobile, web share API on web

### 4. Record Page (`lib/pages/record_page.dart`)
**Web Adaptations:**

#### UI Disclaimers:
Added info boxes to inform users about platform limitations:

```dart
if (kIsWeb) {
  Container(
    child: Text(
      'Web version: File upload supported. For recording audio, please use the mobile app.',
    ),
  )
}
```

#### Feature Availability:
- Normal Recording: Mobile only (requires file system)
- Live Transcription: Mobile only (requires file system and continuous recording)
- File Upload: Both platforms ✓
- Transcription: Both platforms ✓ (via API)

## Features Support Matrix

| Feature | Mobile (Android/iOS) | Web |
|---------|---------------------|-----|
| Record Audio | ✅ Full support | ⚠️ Limited (browser memory) |
| Live Transcription | ✅ Supported | ⚠️ Limited |
| Upload Audio File | ✅ Supported | ✅ Supported |
| Transcribe via API | ✅ Supported | ✅ Supported |
| Play Audio | ✅ Full support | ✅ Supported |
| Edit Transcript | ✅ Supported | ✅ Supported |
| Share Audio File | ✅ Supported | ❌ Not available |
| Share Transcript | ✅ Supported | ✅ Supported |
| Copy Transcript | ✅ Supported | ✅ Supported |
| Search Recordings | ✅ Supported | ✅ Supported |
| Delete Recordings | ✅ Supported | ✅ Supported |
| Local Storage (Hive) | ✅ Supported | ✅ Supported (IndexedDB) |

## Dependencies

All dependencies are web-compatible:
- `flutter_sound`: ✅ Web support
- `hive_ce`: ✅ Web support (uses IndexedDB)
- `file_picker`: ✅ Web support
- `share_plus`: ✅ Web support (Web Share API)
- `speech_to_text`: ✅ Web support
- `url_launcher`: ✅ Web support
- `provider`: ✅ Platform agnostic
- `universal_html`: ✅ Web compatibility helper

## Build Configuration

### Web Build Command:
```bash
flutter build web --release
```

### Build Output:
- Files generated in `build/web/`
- Can be deployed to any static hosting (Firebase, GitHub Pages, Netlify, etc.)

## Known Limitations on Web

1. **Audio Recording**: Limited to browser capabilities, files stored in memory
2. **File Sharing**: Audio files cannot be shared (transcript sharing works)
3. **File System Access**: No direct file system access (uses browser storage)
4. **Permissions**: Handled by browser, may require HTTPS in production
5. **Audio Formats**: Limited to browser-supported codecs (WebM/Opus)

## Testing

### Local Web Testing:
```bash
flutter run -d chrome
```

### Production Web Testing:
- Deploy to HTTPS server
- Test microphone permissions
- Test file upload
- Test transcript sharing
- Test all CRUD operations

## Deployment Notes

1. **HTTPS Required**: Microphone access requires HTTPS in production
2. **CORS**: Ensure API endpoints have proper CORS headers
3. **PWA**: App is PWA-ready with `pwa_install` package
4. **Browser Support**: 
   - Chrome/Edge: Full support
   - Firefox: Full support
   - Safari: Limited (some audio codec issues)

## Future Enhancements

1. **Offline Support**: Implement service worker for offline functionality
2. **PWA Installation**: Add install prompts and app manifest
3. **File System API**: Use File System Access API when available
4. **WebRTC**: Explore WebRTC for better audio recording on web
5. **IndexedDB Optimization**: Optimize storage for large audio files

## Error Handling

All platform-specific code includes proper error handling:
```dart
try {
  if (kIsWeb) {
    // Web-specific code
  } else {
    // Mobile-specific code
  }
} catch (e) {
  print('Error: $e');
  // Show user-friendly message
}
```

## Security Considerations

1. **API Keys**: Ensure API keys are properly secured
2. **CORS**: Configure CORS for API endpoints
3. **HTTPS**: Always use HTTPS in production
4. **Permissions**: Handle browser permission denials gracefully
5. **File Size Limits**: Enforce on both client and server

## Performance Optimization

1. **Web**: 
   - Lazy load audio files
   - Use compressed audio formats
   - Optimize bundle size

2. **Mobile**:
   - Use native codecs
   - Efficient file I/O
   - Background processing for transcription

---

## Summary

The SoundScript app is now fully compatible with both mobile and web platforms, with appropriate fallbacks and user notifications for platform-specific limitations. The core functionality works across all platforms, with some advanced features (like native audio recording) limited to mobile for the best user experience.
