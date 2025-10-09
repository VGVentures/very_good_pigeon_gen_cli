import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/generate/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('resolveExternalClasses', () {
    test('resolves external classes correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      Directory.current = tempDir.path;

      final inputFile =
          File(
            p.join(tempDir.path, 'input.dart'),
          )..writeAsStringSync('''
import 'package:pigeon/pigeon.dart';
import 'package:package_1/package_1.dart';

@HostApi()
abstract class Messages {
  Package1Model getModel();

  void testVoid();
}
      ''');

      // root package pubspec.yaml
      File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('''
name: root_package
version: 1.0.0
''');

      /// create package_1 directory
      final package1RootDir = Directory(
        p.join(tempDir.path, 'package_1'),
      );
      await package1RootDir.create(recursive: true);

      final package1LibDir = Directory(
        p.join(package1RootDir.path, 'lib'),
      );
      await package1LibDir.create(recursive: true);
      File(
        p.join(package1RootDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('''
name: package_1
version: 1.0.0
''');

      File(
        p.join(package1LibDir.path, 'package_1.dart'),
      ).writeAsStringSync('''
export 'package_1_model.dart';
      ''');

      final package1ModelFile =
          File(
            p.join(package1LibDir.path, 'package_1_model.dart'),
          )..writeAsStringSync('''
class Package1Model {
  const Package1Model({required this.text});
  String text;
}
      ''');

      final externalClasses = await resolveExternalClasses(inputFile.path, {
        'package_1': package1RootDir.path,
      });

      expect(externalClasses, {'Package1Model': package1ModelFile.path});
    });

    test(
      'throws an error if an import from the referenced file is not part '
      'of the same package',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'pigeon_gen_cli_test_',
        );
        addTearDown(() async {
          await tempDir.delete(recursive: true);
        });

        Directory.current = tempDir.path;

        final inputFile =
            File(
              p.join(tempDir.path, 'input.dart'),
            )..writeAsStringSync('''
import 'package:pigeon/pigeon.dart';
import 'package:package_1/package_1.dart';

@HostApi()
abstract class Messages {
  Package1Model getModel();

  void testVoid();
}
      ''');

        // root package pubspec.yaml
        File(
          p.join(tempDir.path, 'pubspec.yaml'),
        ).writeAsStringSync('''
name: root_package
version: 1.0.0
''');

        /// create equatable directory
        final equatableRootDir = Directory(
          p.join(tempDir.path, 'equatable'),
        );
        await equatableRootDir.create(recursive: true);

        /// create package_1 directory
        final package1RootDir = Directory(
          p.join(tempDir.path, 'package_1'),
        );
        await package1RootDir.create(recursive: true);

        final package1LibDir = Directory(
          p.join(package1RootDir.path, 'lib'),
        );
        await package1LibDir.create(recursive: true);
        File(
          p.join(package1RootDir.path, 'pubspec.yaml'),
        ).writeAsStringSync('''
name: package_1
version: 1.0.0
''');

        File(
          p.join(package1LibDir.path, 'package_1.dart'),
        ).writeAsStringSync('''
export 'package_1_model.dart';
      ''');

        File(
          p.join(package1LibDir.path, 'package_1_model.dart'),
        ).writeAsStringSync('''
import 'package:equatable/equatable.dart';
class Package1Model extends Equatable {
  const Package1Model({required this.text});
  String text;

  @override
  List<Object?> get props => [text];
}
      ''');

        expect(
          () async => resolveExternalClasses(inputFile.path, {
            'package_1': package1RootDir.path,
            'equatable': equatableRootDir.path,
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Error in package_1_model.dart, only imports from the same'
                ' package are allowed, equatable is not part of package_1',
              ),
            ),
          ),
        );
      },
    );
  });

  group('getPackageNameByPath', () {
    test('returns the parent package name', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      final parentPackageDir = Directory(
        p.join(tempDir.path, 'parent_package'),
      );
      await parentPackageDir.create(recursive: true);
      final childPackageDir = Directory(
        p.join(parentPackageDir.path, 'child_package'),
      );
      await childPackageDir.create(recursive: true);

      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

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
    });
  });
  group('getCurrentPackageName', () {
    test('returns the current package name', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

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
    });

    test('throws an error if the pubspec.yaml is not found', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

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
    });
  });
}
