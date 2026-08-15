import 'dart:convert';
import 'dart:io';
import '../models/dependency_info.dart';
import '../models/fs_node.dart';

class ManifestParserService {
  const ManifestParserService();

  /// Locates all known manifest files across the scanned nodes tree or directory.
  Future<List<ManifestFile>> findAndParseManifests({
    List<FsNode>? nodes,
    String? rootPath,
  }) async {
    final manifestPaths = <String>{};

    if (nodes != null && nodes.isNotEmpty) {
      _collectManifestPathsFromNodes(nodes, manifestPaths);
    } else if (rootPath != null && Directory(rootPath).existsSync()) {
      await _collectManifestPathsFromDisk(Directory(rootPath), manifestPaths);
    }

    final manifests = <ManifestFile>[];
    for (final path in manifestPaths) {
      final manifest = await parseManifestFile(path);
      if (manifest != null && manifest.dependencies.isNotEmpty) {
        manifests.add(manifest);
      }
    }

    return manifests;
  }

  void _collectManifestPathsFromNodes(
    List<FsNode> nodes,
    Set<String> collected,
  ) {
    for (final node in nodes) {
      if (node.isDirectory) {
        if (node.children != null) {
          _collectManifestPathsFromNodes(node.children!, collected);
        }
      } else {
        final name = node.name.toLowerCase();
        if (_isManifestName(name)) {
          collected.add(node.path);
        }
      }
    }
  }

