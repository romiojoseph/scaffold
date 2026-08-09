import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../models/fs_node.dart';
import '../models/exclusions_config.dart';

class ScanParams {
  final String path;
  final ExclusionsConfig exclusionsConfig;
  ScanParams({required this.path, required this.exclusionsConfig});
}

/// Totals for the entire directory on disk, counted BEFORE exclusions
/// are applied, so exclusions can be reasoned about.
class ScanTotals {
  int files;
  int directories;
  int bytes;

  ScanTotals({this.files = 0, this.directories = 0, this.bytes = 0});
}

class ScanResult {
  final List<FsNode> nodes;
  final ScanTotals totals;
  const ScanResult({required this.nodes, required this.totals});
}

class ScannerService {
  final ExclusionsConfig exclusionsConfig;
  Isolate? _activeIsolate;

  ScannerService({required this.exclusionsConfig});

  Future<ScanResult> scanDirectoryInIsolate(
    String path, {
    void Function()? onCancel,
  }) async {
    final rootDir = Directory(path);
    if (!await rootDir.exists()) {
      throw Exception('Specified directory path does not exist: $path');
    }

    final completer = Completer<ScanResult>();
    final receivePort = ReceivePort();

    final params = ScanParams(path: path, exclusionsConfig: exclusionsConfig);

    try {
      _activeIsolate = await Isolate.spawn(
        _isolateEntry,
        [receivePort.sendPort, params],
      );

      receivePort.listen((message) {
        if (message is ScanResult) {
          completer.complete(message);
        } else if (message is String) {
          completer.completeError(Exception(message));
        } else if (message == 'CANCELLED') {
          completer.completeError(Exception('Scan was cancelled by user.'));
        }
        receivePort.close();
      });
    } catch (e) {
      receivePort.close();
      completer.completeError(e);
    }

    return completer.future;
  }

  void cancelScan() {
    if (_activeIsolate != null) {
      _activeIsolate!.kill(priority: Isolate.immediate);
      _activeIsolate = null;
    }
  }

  static void _isolateEntry(List<dynamic> args) {
    final SendPort sendPort = args[0] as SendPort;
    final ScanParams params = args[1] as ScanParams;

    try {
      final rootDir = Directory(params.path);

      ExclusionsConfig activeConfig = params.exclusionsConfig;
      if (params.exclusionsConfig.gitignoreOnly) {
        final gitignoreFile = File('${params.path}${Platform.pathSeparator}.gitignore');
        final gitPatterns = ExclusionsConfig.parseGitignoreFile(gitignoreFile);
        activeConfig = ExclusionsConfig(
          patterns: params.exclusionsConfig.patterns,
          enabled: params.exclusionsConfig.enabled,
          gitignoreOnly: true,
          gitignorePatterns: gitPatterns,
        );
      }

      final totals = ScanTotals();
      final tokeiStats = _runTokei(params.path);
      final results = _scanSubDir(
        rootDir,
        activeConfig,
        totals,
        tokeiStats: tokeiStats,
        rootPath: '',
      );
      sendPort.send(ScanResult(nodes: results, totals: totals));
    } catch (e) {
      sendPort.send(e.toString());
    }
  }

