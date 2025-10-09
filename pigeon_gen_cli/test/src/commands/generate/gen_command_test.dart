import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pigeon_gen_cli/src/command_runner.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('gen', () {
    late Logger logger;
    late PigeonGenCliCommandRunner commandRunner;

    setUp(() {
      logger = _MockLogger();
      commandRunner = PigeonGenCliCommandRunner(logger: logger);
    });

    test('thorws an error when an exception is caught', () async {
      final exitCode = await commandRunner.run([
        'gen',
        '-i',
        '',
      ]);

      expect(exitCode, ExitCode.software.code);
      verify(
        () => logger.err(
          any(
            that: contains('❌ [Error]'),
          ),
        ),
      ).called(1);
    });

    test('wrong usage', () async {
      final exitCode = await commandRunner.run(['gen', '-p']);

      expect(exitCode, ExitCode.usage.code);

      verify(
        () => logger.err('Could not find an option or flag "-p".'),
      ).called(1);

      verify(
        () => logger.info('''
Usage: $executableName gen [arguments]
-h, --help                 Print this usage information.
-i, --input (mandatory)    The input file to process and generate the flattened pigeon file

Run "$executableName help" to see global options.'''),
      ).called(1);
    });
  });
}
