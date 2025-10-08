import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/generate/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('getPackageNameByPath', () {
    test('returns the parent package name', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      // Ensure parent_package and child_package directories exist
      final parentPackageDir = Directory(
        p.join(tempDir.path, 'parent_package'),
      );
      await parentPackageDir.create(recursive: true);
      final childPackageDir = Directory(
        p.join(parentPackageDir.path, 'child_package'),
      );
      await childPackageDir.create(recursive: true);

      File(
        p.join(parentPackageDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('''
name: my_package
version: 1.0.0
''');
      final file = File(
        p.join(childPackageDir.path, 'file.dart'),
      )..writeAsStringSync('some file content');
      Directory.current = tempDir.path;
      final parentPackageName = getPackageNameByPath(file.path);
      expect(parentPackageName, 'my_package');

      await tempDir.delete(recursive: true);
    });
  });
  group('getCurrentPackageName', () {
    test('returns the current package name', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('''
name: my_package
version: 1.0.0

dependencies:
  my_package: ^1.0.0
''');
      Directory.current = tempDir.path;
      final currentPackageName = getCurrentPackageName();
      expect(currentPackageName, 'my_package');

      await tempDir.delete(recursive: true);
    });

    test('throws an error if the pubspec.yaml is not found', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      Directory.current = tempDir.path;
      expect(
        getCurrentPackageName,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('pubspec.yaml not found in current directory'),
          ),
        ),
      );
      await tempDir.delete(recursive: true);
    });
  });
}
