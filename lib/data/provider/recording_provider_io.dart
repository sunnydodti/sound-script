// Mobile/Desktop platform implementation using dart:io
import 'dart:io';

String? createBlobUrl(List<int> bytes) {
  // Not needed on mobile - we use file paths
  throw UnsupportedError('Blob URLs are not supported on mobile platforms');
}

Future<List<int>> readFileBytes(String path) async {
  try {
    final file = File(path);
    return await file.readAsBytes();
  } catch (e) {
    print('Error reading file bytes: $e');
    throw Exception('Failed to read file: $e');
  }
}

Future<bool> fileExists(String path) async {
  try {
    final file = File(path);
    return await file.exists();
  } catch (e) {
    print('Error checking file existence: $e');
    return false;
  }
}

Future<int> getFileSize(String path) async {
  try {
    final file = File(path);
    return await file.length();
  } catch (e) {
    print('Error getting file size: $e');
    return 0;
  }
}

Future<void> deleteFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    print('Error deleting file: $e');
  }
}
