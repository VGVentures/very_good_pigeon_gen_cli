import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/generate/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  const pigeonFileContent = '''
import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class Messages {
  Message getMessage();

  Response getResponse();
}

class Message {
  String text;
}

''';

  const messageFileContent = '''
class Response {
  Response({required this.data});
  String data;
}

''';

  const expectedContent = '''
import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class Messages {
  Message getMessage();

  Response getResponse();
}

class Message {
  String text;
}

class Response {
  Response({required this.data});
  String data;
}\n''';

  group('generateFlattenedPigeonFile', () {
    test('generates a flattened pigeon file', () async {
      /// create the temp directory
      final tempDir = await Directory.systemTemp.createTemp(
        'pigeon_gen_cli_test_',
      );
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final targetFilePath = p.join(tempDir.path, 'messages.dart');
      final responseFile = File(p.join(tempDir.path, 'message.dart'))
        ..writeAsStringSync(messageFileContent);
      final classToFile = {'Response': responseFile.path};

      await generateFlattenedPigeonFile(
        pigeonFileContent,
        classToFile,
        targetFilePath,
      );

      final targetFileContent = File(targetFilePath).readAsStringSync();
      expect(targetFileContent, contains(expectedContent));
    });
  });
}