  Future<void> _collectManifestPathsFromDisk(
    Directory dir,
    Set<String> collected,
  ) async {
    try {
      final entities = await dir.list(followLinks: false).toList();
      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
        if (name == 'node_modules' ||
            name == '.git' ||
            name == '.dart_tool' ||
            name == 'target' ||
            name == 'vendor') {
          continue;
        }

        if (entity is Directory) {
          await _collectManifestPathsFromDisk(entity, collected);
        } else if (entity is File) {
          if (_isManifestName(name)) {
            collected.add(entity.path);
          }
        }
      }
    } catch (_) {}
  }

  bool _isManifestName(String name) {
    return name == 'package.json' ||
        name == 'pubspec.yaml' ||
        name == 'go.mod' ||
        name == 'cargo.toml' ||
        name == 'pyproject.toml' ||
        name == 'requirements.txt';
  }

  Future<ManifestFile?> parseManifestFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final lowerName = fileName.toLowerCase();

    try {
      final content = await file.readAsString();

      if (lowerName == 'package.json') {
        return _parsePackageJson(filePath, fileName, content);
      } else if (lowerName == 'pubspec.yaml') {
        return _parsePubspecYaml(filePath, fileName, content);
      } else if (lowerName == 'go.mod') {
        return _parseGoMod(filePath, fileName, content);
      } else if (lowerName == 'cargo.toml') {
        return _parseCargoToml(filePath, fileName, content);
      } else if (lowerName == 'pyproject.toml') {
        return _parsePyprojectToml(filePath, fileName, content);
      } else if (lowerName == 'requirements.txt') {
        return _parseRequirementsTxt(filePath, fileName, content);
      }
    } catch (_) {}

    return null;
  }

  String _cleanVersion(String constraint) {
    var v = constraint.trim();
    // Strip common semver prefixes
    v = v.replaceAll(RegExp(r'^[\^~>=<]+'), '').trim();
    if (v.startsWith('v')) {
      v = v.substring(1);
    }
    // Extract first valid semver token (e.g. 1.2.3 from 1.2.3, <2.0)
    final match = RegExp(r'^\d+(\.\d+)*').firstMatch(v);
    if (match != null) {
      return match.group(0)!;
    }
    return v;
  }

  ManifestFile? _parsePackageJson(
    String path,
    String fileName,
    String content,
  ) {
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return null;

      final items = <DependencyItem>[];

      void extract(Map<String, dynamic>? deps, bool isDev) {
        if (deps == null) return;
        for (final entry in deps.entries) {
          final name = entry.key;
          final constraint = entry.value.toString().trim();
          if (name.isNotEmpty && constraint.isNotEmpty) {
            items.add(
              DependencyItem(
                name: name,
                currentConstraint: constraint,
                cleanCurrentVersion: _cleanVersion(constraint),
                isDev: isDev,
                manifestPath: path,
                ecosystem: Ecosystem.node,
                packageUrl: 'https://www.npmjs.com/package/$name',
              ),
            );
          }
        }
      }

      extract(data['dependencies'] as Map<String, dynamic>?, false);
      extract(data['devDependencies'] as Map<String, dynamic>?, true);

      return ManifestFile(
        path: path,
        fileName: fileName,
        ecosystem: Ecosystem.node,
        dependencies: items,
      );
    } catch (_) {
      return null;
    }
  }

  ManifestFile? _parsePubspecYaml(
    String path,
    String fileName,
    String content,
  ) {
    final lines = LineSplitter.split(content).toList();
    final items = <DependencyItem>[];

    String? currentSection;

    for (final rawLine in lines) {
      final line = rawLine.split('#').first.trimRight(); // strip comments
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (line.startsWith('dependencies:')) {
        currentSection = 'dependencies';
        continue;
      } else if (line.startsWith('dev_dependencies:')) {
        currentSection = 'dev_dependencies';
        continue;
      } else if (!line.startsWith(' ') && !line.startsWith('\t') && line.endsWith(':')) {
        currentSection = null;
        continue;
      }

      if (currentSection != null && (line.startsWith('  ') || line.startsWith('\t'))) {
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx != -1) {
          final pkg = trimmed.substring(0, colonIdx).trim();
          final val = trimmed.substring(colonIdx + 1).trim();

          // Skip SDK dependencies like flutter: sdk: flutter
          if (pkg == 'flutter' || pkg == 'flutter_test' || pkg == 'flutter_driver') {
            continue;
          }
          if (val == 'sdk' || val.startsWith('sdk:')) continue;

          var constraint = val;
          if (constraint.startsWith('^') ||
              constraint.startsWith('>') ||
              constraint.startsWith('~') ||
              RegExp(r'^\d').hasMatch(constraint)) {
            items.add(
              DependencyItem(
                name: pkg,
                currentConstraint: constraint,
                cleanCurrentVersion: _cleanVersion(constraint),
                isDev: currentSection == 'dev_dependencies',
                manifestPath: path,
                ecosystem: Ecosystem.flutter,
                packageUrl: 'https://pub.dev/packages/$pkg',
              ),
            );
          }
        }
      }
    }

    return ManifestFile(
      path: path,
      fileName: fileName,
      ecosystem: Ecosystem.flutter,
      dependencies: items,
    );
  }

  ManifestFile? _parseGoMod(
    String path,
    String fileName,
    String content,
  ) {
    final lines = LineSplitter.split(content).toList();
    final items = <DependencyItem>[];
    bool inRequireBlock = false;

    for (final rawLine in lines) {
      final line = rawLine.split('//').first.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('require (')) {
        inRequireBlock = true;
        continue;
      } else if (inRequireBlock && line == ')') {
        inRequireBlock = false;
        continue;
      }

      if (inRequireBlock || line.startsWith('require ')) {
        final effective = line.startsWith('require ')
            ? line.substring(8).trim()
            : line;
        final parts = effective.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final mod = parts[0];
          final ver = parts[1];
          items.add(
            DependencyItem(
              name: mod,
              currentConstraint: ver,
              cleanCurrentVersion: _cleanVersion(ver),
              isDev: false,
              manifestPath: path,
              ecosystem: Ecosystem.go,
              packageUrl: 'https://pkg.go.dev/$mod',
            ),
          );
        }
      }
    }

    return ManifestFile(
      path: path,
      fileName: fileName,
      ecosystem: Ecosystem.go,
      dependencies: items,
    );
  }

  ManifestFile? _parseCargoToml(
    String path,
    String fileName,
    String content,
  ) {
    final lines = LineSplitter.split(content).toList();
    final items = <DependencyItem>[];
    String? currentSection;

    for (final rawLine in lines) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        final sec = line.substring(1, line.length - 1).trim();
        if (sec == 'dependencies' || sec.endsWith('.dependencies')) {
          currentSection = 'dependencies';
        } else if (sec == 'dev-dependencies' || sec.endsWith('.dev-dependencies')) {
          currentSection = 'dev-dependencies';
        } else {
          currentSection = null;
        }
        continue;
      }

      if (currentSection != null && line.contains('=')) {
        final eqIdx = line.indexOf('=');
        final pkg = line.substring(0, eqIdx).trim();
        final val = line.substring(eqIdx + 1).trim();

        String? version;
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          version = val.substring(1, val.length - 1);
        } else if (val.startsWith('{')) {
          final match = RegExp(r'version\s*=\s*"([^"]+)"').firstMatch(val);
          if (match != null) {
            version = match.group(1);
          }
        }

        if (pkg.isNotEmpty && version != null && version.isNotEmpty) {
          items.add(
            DependencyItem(
              name: pkg,
              currentConstraint: version,
              cleanCurrentVersion: _cleanVersion(version),
              isDev: currentSection == 'dev-dependencies',
              manifestPath: path,
              ecosystem: Ecosystem.rust,
              packageUrl: 'https://crates.io/crates/$pkg',
            ),
          );
        }
      }
    }

    return ManifestFile(
      path: path,
      fileName: fileName,
      ecosystem: Ecosystem.rust,
      dependencies: items,
    );
  }

  ManifestFile? _parsePyprojectToml(
    String path,
    String fileName,
    String content,
  ) {
    final lines = LineSplitter.split(content).toList();
    final items = <DependencyItem>[];
    bool inDependenciesList = false;
    bool inPoetryDependencies = false;

    for (final rawLine in lines) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[project]') || line.startsWith('[tool.poetry.dependencies]')) {
        inPoetryDependencies = line.startsWith('[tool.poetry.dependencies]');
      } else if (line.startsWith('dependencies = [')) {
        inDependenciesList = true;
        continue;
      } else if (inDependenciesList && line.contains(']')) {
        inDependenciesList = false;
      }

      if (inDependenciesList) {
        final match = RegExp('["\']([^"\']+)["\']').firstMatch(line);
        if (match != null) {
          final depStr = match.group(1)!;
          final parsed = _parsePythonDep(depStr, path);
          if (parsed != null) items.add(parsed);
        }
      } else if (inPoetryDependencies && line.contains('=')) {
        final parts = line.split('=');
        final pkg = parts[0].trim();
        final val = parts[1].trim().replaceAll('"', '').replaceAll("'", '');
        if (pkg != 'python' && pkg.isNotEmpty && val.isNotEmpty) {
          items.add(
            DependencyItem(
              name: pkg,
              currentConstraint: val,
              cleanCurrentVersion: _cleanVersion(val),
              isDev: false,
              manifestPath: path,
              ecosystem: Ecosystem.python,
              packageUrl: 'https://pypi.org/project/$pkg/',
            ),
          );
        }
      }
    }

    return ManifestFile(
      path: path,
      fileName: fileName,
      ecosystem: Ecosystem.python,
      dependencies: items,
    );
  }

  ManifestFile? _parseRequirementsTxt(
    String path,
    String fileName,
    String content,
  ) {
    final lines = LineSplitter.split(content).toList();
    final items = <DependencyItem>[];

    for (final rawLine in lines) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty || line.startsWith('-')) continue;

      final parsed = _parsePythonDep(line, path);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    return ManifestFile(
      path: path,
      fileName: fileName,
      ecosystem: Ecosystem.python,
      dependencies: items,
    );
  }

  DependencyItem? _parsePythonDep(String depStr, String manifestPath) {
    final opMatch = RegExp(r'([=><~^!]+)').firstMatch(depStr);
    if (opMatch != null) {
      final pkg = depStr.substring(0, opMatch.start).trim();
      final constraint = depStr.substring(opMatch.start).trim();
      if (pkg.isNotEmpty) {
        return DependencyItem(
          name: pkg,
          currentConstraint: constraint,
          cleanCurrentVersion: _cleanVersion(constraint),
          isDev: false,
          manifestPath: manifestPath,
          ecosystem: Ecosystem.python,
          packageUrl: 'https://pypi.org/project/$pkg/',
        );
      }
    } else {
      final pkg = depStr.trim();
      if (pkg.isNotEmpty && RegExp(r'^[a-zA-Z0-9_\-\.]+').hasMatch(pkg)) {
        return DependencyItem(
          name: pkg,
          currentConstraint: '*',
          cleanCurrentVersion: '*',
          isDev: false,
          manifestPath: manifestPath,
          ecosystem: Ecosystem.python,
          packageUrl: 'https://pypi.org/project/$pkg/',
        );
      }
    }
    return null;
  }
}