  static List<FsNode> _scanSubDir(
    Directory dir,
    ExclusionsConfig exclusionsConfig,
    ScanTotals totals, {
    bool collectNodes = true,
    Map<String, ({int total, int code, int blank, int comments})> tokeiStats =
        const {},
    String rootPath = '',
  }) {
    final items = <FsNode>[];

    // If a "folders only" pattern covers this directory, files are collected
    // for totals but not added to the visible tree.
    final filesHidden = collectNodes && rootPath.isNotEmpty &&
        exclusionsConfig.isFoldersOnly(rootPath);

    try {
      final entities = dir.listSync(followLinks: false);
      final included = <(FileSystemEntity, List<FsNode>)>[];

      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;

        // Build a forward-slash relative path from the scan root so that
        // path-style patterns like "build/flutter_assets" can be matched.
        final relativePath = rootPath.isEmpty
            ? name
            : '$rootPath/$name';

        final isExcluded = exclusionsConfig.isExcluded(
          name,
          relativePath: relativePath,
        );

        if (entity is Directory) {
          totals.directories++;
          final subChildren = _scanSubDir(
            entity,
            exclusionsConfig,
            totals,
            collectNodes: collectNodes && !isExcluded,
            tokeiStats: tokeiStats,
            rootPath: relativePath,
          );
          if (collectNodes && !isExcluded) {
            included.add((entity, subChildren));
          }
        } else if (entity is File) {
          totals.files++;
          try {
            totals.bytes += entity.lengthSync();
          } catch (_) {
            // Ignore files that cannot be stat'ed (locked/permission issues)
          }
          // Skip adding the file to the visible tree if the parent folder
          // has a "folders only" pattern (e.g. assets/icons/*)
          if (collectNodes && !isExcluded && !filesHidden) {
            included.add((entity, const <FsNode>[]));
          }
        }
      }

      // Sort: directories first (alphabetical), then files (alphabetical)
      included.sort((a, b) {
        final aIsDir = a.$1 is Directory;
        final bIsDir = b.$1 is Directory;
        if (aIsDir != bIsDir) {
          return aIsDir ? -1 : 1;
        }
        final aName = a.$1.path.split(Platform.pathSeparator).last.toLowerCase();
        final bName = b.$1.path.split(Platform.pathSeparator).last.toLowerCase();
        return aName.compareTo(bName);
      });

      for (final (entity, children) in included) {
        if (entity is Directory) {
          items.add(FsNode.fromFileSystemEntity(entity, children: children));
        } else if (entity is File) {
          final stats = tokeiStats[_tokeiKey(entity.path)];
          items.add(FsNode.fromFileSystemEntity(
            entity,
            lineCount: stats?.total ?? 0,
            codeLineCount: stats?.code ?? 0,
            blankLineCount: stats?.blank ?? 0,
            commentLineCount: stats?.comments ?? 0,
          ));
        }
      }
    } catch (_) {
      // Ignore unaccessible folders gracefully
    }

    return items;
  }

  /// Runs the bundled tokei CLI once over the whole root and returns
  /// per-file line statistics keyed by normalized absolute path.
  ///
  /// Exclusions (including gitignore patterns) are applied by this app's own
  /// walker, so tokei is told to ignore none of them (`--no-ignore`); only
  /// stats for files that end up included in the tree are read back.
  /// Returns an empty map when tokei is unavailable or fails, leaving line
  /// counts at zero without falling back to custom counting.
  static Map<String, ({int total, int code, int blank, int comments})>
      _runTokei(String rootPath) {
    final result = <String, ({int total, int code, int blank, int comments})>{};
    final exe = _findTokei();
    if (exe == null) return result;

    ProcessResult proc;
    try {
      proc = Process.runSync(
        exe,
        [rootPath, '--output', 'json', '--files', '--no-ignore', '--hidden'],
        stdoutEncoding: utf8,
      );
    } catch (_) {
      return result;
    }
    if (proc.exitCode != 0) return result;

    try {
      final data = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      for (final entry in data.entries) {
        if (entry.key == 'Total') continue;
        final language = entry.value;
        if (language is! Map<String, dynamic>) continue;
        final reports = language['reports'] as List<dynamic>? ?? const [];
        for (final report in reports) {
          if (report is! Map<String, dynamic>) continue;
          final name = report['name'];
          final stats = report['stats'];
          if (name is! String || stats is! Map<String, dynamic>) continue;
          final blank = stats['blanks'] as int? ?? 0;
          final code = stats['code'] as int? ?? 0;
          final comments = stats['comments'] as int? ?? 0;
          result[_tokeiKey(name)] = (
            total: blank + code + comments,
            code: code,
            blank: blank,
            comments: comments,
          );
        }
      }
    } catch (_) {
      return {};
    }
    return result;
  }

  static String _tokeiKey(String path) =>
      path.replaceAll('\\', '/').toLowerCase();

  /// Locates the tokei executable: `TOKEI_PATH` env var, next to the app
  /// executable (bundled by CMake at build time), relative to the working
  /// directory (dev runs), then on PATH.
  static String? _findTokei() {
    final env = Platform.environment['TOKEI_PATH'];
    if (env != null && env.isNotEmpty && File(env).existsSync()) {
      return env;
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final nearExe = File('$exeDir${Platform.pathSeparator}tokei.exe');
    if (nearExe.existsSync()) return nearExe.path;

    final relative =
        'assets${Platform.pathSeparator}third_party${Platform.pathSeparator}'
        'tokei${Platform.pathSeparator}tokei.exe';
    final cwd = File('${Directory.current.path}${Platform.pathSeparator}$relative');
    if (cwd.existsSync()) return cwd.path;

    for (final dir in Platform.environment['PATH']?.split(';') ?? const []) {
      if (dir.isEmpty) continue;
      final candidate = File('$dir${Platform.pathSeparator}tokei.exe');
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }
}
