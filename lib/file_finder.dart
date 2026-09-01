import 'dart:async';
import 'dart:collection';
import 'dart:io';

const _skippedDirNames = {
  'node_modules',
  '.git',
  'Library/Caches',
  '.dart_tool',
  'build',
  'dist',
  '.npm',
  '.cache',
  'DerivedData',
  'Pods',
  'vendor',
  'target',
  '.pnpm-store',
  '__pycache__',
  '.gradle',
};

const _maxConcurrentScans = 8;

class _DirWorkItem {
  const _DirWorkItem(this.directory, this.depth);

  final Directory directory;
  final int depth;
}

class PathResolution {
  const PathResolution({
    required this.absolutePath,
    required this.kind,
    this.parentPath,
  });

  final String absolutePath;
  final PathKind kind;
  final String? parentPath;
}

enum PathKind { file, directory, notFound }

class FileFinder {
  FileFinder({String? defaultSearchRoot})
      : defaultSearchRoot =
            defaultSearchRoot ?? Platform.environment['HOME'] ?? '.';

  final String defaultSearchRoot;

  /// Search for files matching [filename] under [searchRoot].
  ///
  /// Returns absolute paths, stopping after [maxResults] matches.
  /// Uses async breadth-first traversal with bounded concurrency.
  Future<List<String>> findFiles({
    required String filename,
    String? searchRoot,
    int maxResults = 20,
    bool exactMatch = false,
    int? maxDepth,
  }) async {
    if (filename.trim().isEmpty) {
      throw ArgumentError('filename must not be empty');
    }

    if (maxDepth != null && maxDepth < 0) {
      throw ArgumentError('max_depth must be non-negative');
    }

    final rootPath = searchRoot ?? defaultSearchRoot;
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      throw ArgumentError('search_root does not exist: $rootPath');
    }

    final needle = filename.toLowerCase();
    final results = <String>[];
    final queue = Queue<_DirWorkItem>()..add(_DirWorkItem(root, 0));
    final inFlight = <Future<void>>{};
    var stopped = false;

    Future<void> scanDirectory(_DirWorkItem item) async {
      if (stopped || results.length >= maxResults) {
        return;
      }

      try {
        await for (final entry in item.directory.list(followLinks: false)) {
          if (stopped || results.length >= maxResults) {
            stopped = true;
            return;
          }

          final name = _entryName(entry);
          if (entry is Directory) {
            if (_shouldSkipDirectory(name)) continue;
            if (maxDepth == null || item.depth < maxDepth) {
              queue.add(_DirWorkItem(entry, item.depth + 1));
            }
            continue;
          }

          if (entry is! File) continue;

          final basename = name.toLowerCase();
          final matches =
              exactMatch ? basename == needle : basename.contains(needle);
          if (matches) {
            results.add(entry.absolute.path);
            if (results.length >= maxResults) {
              stopped = true;
              return;
            }
          }
        }
      } on FileSystemException {
        return;
      }
    }

    while ((queue.isNotEmpty || inFlight.isNotEmpty) && !stopped) {
      while (queue.isNotEmpty &&
          inFlight.length < _maxConcurrentScans &&
          !stopped) {
        final item = queue.removeFirst();
        final future = scanDirectory(item);
        inFlight.add(future);
        unawaited(
          future.whenComplete(() {
            inFlight.remove(future);
          }),
        );
      }

      if (inFlight.isEmpty) {
        break;
      }

      await Future.any(inFlight);
    }

    return results;
  }

  PathResolution resolvePath(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError('path must not be empty');
    }

    final file = File(path);
    if (file.existsSync()) {
      final absolute = file.absolute;
      return PathResolution(
        absolutePath: absolute.path,
        kind: PathKind.file,
        parentPath: absolute.parent.path,
      );
    }

    final directory = Directory(path);
    if (directory.existsSync()) {
      final absolute = directory.absolute;
      return PathResolution(
        absolutePath: absolute.path,
        kind: PathKind.directory,
        parentPath: absolute.parent.path,
      );
    }

    final absolute = file.absolute;
    return PathResolution(
      absolutePath: absolute.path,
      kind: PathKind.notFound,
      parentPath: absolute.parent.path,
    );
  }

  bool _shouldSkipDirectory(String name) {
    if (name.isEmpty) return false;
    if (name.startsWith('.')) return true;
    return _skippedDirNames.contains(name);
  }

  String _entryName(FileSystemEntity entry) {
    return entry.path
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .last;
  }
}
