// Extracts the content of the pigeon file, retaining only the import for
// 'package:pigeon/pigeon.dart' and removing all other imports.
String extractPigeonFileContent(String source) {
  final importRegex = RegExp(
    r'''^\s*import\s+(?:["']{1,3})([^"']+)(?:["']{1,3})''',
    multiLine: true,
  );
  final result = StringBuffer();
  final lines = source.split('\n');

  for (final line in lines) {
    final match = importRegex.firstMatch(line);
    if (match != null) {
      final uri = match.group(1);
      if (uri == 'package:pigeon/pigeon.dart') {
        result.writeln(line);
      }
    } else {
      result.writeln(line);
    }
  }
  return result.toString();
}
