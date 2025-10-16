// ignore_for_file: leading_newlines_in_multiline_strings

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pigeon/pigeon.dart';
import 'package:pigeon_gen_cli/src/commands/generate_classes/gen_classes_command.dart';
import 'package:pigeon_gen_cli/src/commands/generate_classes/utils/utils.dart';

/// {@template gen_command}
///
/// `pigeon_gen_cli gen -i <input_file>`
/// A [Command] to generate a Pigeon classes file by extracting classes from
/// a single file.
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
      'Runs the Pigeon code generator with the given input file';

  @override
  String get name => 'gen';

  final Logger _logger;

  @override
  Future<int> run() async {
    try {
      final input = argResults?['input'] as String;

      _logger.info('Processing input: $input');

      final inputFile = File(input);
      final originalInputContent = inputFile.readAsStringSync();
      final importLines = extractImportLinesExcludingPigeon(
        originalInputContent,
      );
      final pigeonFileContent = extractPigeonFileContent(originalInputContent);

      final externalClasses = await resolveExternalClasses(input);
      final tempPigeonFile = File(input.replaceAll('.dart', '.g.dart'));

      await generateFlattenedPigeonFile(
        pigeonFileContent,
        externalClasses,
        tempPigeonFile.path,
      );
      final tempPigeonFileContent = tempPigeonFile.readAsStringSync();

      final contentWithoutGenClasses = removeSectionByTags(
        tempPigeonFileContent,
        sectionName: 'pigeonGenClasses',
      );
      final contentWithBaseClasses = renameBaseClassesToClasses(
        contentWithoutGenClasses,
      );

      final baseClasses = extractBaseClasses(contentWithBaseClasses);

      tempPigeonFile.writeAsStringSync(contentWithBaseClasses);

      await Pigeon.run(
        ['--input', tempPigeonFile.path],
      );

      final contentWithoutBaseClasses = removeClasses(
        contentWithBaseClasses,
        baseClasses.toList(),
      );
      final outputFilePath = extractDartOutWithRegex(contentWithBaseClasses);

      if (outputFilePath == null) {
        _logger.err('❌ [Error] Could not extract dartOut from source');
        return ExitCode.software.code;
      }

      final importLinesString = importLines.join('\n');

      File(outputFilePath).writeAsStringSync('''
      $importLinesString
      $contentWithoutBaseClasses
      ''');

      await tempPigeonFile.delete();
      await formatDartFile(outputFilePath);

      _logger.success('[Success] Pigeon file generated: $outputFilePath ✅');

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('❌ [Error] $e');
      return ExitCode.software.code;
    }
  }
}

/// Removes everything between start and end markers in [source].
///
/// [sectionName] is the name used in the marker, e.g., "basePigeonClasses".
/// If [keepTags] is true, the start/end tags themselves are kept; otherwise they are removed.
String removeSectionByTags(
  String source, {
  required String sectionName,
  bool keepTags = false,
}) {
  final startMarker = '// <!-- start $sectionName -->';
  final endMarker = '// <!-- end $sectionName -->';

  final startIndex = source.indexOf(startMarker);
  final endIndex = source.indexOf(endMarker);

  if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
    // Section not found, return original source
    return source;
  }

  final startRemoval = keepTags ? startIndex + startMarker.length : startIndex;
  final endRemoval = keepTags ? endIndex : endIndex + endMarker.length;

  return source.replaceRange(startRemoval, endRemoval, '');
}

String renameBaseClassesToClasses(String content) {
  /// Remove everything that matches the pattern 'PigeonGenBaseClass'
  return content.replaceAll('PigeonGenBaseClass', '');
}

Set<String> extractBaseClasses(String content) {
  // Looks for:
  // const List<Type> baseClasses = [
  //   SomeClass,
  //   AnotherClass,
  //   ...,
  // ];
  final baseClassesPattern = RegExp(
    r'const\s+List<Type>\s+baseClasses\s*=\s*\[(.*?)\];',
    multiLine: true,
    dotAll: true,
  );
  final match = baseClassesPattern.firstMatch(content);
  if (match == null) {
    return <String>{};
  }
  final classesBlock = match.group(1);

  if (classesBlock == null) {
    return <String>{};
  }

  // Split entries, remove whitespace/comments/trailing commas
  final lines = classesBlock
      .split(',')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => l.replaceAll(',', '').trim())
      .where((l) => l.isNotEmpty);

  return Set<String>.from(lines);
}

/// Extracts the `dartOut` value from a PigeonOptions declaration in Dart [source].
String? extractDartOutFromSource(String source) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;

  for (final decl
      in unit.declarations.whereType<TopLevelVariableDeclaration>()) {
    for (final variable in decl.variables.variables) {
      final initializer = variable.initializer;
      if (initializer is InstanceCreationExpression) {
        if (initializer.constructorName.type.name2.lexeme == 'PigeonOptions') {
          for (final arg in initializer.argumentList.arguments) {
            if (arg is NamedExpression && arg.name.label.name == 'dartOut') {
              final value = arg.expression;
              if (value is SimpleStringLiteral) {
                return value.value;
              }
            }
          }
        }
      }
    }
  }

  return null;
}

/// Extracts the dartOut path from a PigeonOptions declaration in [source].
/// Returns null if not found.
String? extractDartOutWithRegex(String source) {
  final regex = RegExp(
    r'''\bdartOut\s*:\s*(['"])([^'"]+)\1''',
    multiLine: true,
  );

  final match = regex.firstMatch(source);
  if (match != null && match.groupCount >= 2) {
    return match.group(2);
  }

  return null;
}

/// Extracts all import lines from [source], ignoring Pigeon imports.
/// Returns the full import line as in the source.
List<String> extractImportLinesExcludingPigeon(String source) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;

  final imports = <String>[];

  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri != null && !uri.startsWith('package:pigeon')) {
      imports.add(directive.toSource());
    }
  }

  return imports;
}
