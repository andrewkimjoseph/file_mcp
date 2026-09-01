import 'dart:io';

import 'package:file_mcp/file_finder.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late FileFinder finder;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('file_mcp_test_');
    finder = FileFinder(defaultSearchRoot: tempRoot.path);

    await _writeTree(tempRoot, {
      'shallow.txt': 'a',
      'docs/readme.md': 'b',
      'docs/notes.txt': 'c',
      'deep/nested/target.txt': 'd',
      'deep/nested/buried/hidden.txt': 'e',
      'node_modules/pkg/secret.txt': 'f',
      '.hidden/secret.txt': 'g',
    });
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('finds files with substring match', () async {
    final matches = await finder.findFiles(
      filename: 'readme',
      searchRoot: tempRoot.path,
    );

    expect(matches, hasLength(1));
    expect(matches.single, endsWith('docs/readme.md'));
  });

  test('finds files with exact match', () async {
    final matches = await finder.findFiles(
      filename: 'target.txt',
      searchRoot: tempRoot.path,
      exactMatch: true,
    );

    expect(matches, hasLength(1));
    expect(matches.single, endsWith('deep/nested/target.txt'));
  });

  test('respects max_results', () async {
    final matches = await finder.findFiles(
      filename: '.txt',
      searchRoot: tempRoot.path,
      maxResults: 2,
    );

    expect(matches, hasLength(2));
  });

  test('respects max_depth', () async {
    final matches = await finder.findFiles(
      filename: 'hidden.txt',
      searchRoot: tempRoot.path,
      exactMatch: true,
      maxDepth: 2,
    );

    expect(matches, isEmpty);
  });

  test('finds deep files when max_depth allows', () async {
    final matches = await finder.findFiles(
      filename: 'hidden.txt',
      searchRoot: tempRoot.path,
      exactMatch: true,
      maxDepth: 4,
    );

    expect(matches, hasLength(1));
    expect(matches.single, contains('deep/nested/buried/hidden.txt'));
  });

  test('skips node_modules and dot directories', () async {
    final matches = await finder.findFiles(
      filename: 'secret.txt',
      searchRoot: tempRoot.path,
      exactMatch: true,
    );

    expect(matches, isEmpty);
  });

  test('resolvePath reports file and directory kinds', () {
    final filePath = '${tempRoot.path}/shallow.txt';
    final dirPath = '${tempRoot.path}/docs';

    final fileResolution = finder.resolvePath(filePath);
    expect(fileResolution.kind, PathKind.file);
    expect(fileResolution.absolutePath, filePath);

    final dirResolution = finder.resolvePath(dirPath);
    expect(dirResolution.kind, PathKind.directory);
    expect(dirResolution.absolutePath, dirPath);

    final missing = finder.resolvePath('${tempRoot.path}/missing.txt');
    expect(missing.kind, PathKind.notFound);
  });
}

Future<void> _writeTree(Directory root, Map<String, String> files) async {
  for (final entry in files.entries) {
    final file = File('${root.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
}
