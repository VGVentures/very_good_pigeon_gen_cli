// ignore_for_file: leading_newlines_in_multiline_strings

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pigeon/pigeon.dart';
import 'package:pigeon_gen_cli/src/commands/generate_classes/utils/utils.dart';

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
      _logger.info('Processing output: $output');

      final inputFile = File(input);
      final originalInputContent = inputFile.readAsStringSync();

      await generatePigeonFile(input, output);

      final outputFile = File(output);
      final outputContent = outputFile.readAsStringSync();

      final classes = extractClassNames(originalInputContent);

      final (renamedOutputContent, newClasses) = _renameCustomClasses(
        originalInputContent,
        classes,
      );

      final newClassesConst =
          'const List<Type> baseClasses = [${newClasses.join(', ')}];';
      outputFile.writeAsStringSync(
        '''
        // <!-- start pigeonGenClasses -->
        $outputContent
        // <!-- end pigeonGenClasses -->
        // <!-- start pigeonGenBaseClasses -->
        $newClassesConst
        \n
        $renamedOutputContent
        // <!-- end pigeonGenBaseClasses -->
        ''',
      );

      // Format file
      await formatDartFile(outputFile.path);

      _logger.success(
        '[Success] Generated Pigeon classes file: $output ✅',
      );

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('❌ [Error] $e');
      return ExitCode.software.code;
    }
  }
}

Future<void> formatDartFile(String filePath) async => Process.run(
  'dart',
  ['format', filePath],
  runInShell: true,
);

Future<void> generatePigeonFile(String input, String output) async {
  final inputFile = File(input);
  var inputContent = inputFile.readAsStringSync();
  final currentPackageName = getPackageNameByPath(input);

  /// Append PigeonConfiguration to the input content
  inputContent =
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

  outputContent = removeClasses(outputContent, ['_PigeonCodec']);
  outputContent = removeAllImports(outputContent);

  outputFile.writeAsStringSync(outputContent);
}

(String, Set<String>) _renameCustomClasses(
  String classSource,
  Set<String> classes,
) {
  var source = classSource;
  final newClasses = <String>{};
  for (final customClass in classes) {
    final newName = '${customClass}PigeonGenBaseClass';
    source = source.replaceAllMapped(
      RegExp(r'\b' + RegExp.escape(customClass) + r'\b'),
      (match) => newName,
    );
    newClasses.add(newName);
  }
  return (source, newClasses);
}

/// Returns a list of all class names in the given Dart source
Set<String> extractClassNames(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final unit = result.unit;

  final classNames = <String>[];

  for (final decl
      in unit.declarations.whereType<NamedCompilationUnitMember>()) {
    classNames.add(decl.name.lexeme);
  }

  return classNames.toSet();
}

/// Removes classes with the given [classNames] from the Dart [source].
String removeClasses(String source, List<String> classNames) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;

  // Collect ranges to remove
  final ranges = <_Range>[];

  for (final decl
      in unit.declarations.whereType<NamedCompilationUnitMember>()) {
    if (classNames.contains(decl.name.lexeme)) {
      // Remove from start of the class declaration to the end
      ranges.add(_Range(start: decl.offset, end: decl.end));
    }
  }

  // Apply removals from end to start to preserve offsets
  var updatedSource = source;
  for (final range in ranges.reversed) {
    updatedSource = updatedSource.replaceRange(range.start, range.end, '');
  }

  return updatedSource;
}

/// Removes all import lines from the Dart [source] literally
String removeAllImports(String source) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;
  final lineInfo = parseResult.lineInfo;

  final ranges = <_Range>[];

  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final startLine = lineInfo.getLocation(directive.offset).lineNumber - 1;
    final endLine = lineInfo.getLocation(directive.end).lineNumber - 1;

    final startOffset = lineInfo.getOffsetOfLine(startLine);

    // Calculate end offset: start of next line, or end of file
    final endOffset = (endLine + 1 < lineInfo.lineCount)
        ? lineInfo.getOffsetOfLine(endLine + 1)
        : source.length;

    ranges.add(_Range(start: startOffset, end: endOffset));
  }

  // Apply removals from end to start to preserve offsets
  var updatedSource = source;
  for (final range in ranges.reversed) {
    updatedSource = updatedSource.replaceRange(range.start, range.end, '');
  }

  return updatedSource;
}

class _Range {
  _Range({required this.start, required this.end});

  final int start;
  final int end;
}
