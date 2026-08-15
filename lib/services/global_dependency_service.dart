import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/dependency_info.dart';

class ProjectDependencyEntry {
  final String projectName;
  final String projectPath;
  final String manifestRelativePath;
  final String currentConstraint;
  final String? cleanCurrentVersion;
  final bool isDev;

  const ProjectDependencyEntry({
    required this.projectName,
    required this.projectPath,
    required this.manifestRelativePath,
    required this.currentConstraint,
    this.cleanCurrentVersion,
    this.isDev = false,
  });

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'projectPath': projectPath,
        'manifestRelativePath': manifestRelativePath,
        'currentConstraint': currentConstraint,
        'cleanCurrentVersion': cleanCurrentVersion,
        'isDev': isDev,
      };

  factory ProjectDependencyEntry.fromJson(Map<String, dynamic> json) {
    return ProjectDependencyEntry(
      projectName: json['projectName']?.toString() ?? '',
      projectPath: json['projectPath']?.toString() ?? '',
      manifestRelativePath: json['manifestRelativePath']?.toString() ?? '',
      currentConstraint: json['currentConstraint']?.toString() ?? '',
      cleanCurrentVersion: json['cleanCurrentVersion']?.toString(),
      isDev: json['isDev'] as bool? ?? false,
    );
  }
}

class GlobalPackageGroup {
  final String name;
  final Ecosystem ecosystem;
  final List<ProjectDependencyEntry> usages;
  String? latestVersion;
  DateTime? latestPublishedAt;
  String? description;
  String? repositoryUrl;
  String? changelogUrl;
  String? license;
  List<String> vulnerabilityIds;
  String? vulnerabilitySummary;

  GlobalPackageGroup({
    required this.name,
    required this.ecosystem,
    required this.usages,
    this.latestVersion,
    this.latestPublishedAt,
    this.description,
    this.repositoryUrl,
    this.changelogUrl,
    this.license,
    this.vulnerabilityIds = const [],
    this.vulnerabilitySummary,
  });

  int get projectCount => usages.map((u) => u.projectPath).toSet().length;

  bool get hasVersionDivergence {
    final versions = usages
        .map((u) => u.cleanCurrentVersion ?? u.currentConstraint)
        .where((v) => v.isNotEmpty)
        .toSet();
    return versions.length > 1;
  }

  bool get hasVulnerabilities => vulnerabilityIds.isNotEmpty;

  int get outdatedUsagesCount {
    if (latestVersion == null) return 0;
    int count = 0;
    for (final u in usages) {
      if (_isOutdated(u.cleanCurrentVersion, latestVersion!)) {
        count++;
      }
    }
    return count;
  }

  static bool _isOutdated(String? currentConstraint, String latest) {
    if (currentConstraint == null || currentConstraint.isEmpty || currentConstraint == '*') {
      return false;
    }
    final currentClean = _cleanSemver(currentConstraint);
    final latestClean = _cleanSemver(latest);
    if (currentClean == null || latestClean == null) return false;
    for (int i = 0; i < 3; i++) {
      final diff = latestClean[i].compareTo(currentClean[i]);
      if (diff != 0) return diff > 0;
    }
    return false;
  }

  static List<int>? _cleanSemver(String raw) {
    var str = raw.trim().replaceAll(RegExp(r'^[\^~>=<v]+'), '').trim();
    final parts = str
        .split('.')
        .map((p) => int.tryParse(RegExp(r'^\d+').firstMatch(p)?.group(0) ?? '') ?? 0)
        .toList();
    if (parts.isEmpty) return null;
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}

class StoredProjectManifest {
  final String projectPath;
  final String projectName;
  final DateTime lastScanned;
  final List<ManifestFile> manifests;

  const StoredProjectManifest({
    required this.projectPath,
    required this.projectName,
    required this.lastScanned,
    required this.manifests,
  });
}

class GlobalDependencyService {
  static GlobalDependencyService? _instance;
  GlobalDependencyService._();
  factory GlobalDependencyService() => _instance ??= GlobalDependencyService._();

  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationSupportDirectory();
    _cachedFile = File('${dir.path}${Platform.pathSeparator}global_dependencies.json');
    return _cachedFile!;
  }

