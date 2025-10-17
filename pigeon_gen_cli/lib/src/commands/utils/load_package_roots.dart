// Ignore dynamic calls due to jsonDecode
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:path/path.dart' as p;

/// Loads the package roots from the package_config.json file.
Map<String, String> loadPackageRoots() {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw Exception('package_config.json not found. Run `flutter pub get`.');
  }

  final jsonMap = jsonDecode(configFile.readAsStringSync());
  final packages = <String, String>{};

  for (final pkg in jsonMap['packages'] as List<dynamic>) {
    final name = pkg['name'] as String;
    final rootUri = pkg['rootUri'] as String;
    final uri = Uri.parse(rootUri);

    String resolvedPath;
    if (uri.isAbsolute) {
      // e.g. file:///Users/.../.pub-cache/...
      resolvedPath = uri.toFilePath();
    } else {
      // relative path (e.g. ../../..)
      resolvedPath = p.normalize(
        p.join(configFile.parent.path, uri.toFilePath()),
      );
    }

    packages[name] = resolvedPath;
  }
  return packages;
}
