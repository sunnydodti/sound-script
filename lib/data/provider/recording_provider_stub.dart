// Stub implementation for platforms that don't have conditional imports resolved
// This file should never be actually used at runtime

String? createBlobUrl(List<int> bytes) {
  throw UnsupportedError('Platform not supported');
}

Future<List<int>> readFileBytes(String path) {
  throw UnsupportedError('Platform not supported');
}

Future<bool> fileExists(String path) {
  throw UnsupportedError('Platform not supported');
}

Future<int> getFileSize(String path) {
  throw UnsupportedError('Platform not supported');
}

Future<void> deleteFile(String path) async {
  throw UnsupportedError('Platform not supported');
}
