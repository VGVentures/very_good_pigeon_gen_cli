import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pigeon_gen_cli/src/commands/generate/utils/utils.dart';

/// {@template gen_command}
///
/// `pigeon_gen_cli gen -i <input_file>`
/// A [Command] to generate a flattened pigeon file by importing classes from
/// multiple files into a single file.
/// {@endtemplate}
class GenCommand extends Command<int> {
  /// {@macro gen_command}
  GenCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'input',
      abbr: 'i',
      help: 'The input file to process and generate the flattened pigeon file',
      mandatory: true,
    );
  }

  @override
  String get description =>
      'Generate a flattened pigeon file by importing classes from '
      'multiple files into a single file';

  @override
  String get name => 'gen';

  final Logger _logger;

  @override
  Future<int> run() async {
    try {
      final input = argResults?['input'] as String;
      _logger.info('Processing input: $input');

      final output = input.replaceAll('.dart', '.g.dart');

      final inputFile = File(input);
      final inputContent = inputFile.readAsStringSync();
      final selfContainedContent = extractPigeonFileContent(inputContent);

      final externalClasses = await resolveExternalClasses(input);

      await generateFlattenedPigeonFile(
        selfContainedContent,
        externalClasses,
        output,
      );

      _logger.success(
        '[Success] Generated flattened pigeon api file: $output ✅',
      );

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('❌ [Error] $e');
      return ExitCode.software.code;
    }
  }
}
