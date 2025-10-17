import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pigeon/pigeon.dart';
import 'package:pigeon_gen_cli/src/commands/utils/utils.dart';

/// {@template gen_classes_command}
///
/// `pigeon_gen_cli gen-classes -i <input_file>`
/// A [Command] to generate a Pigeon classes file by extracting classes from
/// a single file.
/// {@endtemplate}
class GenClassesCommand extends Command<int> {
  /// {@macro gen_classes_command}
  GenClassesCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help:
            'The input file to process and generate the flattened pigeon file',
        mandatory: true,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'The output file to save the Pigeon classes file',
        mandatory: true,
      );
  }

  @override
  String get description =>
      'Generate a Pigeon classes file by extracting classes from '
      'a single file';

  @override
  String get name => 'gen_classes';

  final Logger _logger;

  @override
  Future<int> run() async {
    try {
      final input = argResults?['input'] as String;
      final output = argResults?['output'] as String;

      _logger.info('Processing input: $input');

      final outputPigeonDataClassesFile = await generatePigeonFile(
        input,
        output,
      );
      final outputContent = outputPigeonDataClassesFile.readAsStringSync();

      // final newClassesConst =
      //   'const List<Type> baseClasses = [${newClasses.join(', ')}];';
      outputPigeonDataClassesFile.writeAsStringSync(outputContent);

      // Format file
      await formatDartFile(outputPigeonDataClassesFile.path);

      _logger.success('[Success] Generated Pigeon classes file: $output ✅');

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('❌ [Error] $e');
      return ExitCode.software.code;
    }
  }
}

/// Generates a Pigeon data classes file from the given input file.
Future<File> generatePigeonFile(String input, String output) async {
  final inputFile = File(input);
  var inputContent = inputFile.readAsStringSync();
  final currentPackageName = getPackageNameByPath(input);

  /// Append PigeonConfiguration to the input content
  inputContent =
      // Improves readability
      // ignore: leading_newlines_in_multiline_strings
      '''import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: '$output',
    dartPackageName: '$currentPackageName',
  ),
)

$inputContent
''';

  final tempFile = File('temp.dart')..writeAsStringSync(inputContent);

  await Pigeon.run(['--input', tempFile.path]);

  await tempFile.delete();

  final outputFile = File(output);
  var outputContent = outputFile.readAsStringSync();

  /// Remove everything but pigeon data classes
  outputContent = removeClasses(outputContent, ['_PigeonCodec']);
  outputContent = removeAllImports(outputContent);

  outputFile.writeAsStringSync(outputContent);

  return outputFile;
}

/// Removes classes with the given [classNames] from the Dart [source].
String removeClasses(String source, List<String> classNames) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;

  // Collect ranges to remove
  final ranges = <(int start, int end)>[];

  for (final decl
      in unit.declarations.whereType<NamedCompilationUnitMember>()) {
    if (classNames.contains(decl.name.lexeme)) {
      // Remove from start of the class declaration to the end
      ranges.add((decl.offset, decl.end));
    }
  }

  // Apply removals from end to start to preserve offsets
  var updatedSource = source;
  for (final range in ranges.reversed) {
    updatedSource = updatedSource.replaceRange(range.$1, range.$2, '');
  }

  return updatedSource;
}

/// Removes all import lines from the Dart [source] literally
String removeAllImports(String source) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;
  final lineInfo = parseResult.lineInfo;

  final ranges = <(int start, int end)>[];

  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final startLine = lineInfo.getLocation(directive.offset).lineNumber - 1;
    final endLine = lineInfo.getLocation(directive.end).lineNumber - 1;

    final startOffset = lineInfo.getOffsetOfLine(startLine);

    // Calculate end offset: start of next line, or end of file
    final endOffset = (endLine + 1 < lineInfo.lineCount)
        ? lineInfo.getOffsetOfLine(endLine + 1)
        : source.length;

    ranges.add((startOffset, endOffset));
  }

  // Apply removals from end to start to preserve offsets
  var updatedSource = source;
  for (final range in ranges.reversed) {
    updatedSource = updatedSource.replaceRange(range.$1, range.$2, '');
  }

  return updatedSource;
}
