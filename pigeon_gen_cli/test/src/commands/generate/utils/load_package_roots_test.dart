import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/utils/load_package_roots.dart';
import 'package:test/test.dart';

// TODO(matiasleyba): fix or find a better way to handle flaky tests,
// randomize order: 683288169
void main() {
  group('loadPackageRoots', () {
    test('throws when .dart_tool/package_config.json is missing', () async {
      final originalCwd = Directory.current.path;
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test',
      );
      addTearDown(() async {
        Directory.current = originalCwd;
        await tempDir.delete(recursive: true);
      });

      tempDir.createSync(recursive: true);

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
    });

    test(
      'returns correct map for absolute and relative rootUri entries',
      () async {
        final originalCwd = Directory.current.path;
        final cwd = await Directory.systemTemp.createTemp(
          'pigeon_gen_cli_test',
        );
        final absDir = await Directory.systemTemp.createTemp(
          'pigeon_gen_cli_abst',
        );

        absDir.createSync(recursive: true);
        cwd.createSync(recursive: true);

        addTearDown(() async {
          Directory.current = originalCwd;
          await cwd.delete(recursive: true);
          await absDir.delete(recursive: true);
        });

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
      },
    );
  });
}
