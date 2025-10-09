import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:pigeon_gen_cli/src/commands/generate/utils/generate_flatten_pigeon.dart';
import 'package:yaml/yaml.dart';

const _pubspecPath = 'pubspec.yaml';

/// Resolves all external classes used in [entryFile] except for pigeon.
/// Returns a map: class name -> absolute file path where it's defined.
Future<Map<String, String>> resolveExternalClasses(
  String entryFile,
  Map<String, String> packageRoots,
) async {
  final visitedFiles = <String>{};
  final classToFile = <String, String>{};

  _visitFile(
    entryFile,
    packageRoots,
    visitedFiles,
    classToFile,
    entryFile: entryFile,
  );

  return classToFile;
}

/// Recursively visit a file, analyzing imports/exports and class references.
/// - [filePath] → the file to visit
/// - [entryFile] → the entry file path
/// - [packageRoots] → the package roots
/// - [visitedFiles] → the visited files
/// - [classToFile] → the class to file map
void _visitFile(
  String filePath,
  Map<String, String> packageRoots,
  Set<String> visitedFiles,
  Map<String, String> classToFile, {
  String entryFile = '',
}) {
  final file = File(filePath);
  final absPath = p.normalize(file.absolute.path);

  if (visitedFiles.contains(absPath)) return;
  visitedFiles.add(absPath);

  final source = file.readAsStringSync();
  final unit = parseString(content: source, path: filePath).unit;

  // Collect local class declarations
  final declaredClasses = <String>{};
  for (final decl
      in unit.declarations.whereType<NamedCompilationUnitMember>()) {
    final lexeme = decl.name.lexeme;
    declaredClasses.add(lexeme);

    // Ignore classes that are part of the entry file
    final isPartOfEntryFile = filePath.contains(entryFile);
    if (!isPartOfEntryFile) {
      classToFile.putIfAbsent(lexeme, () => absPath);
    }
  }

  // Collect type references
  final referencedClasses = <String>{};
  unit.visitChildren(TypeReferenceCollector(referencedClasses));

  // Resolve imports
  final imports = unit.directives
      .whereType<ImportDirective>()
      .map((d) => d.uri.stringValue)
      // Ignore pigeon imports
      .where((d) => !(d?.contains('package:pigeon/pigeon.dart') ?? false))
      .whereType<String>();

  for (final import in imports) {
    final resolvedPath = _resolveImportUri(import, absPath, packageRoots);
    if (resolvedPath == null || visitedFiles.contains(resolvedPath)) continue;
    _visitFile(
      resolvedPath,
      packageRoots,
      visitedFiles,
      classToFile,
      entryFile: entryFile,
    );
  }

  // Resolve exports (barrel files)
  final exports = unit.directives
      .whereType<ExportDirective>()
      .map((d) => d.uri.stringValue)
      .whereType<String>();

  for (final export in exports) {
    final resolvedPath = _resolveImportUri(export, absPath, packageRoots);
    if (resolvedPath == null || visitedFiles.contains(resolvedPath)) continue;
    _visitFile(
      resolvedPath,
      packageRoots,
      visitedFiles,
      classToFile,
      entryFile: entryFile,
    );
  }
}

/// Resolves an import/export URI to a local file path
String? _resolveImportUri(
  String uri,
  String basePath,
  Map<String, String> packageRoots,
) {
  final mainPackageName = getCurrentPackageName();

  if (uri.startsWith('package:')) {
    // Get the package name from the current file path being processed
    final filePackageName = getPackageNameByPath(basePath);

    final parts = uri.replaceFirst('package:', '').split('/');
    final importPackageName = parts.first;
    final relativePath = parts.skip(1).join('/');

    if (importPackageName != filePackageName &&
        filePackageName != mainPackageName) {
      final fileName = p.basename(basePath);
      throw Exception(
        'Error in $fileName, only imports from the same package are allowed, '
        '$importPackageName is not part of $filePackageName',
      );
    }

    final root = packageRoots[importPackageName];
    if (root == null) return null;
    return p.join(root, 'lib', relativePath);
  }

  if (uri.startsWith('file://')) return Uri.parse(uri).toFilePath();

  // relative path
  return p.normalize(p.join(p.dirname(basePath), uri));
}

/// Gets the package name from the nearest pubspec.yaml file
/// - [filePath] → the file path to get the package name from
String? getPackageNameByPath(String filePath) {
  var dir = Directory(p.dirname(filePath));

  while (dir.path != dir.parent.path) {
    // stop at root
    final pubspec = File(p.join(dir.path, _pubspecPath));
    if (pubspec.existsSync()) {
      final name = _getPackageName(pubspec);
      return name;
    }
    dir = dir.parent;
  }

  return null; // pubspec.yaml not found
}

/// Gets the current package name from the pubspec.yaml file
String getCurrentPackageName() {
  final pubspecFile = File(_pubspecPath);
  if (!pubspecFile.existsSync()) {
    throw Exception('$_pubspecPath not found in current directory');
  }
  final content = _getPackageName(pubspecFile);
  return content;
}

String _getPackageName(File pubspecFile) {
  final content = pubspecFile.readAsStringSync();
  final yaml = loadYaml(content) as YamlMap;
  final name = yaml['name'] as String;
  return name;
}
