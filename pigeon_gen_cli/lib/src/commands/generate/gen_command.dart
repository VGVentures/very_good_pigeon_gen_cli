// ignore_for_file: leading_newlines_in_multiline_strings

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pigeon/pigeon.dart';
import 'package:pigeon_gen_cli/src/commands/generate_classes/gen_classes_command.dart';
import 'package:pigeon_gen_cli/src/commands/generate_classes/utils/utils.dart';
import 'package:pigeon_gen_cli/src/commands/utils/utils.dart';

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
      final importLinesString = importLines.join('\n');

      final pigeonFileContent = extractPigeonFileContent(originalInputContent);

      final externalClasses = await resolveExternalClasses(input);
      final tempPigeonFile = File(input.replaceAll('.dart', '.g.dart'));

      final generatedClasses = externalClasses.keys
          .toList()
          .where((element) => !element.contains('_deepEquals'))
          .toList();

      await generateFlattenedPigeonFile(
        pigeonFileContent,
        externalClasses,
        tempPigeonFile.path,
      );
      final tempPigeonFileContent = tempPigeonFile.readAsStringSync();

      final formattedPigeonClassesFileContent = removeGeneratedMembers(
        tempPigeonFileContent,
      );
      tempPigeonFile.writeAsStringSync(formattedPigeonClassesFileContent);

      // Run Pigeon with generated classes
      await Pigeon.run(['--input', tempPigeonFile.path]);

      final outputFilePath = extractDartOutWithRegex(
        formattedPigeonClassesFileContent,
      );

      if (outputFilePath == null) {
        _logger.err('❌ [Error] Could not extract dartOut from source');
        return ExitCode.software.code;
      }
      final outputFile = File(outputFilePath);
      final outputFileContent = outputFile.readAsStringSync();

      final contentWithoutGeneratedClasses = removeClasses(
        outputFileContent,
        generatedClasses,
      );

      outputFile.writeAsStringSync(contentWithoutGeneratedClasses);

      final contentWithImportLines = insertContent(
        contentWithoutGeneratedClasses,
        importLinesString,
        4,
      );
      outputFile.writeAsStringSync(contentWithImportLines);

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

String insertContent(String source, String content, int lineNumber) {
  final lines = source.split('\n')..insert(lineNumber, content);
  return lines.join('\n');
}

/// Removes `_toList`, `decode`, `operator ==`, and `hashCode` members
/// from all class declarations in the provided [source].
String removeGeneratedMembers(String source) {
  final parseResult = parseString(content: source, throwIfDiagnostics: false);
  final unit = parseResult.unit;
  final buffer = StringBuffer();
  var lastIndex = 0;

  // Helper: record the offset ranges of members to remove
  final rangesToRemove = <(int, int)>[];

  /// Remove _deepEquals()
  for (final decl in unit.declarations.whereType<FunctionDeclaration>()) {
    if (decl.name.lexeme == '_deepEquals') {
      rangesToRemove.add((decl.offset, decl.end));
    }
  }

  for (final decl in unit.declarations.whereType<ClassDeclaration>()) {
    for (final member in decl.members) {
      var shouldRemove = false;

      // Remove private _toList() method
      if (member is MethodDeclaration && member.name.lexeme == '_toList') {
        shouldRemove = true;
      }
      // Remove static decode()
      else if (member is MethodDeclaration &&
          member.name.lexeme == 'decode' &&
          member.isStatic) {
        shouldRemove = true;
      }
      // Remove  encode()
      else if (member is MethodDeclaration && member.name.lexeme == 'encode') {
        shouldRemove = true;
      }
      // Remove operator ==
      else if (member is MethodDeclaration && member.name.lexeme == '==') {
        shouldRemove = true;
      }
      // Remove hashCode getter
      else if (member is MethodDeclaration &&
          member.isGetter &&
          member.name.lexeme == 'hashCode') {
        shouldRemove = true;
      }

      if (shouldRemove) {
        rangesToRemove.add((member.offset, member.end));
      }
    }
  }

  // Build the new source, skipping removed ranges
  for (final range in rangesToRemove) {
    final (start, end) = range;
    buffer.write(source.substring(lastIndex, start));
    lastIndex = end;
  }
  buffer.write(source.substring(lastIndex));

  return buffer.toString();
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
