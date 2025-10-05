// Web platform implementation using dart:html
import 'dart:html' as html;
import 'dart:typed_data';

String? createBlobUrl(List<int> bytes) {
  try {
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    return html.Url.createObjectUrlFromBlob(blob);
  } catch (e) {
    print('Error creating blob URL: $e');
    return null;
  }
}

Future<List<int>> readFileBytes(String path) async {
  // On web, we don't read from file paths - bytes should be cached
  throw UnsupportedError('File reading not supported on web. Use cached bytes instead.');
}

Future<bool> fileExists(String path) async {
  // On web, blob URLs are always "available" when created
  // but we can't check file system
  return true;
}

Future<int> getFileSize(String path) async {
  // Can't determine size from blob URL on web
  return 0;
}

Future<void> deleteFile(String path) async {
  // On web, blob URLs are automatically cleaned up by the browser
  // Nothing to do here
}
