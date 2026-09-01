import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:file_mcp/file_finder.dart';

Future<void> main() async {
  final channel = stdioChannel(input: stdin, output: stdout);
  final server = FileMcpServer(channel);
  await server.done;
}

final class FileMcpServer extends MCPServer with ToolsSupport {
  FileMcpServer(super.channel)
      : _fileFinder = FileFinder(),
        super.fromStreamChannel(
          implementation: Implementation(
            name: 'file_mcp',
            version: '1.0.0',
          ),
          instructions: 'Locate files on the local filesystem. '
              'Use find_file to search by basename, glob, or substring '
              'under a directory tree, or resolve_path to resolve and '
              'verify a single path.',
        );

  final FileFinder _fileFinder;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    registerTool(
      Tool(
        name: 'find_file',
        description: 'Search for files by basename within a directory tree. '
            'Supports globs such as *.dart, *mcp*, and file_*.dart. '
            'Defaults to searching from the user home directory.',
        inputSchema: ObjectSchema(
          properties: {
            'filename': StringSchema(
              description:
                  'Basename to match (case-insensitive). '
                  'Use * and ? as globs (e.g. *.dart, *mcp*, file_*.dart). '
                  'Without wildcards, matches as a substring. '
                  'When exact_match is true, wildcards are literal.',
            ),
            'search_root': StringSchema(
              description:
                  'Directory to search from. Defaults to the user home directory.',
            ),
            'max_results': IntegerSchema(
              description: 'Maximum number of paths to return. Defaults to 20.',
            ),
            'exact_match': BooleanSchema(
              description:
                  'When true, match the full basename exactly and treat '
                  '* and ? as literal characters. Defaults to false.',
            ),
            'max_depth': IntegerSchema(
              description:
                  'Maximum directory depth to search below search_root. '
                  'Omit for unlimited depth.',
            ),
          },
          required: ['filename'],
        ),
      ),
      _handleFindFile,
    );

    registerTool(
      Tool(
        name: 'resolve_path',
        description:
            'Resolve a path to its absolute form and report whether it exists.',
        inputSchema: ObjectSchema(
          properties: {
            'path': StringSchema(
              description: 'Relative or absolute path to resolve.',
            ),
          },
          required: ['path'],
        ),
      ),
      _handleResolvePath,
    );

    return super.initialize(request);
  }

  Future<CallToolResult> _handleFindFile(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final filename = args['filename'] as String?;

    if (filename == null || filename.trim().isEmpty) {
      return _error('filename is required');
    }

    final searchRoot = args['search_root'] as String?;
    final maxResults = args['max_results'] as int? ?? 20;
    final exactMatch = args['exact_match'] as bool? ?? false;
    final maxDepth = args['max_depth'] as int?;

    if (maxResults < 1) {
      return _error('max_results must be at least 1');
    }

    if (maxDepth != null && maxDepth < 0) {
      return _error('max_depth must be non-negative');
    }

    try {
      final matches = await _fileFinder.findFiles(
        filename: filename,
        searchRoot: searchRoot,
        maxResults: maxResults,
        exactMatch: exactMatch,
        maxDepth: maxDepth,
      );

      if (matches.isEmpty) {
        final root = searchRoot ?? _fileFinder.defaultSearchRoot;
        return CallToolResult(
          content: [
            TextContent(
              text: 'No files matching "$filename" found under $root.',
            ),
          ],
        );
      }

      final lines = [
        'Found ${matches.length} match(es):',
        ...matches,
      ];
      return CallToolResult(content: [TextContent(text: lines.join('\n'))]);
    } on ArgumentError catch (error) {
      return _error(error.message ?? error.toString());
    }
  }

  CallToolResult _handleResolvePath(CallToolRequest request) {
    final args = request.arguments ?? {};
    final path = args['path'] as String?;

    if (path == null || path.trim().isEmpty) {
      return _error('path is required');
    }

    try {
      final resolution = _fileFinder.resolvePath(path);
      final kindLabel = switch (resolution.kind) {
        PathKind.file => 'file',
        PathKind.directory => 'directory',
        PathKind.notFound => 'not_found',
      };

      final lines = [
        'absolute_path: ${resolution.absolutePath}',
        'type: $kindLabel',
        if (resolution.parentPath != null) 'parent: ${resolution.parentPath}',
      ];

      return CallToolResult(content: [TextContent(text: lines.join('\n'))]);
    } on ArgumentError catch (error) {
      return _error(error.message ?? error.toString());
    }
  }

  CallToolResult _error(String message) {
    return CallToolResult(
      content: [TextContent(text: message)],
      isError: true,
    );
  }
}