  Future<Map<String, dynamic>> _readRawData() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {'projects': <String, dynamic>{}};
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {'projects': <String, dynamic>{}};
  }

  Future<void> saveProject(String projectPath, List<ManifestFile> manifests) async {
    if (projectPath.isEmpty || manifests.isEmpty) return;

    final projectName = projectPath.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final file = await _getFile();
    final data = await _readRawData();

    final projectsMap = (data['projects'] as Map<String, dynamic>?) ?? {};

    final manifestList = manifests.map((m) {
      return {
        'path': m.path,
        'fileName': m.fileName,
        'ecosystem': m.ecosystem.name,
        'dependencies': m.dependencies.map((d) {
          return {
            'name': d.name,
            'currentConstraint': d.currentConstraint,
            'cleanCurrentVersion': d.cleanCurrentVersion,
            'isDev': d.isDev,
          };
        }).toList(),
      };
    }).toList();

    projectsMap[projectPath] = {
      'projectName': projectName,
      'projectPath': projectPath,
      'lastScanned': DateTime.now().toIso8601String(),
      'manifests': manifestList,
    };

    data['projects'] = projectsMap;

    try {
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  Future<void> removeProject(String projectPath) async {
    final file = await _getFile();
    final data = await _readRawData();
    final projectsMap = (data['projects'] as Map<String, dynamic>?) ?? {};
    if (projectsMap.containsKey(projectPath)) {
      projectsMap.remove(projectPath);
      data['projects'] = projectsMap;
      try {
        await file.writeAsString(jsonEncode(data), flush: true);
      } catch (_) {}
    }
  }

  Future<void> clearAll() async {
    final file = await _getFile();
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<List<GlobalPackageGroup>> getGlobalPackageCatalog() async {
    final data = await _readRawData();
    final projectsMap = (data['projects'] as Map<String, dynamic>?) ?? {};

    final Map<String, GlobalPackageGroup> catalog = {};

    for (final entry in projectsMap.entries) {
      final pData = entry.value as Map<String, dynamic>?;
      if (pData == null) continue;

      final pName = pData['projectName']?.toString() ?? '';
      final pPath = pData['projectPath']?.toString() ?? '';
      final manifests = (pData['manifests'] as List?) ?? [];

      for (final m in manifests) {
        if (m is! Map) continue;
        final ecoStr = m['ecosystem']?.toString() ?? '';
        final eco = Ecosystem.values.firstWhere(
          (e) => e.name == ecoStr,
          orElse: () => Ecosystem.node,
        );
        final manifestPath = m['path']?.toString() ?? '';
        var manifestRel = manifestPath;
        if (manifestPath.startsWith(pPath)) {
          manifestRel = manifestPath.substring(pPath.length);
          while (manifestRel.startsWith('/') || manifestRel.startsWith('\\')) {
            manifestRel = manifestRel.substring(1);
          }
        }

        final deps = (m['dependencies'] as List?) ?? [];
        for (final d in deps) {
          if (d is! Map) continue;
          final name = d['name']?.toString() ?? '';
          final constraint = d['currentConstraint']?.toString() ?? '';
          final cleanVer = d['cleanCurrentVersion']?.toString();
          final isDev = d['isDev'] as bool? ?? false;

          if (name.isEmpty) continue;

          final groupKey = '${eco.name}:$name';
          final usage = ProjectDependencyEntry(
            projectName: pName,
            projectPath: pPath,
            manifestRelativePath: manifestRel,
            currentConstraint: constraint,
            cleanCurrentVersion: cleanVer,
            isDev: isDev,
          );

          if (!catalog.containsKey(groupKey)) {
            catalog[groupKey] = GlobalPackageGroup(
              name: name,
              ecosystem: eco,
              usages: [usage],
            );
          } else {
            catalog[groupKey]!.usages.add(usage);
          }
        }
      }
    }

    final list = catalog.values.toList();
    list.sort((a, b) => b.projectCount.compareTo(a.projectCount));
    return list;
  }

  Future<int> getProjectCount() async {
    final data = await _readRawData();
    final projectsMap = (data['projects'] as Map<String, dynamic>?) ?? {};
    return projectsMap.length;
  }
}
