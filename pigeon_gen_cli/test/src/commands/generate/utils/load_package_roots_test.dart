import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/generate/utils/load_package_roots.dart';
import 'package:test/test.dart';

void main() {
  group('loadPackageRoots', () {
    test('throws when .dart_tool/package_config.json is missing', () async {
      final originalCwd = Directory.current.path;
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      try {
        Directory.current = tempDir.path;

        expect(
          loadPackageRoots,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('package_config.json not found'),
            ),
          ),
        );
      } finally {
        Directory.current = originalCwd;
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'returns correct map for absolute and relative rootUri entries',
      () async {
        final originalCwd = Directory.current.path;
        final cwd = await Directory.systemTemp.createTemp(
          'pigeon_gen_cli_test_',
        );
        final absDir = await Directory.systemTemp.createTemp(
          'pigeon_gen_cli_abs_',
        );

        try {
          // Prepare fake package_config.json
          final dotDartTool = Directory(p.join(cwd.path, '.dart_tool'))
            ..createSync(recursive: true);
          final configFile = File(
            p.join(dotDartTool.path, 'package_config.json'),
          );

          final absoluteUri = Uri.file(absDir.path).toString();
          const relativeUri = '../../relative_root';

          final json =
              '''
{
  "packages": [
    { "name": "absolute_pkg", "rootUri": "$absoluteUri" },
    { "name": "relative_pkg", "rootUri": "$relativeUri" }
  ]
}
''';
          configFile.writeAsStringSync(json);

          Directory.current = cwd.path;

          final result = loadPackageRoots();

          expect(result.length, 2);
          expect(result['absolute_pkg'], absDir.path);
          expect(result['relative_pkg'], '../relative_root');
        } finally {
          Directory.current = originalCwd;
          await cwd.delete(recursive: true);
          await absDir.delete(recursive: true);
        }
      },
    );
  });
}
