import 'dart:io';

/// Formats the Dart file at the given [filePath].
Future<void> formatDartFile(String filePath) async {
  await Process.run(
    'dart',
    ['format', filePath],
    runInShell: true,
  );
}
