import 'package:pigeon_gen_cli/src/commands/generate/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  const content = '''
import 'package:pigeon/pigeon.dart';
import 'package:my_package/models.dart';

@HostApi()
abstract class Messages {
  Message getMessage();

  Response getResponse();
}

class Message {
  String text;
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
\n
''';
  group('extractPigeonFileContent', () {
    test('extracts the pigeon file content', () async {
      final extractedContent = extractPigeonFileContent(content);
      expect(extractedContent, expectedContent);
    });
  });
}
