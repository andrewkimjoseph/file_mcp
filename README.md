# file_mcp

A simple [Model Context Protocol](https://modelcontextprotocol.io/) server written in Dart that helps locate files on your local filesystem. It communicates over STDIO using [`dart_mcp`](https://pub.dev/packages/dart_mcp).

## Tools

### `find_file`

Search for files by name under a directory tree.

| Parameter     | Type   | Required | Default        |
|---------------|--------|----------|----------------|
| `filename`    | string | yes      | —              |
| `search_root` | string | no       | `$HOME`        |
| `max_results` | int    | no       | `20`           |
| `exact_match` | bool   | no       | `false`        |
| `max_depth`   | int    | no       | unlimited      |

Search uses async breadth-first traversal with parallel directory scans and skips common cache/build directories (`node_modules`, `.git`, `build`, etc.).

### `resolve_path`

Resolve a single path and report whether it exists as a file or directory.

| Parameter | Type   | Required |
|-----------|--------|----------|
| `path`    | string | yes      |

## Install Dart

This server requires the [Dart SDK](https://dart.dev/get-dart). If you already have [Flutter](https://docs.flutter.dev/get-started/install), Dart is included and you can skip this step.

Install from the **stable** channel using a package manager:

**macOS** ([Homebrew](https://brew.sh/)):

```bash
brew tap dart-lang/dart
brew trust dart-lang/dart
brew install dart
```

**Linux** (Debian/Ubuntu):

```bash
sudo apt-get update && sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' \
  | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update && sudo apt-get install dart
```

On ARM or RISC-V, replace `arch=amd64` with `armhf`, `arm64`, or `riscv64`.

**Windows** ([Chocolatey](https://chocolatey.org/), elevated PowerShell):

```powershell
choco install dart-sdk
```

Then confirm the SDK is on your `PATH`:

```bash
dart --version
```

Other options (Docker, ZIP archive, building from source) are on [Get the Dart SDK](https://dart.dev/get-dart).

## Run locally

```bash
cd file_mcp
dart pub get
dart run bin/file_mcp.dart
```

## Cursor configuration

Add this to `~/.cursor/mcp.json`:

```json
"file-mcp": {
  "type": "stdio",
  "command": "dart",
  "args": ["run", "/Users/andi/andrewkimjoseph/file_mcp/bin/file_mcp.dart"]
}
```

## Claude Desktop configuration

Add this to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
"file-mcp": {
  "type": "stdio",
  "command": "/Users/andi/develop/flutter/bin/dart",
  "args": ["run", "/Users/andi/andrewkimjoseph/file_mcp/bin/file_mcp.dart"]
}
```

Claude Desktop does not inherit your shell `PATH`, so `"command": "dart"` fails with **No such file or directory**. Use the full path to your Dart binary (run `which dart` in a terminal to find it).

Or install globally and use a shorter command:

```bash
dart pub global activate --source path /Users/andi/andrewkimjoseph/file_mcp
```

```json
"file-mcp": {
  "type": "stdio",
  "command": "file_mcp",
  "args": []
}
```

After updating the config, restart the app so it picks up the new MCP server.
