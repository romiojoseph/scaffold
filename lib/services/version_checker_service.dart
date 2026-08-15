import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/dependency_info.dart';

class _CachedPackageData {
  final String version;
  final DateTime? publishedAt;
  final String? description;
  final String? repositoryUrl;
  final String? changelogUrl;
  final String? license;
  final List<String> vulnerabilityIds;
  final String? vulnerabilitySummary;
  final DateTime lastChecked;

  const _CachedPackageData({
    required this.version,
    this.publishedAt,
    this.description,
    this.repositoryUrl,
    this.changelogUrl,
    this.license,
    this.vulnerabilityIds = const [],
    this.vulnerabilitySummary,
    required this.lastChecked,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'publishedAt': publishedAt?.toIso8601String(),
        'description': description,
        'repositoryUrl': repositoryUrl,
        'changelogUrl': changelogUrl,
        'license': license,
        'vulnerabilityIds': vulnerabilityIds,
        'vulnerabilitySummary': vulnerabilitySummary,
        'lastChecked': lastChecked.toIso8601String(),
      };

  factory _CachedPackageData.fromJson(Map<String, dynamic> json) {
    return _CachedPackageData(
      version: json['version']?.toString() ?? '',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      description: json['description']?.toString(),
      repositoryUrl: json['repositoryUrl']?.toString(),
      changelogUrl: json['changelogUrl']?.toString(),
      license: json['license']?.toString(),
      vulnerabilityIds: (json['vulnerabilityIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      vulnerabilitySummary: json['vulnerabilitySummary']?.toString(),
      lastChecked: json['lastChecked'] != null
          ? (DateTime.tryParse(json['lastChecked'].toString()) ?? DateTime.now())
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isExpired {
    return DateTime.now().difference(lastChecked) >= const Duration(hours: 24);
  }
}

class VersionCheckerService {
  final HttpClient _client;
  static final Map<String, _CachedPackageData> _persistentCache = {};
  static bool _hasLoadedCacheFromDisk = false;
  static File? _cacheFile;

  VersionCheckerService({HttpClient? client})
      : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 6));

  void dispose() {
    _client.close(force: true);
  }

  static Future<void> _ensureCacheLoaded() async {
    if (_hasLoadedCacheFromDisk) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File('${dir.path}${Platform.pathSeparator}registry_cache.json');
      if (await _cacheFile!.exists()) {
        final raw = await _cacheFile!.readAsString();
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          for (final entry in data.entries) {
            if (entry.value is Map<String, dynamic>) {
              _persistentCache[entry.key] =
                  _CachedPackageData.fromJson(entry.value as Map<String, dynamic>);
            }
          }
        }
      }
    } catch (_) {}
    _hasLoadedCacheFromDisk = true;
  }

  static Future<void> _saveCacheToDisk() async {
    if (_cacheFile == null) {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File('${dir.path}${Platform.pathSeparator}registry_cache.json');
    }
    try {
      final jsonMap = _persistentCache.map((k, v) => MapEntry(k, v.toJson()));
      await _cacheFile!.writeAsString(jsonEncode(jsonMap), flush: true);
    } catch (_) {}
  }

  /// Checks a list of dependencies with bounded concurrency and 24-hour persistent cache.
  /// If [forceRefresh] is false, packages checked within the last 24h will resolve immediately from cache.
  Future<List<DependencyItem>> checkDependencies(
    List<DependencyItem> items, {
    void Function(int completed, int total, DependencyItem current)? onProgress,
    int concurrency = 6,
    bool forceRefresh = false,
  }) async {
    await _ensureCacheLoaded();

    final results = List<DependencyItem>.from(items);
    int completedCount = 0;

    final queue = List<int>.generate(items.length, (i) => i);
    final activeFutures = <Future<void>>[];
    bool cacheModified = false;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final index = queue.removeAt(0);
        final item = items[index];

        final updated = await _checkSingleItem(item, forceRefresh: forceRefresh);
        results[index] = updated;

        cacheModified = true;
        completedCount++;
        onProgress?.call(completedCount, items.length, updated);
      }
    }

    final workerCount = mathMin(concurrency, items.length);
    for (int i = 0; i < workerCount; i++) {
      activeFutures.add(worker());
    }

    await Future.wait(activeFutures);

    if (cacheModified) {
      _saveCacheToDisk();
    }

    return results;
  }

  int mathMin(int a, int b) => a < b ? a : b;

  Future<DependencyItem> _checkSingleItem(
    DependencyItem item, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${item.ecosystem.name}:${item.name}:${item.cleanCurrentVersion ?? ""}';
    final cached = _persistentCache[cacheKey];

    // If cache exists and is fresh (< 24 hours old) and not forced, return immediately
    if (cached != null && !cached.isExpired && !forceRefresh) {
      final isOutdated = _isOutdated(item.cleanCurrentVersion, cached.version);
      return item.copyWith(
        latestVersion: cached.version,
        latestPublishedAt: cached.publishedAt,
        description: cached.description,
        repositoryUrl: cached.repositoryUrl,
        changelogUrl: cached.changelogUrl,
        license: cached.license,
        status: isOutdated ? DependencyStatus.outdated : DependencyStatus.upToDate,
        vulnerabilityIds: cached.vulnerabilityIds,
        vulnerabilitySummary: cached.vulnerabilitySummary,
      );
    }

    // Otherwise, fetch fresh info from package registry and OSV
    _CachedPackageData? freshInfo;
    try {
      freshInfo = await _fetchFromRegistryAndOsv(item);
      if (freshInfo != null) {
        _persistentCache[cacheKey] = freshInfo;
      }
    } catch (_) {}

    if (freshInfo != null && freshInfo.version.isNotEmpty) {
      final isOutdated = _isOutdated(item.cleanCurrentVersion, freshInfo.version);
      return item.copyWith(
        latestVersion: freshInfo.version,
        latestPublishedAt: freshInfo.publishedAt,
        description: freshInfo.description,
        repositoryUrl: freshInfo.repositoryUrl,
        changelogUrl: freshInfo.changelogUrl,
        license: freshInfo.license,
        status: isOutdated ? DependencyStatus.outdated : DependencyStatus.upToDate,
        vulnerabilityIds: freshInfo.vulnerabilityIds,
        vulnerabilitySummary: freshInfo.vulnerabilitySummary,
      );
    } else {
      return item.copyWith(
        status: DependencyStatus.error,
        errorMessage: 'Not found or private package',
      );
    }
  }

  Future<_CachedPackageData?> _fetchFromRegistryAndOsv(DependencyItem item) async {
    final regData = await _fetchLatestVersionAndDate(item.ecosystem, item.name);
    if (regData == null) return null;

    List<String> vulns = const [];
    String? vulnSummary;

    if (item.cleanCurrentVersion != null && item.cleanCurrentVersion != '*') {
      try {
        final vulnResult = await _checkOsvVulnerabilities(item);
        vulns = vulnResult.$1;
        vulnSummary = vulnResult.$2;
      } catch (_) {}
    }

    return _CachedPackageData(
      version: regData.$1,
      publishedAt: regData.$2,
      description: regData.$3,
      repositoryUrl: regData.$4,
      changelogUrl: regData.$5,
      license: regData.$6,
      vulnerabilityIds: vulns,
      vulnerabilitySummary: vulnSummary,
      lastChecked: DateTime.now(),
    );
  }

  Future<(String, DateTime?, String?, String?, String?, String?)?>
      _fetchLatestVersionAndDate(
    Ecosystem ecosystem,
    String packageName,
  ) async {
    final Uri url;
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'User-Agent': 'FolderWindowsApp/1.0 (https://github.com/romiojoseph/folder-windows-app)',
    };

    switch (ecosystem) {
      case Ecosystem.node:
        final encodedName = packageName.startsWith('@')
            ? '@${Uri.encodeComponent(packageName.substring(1))}'
            : Uri.encodeComponent(packageName);
        url = Uri.parse('https://registry.npmjs.org/$encodedName');
        break;

      case Ecosystem.python:
        url = Uri.parse('https://pypi.org/pypi/${Uri.encodeComponent(packageName)}/json');
        break;

      case Ecosystem.flutter:
        url = Uri.parse('https://pub.dev/api/packages/${Uri.encodeComponent(packageName)}');
        break;

      case Ecosystem.go:
        final encodedModule = _encodeGoModulePath(packageName);
        url = Uri.parse('https://proxy.golang.org/$encodedModule/@latest');
        break;

      case Ecosystem.rust:
        url = Uri.parse('https://crates.io/api/v1/crates/${Uri.encodeComponent(packageName)}');
        break;
    }

    final request = await _client.getUrl(url);
    headers.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close().timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      switch (ecosystem) {
        case Ecosystem.node:
          if (data is Map) {
            final distTags = data['dist-tags'] as Map?;
            final latest = distTags?['latest']?.toString() ?? data['version']?.toString();
            DateTime? pubDate;
            if (latest != null && data['time'] is Map) {
              final timeStr = data['time'][latest]?.toString();
              if (timeStr != null) pubDate = DateTime.tryParse(timeStr);
            }

            final desc = data['description']?.toString();
            String? repoUrl;
            if (data['repository'] is Map) {
              repoUrl = data['repository']['url']?.toString();
              if (repoUrl != null && repoUrl.startsWith('git+')) {
                repoUrl = repoUrl.substring(4);
              }
              if (repoUrl != null && repoUrl.endsWith('.git')) {
                repoUrl = repoUrl.substring(0, repoUrl.length - 4);
              }
            } else if (data['homepage'] != null) {
              repoUrl = data['homepage']?.toString();
            }

            final lic = data['license']?.toString();

            if (latest != null) {
              return (latest, pubDate, desc, repoUrl, null, lic);
            }
          }
          break;

        case Ecosystem.python:
          if (data is Map && data['info'] is Map) {
            final info = data['info'] as Map;
            final latest = info['version']?.toString();
            DateTime? pubDate;
            if (latest != null && data['releases'] is Map && data['releases'][latest] is List) {
              final releaseList = data['releases'][latest] as List;
              if (releaseList.isNotEmpty && releaseList.first is Map) {
                final uploadTime = releaseList.first['upload_time_iso_8601']?.toString();
                if (uploadTime != null) pubDate = DateTime.tryParse(uploadTime);
              }
            }

            final desc = info['summary']?.toString();
            String? repoUrl = info['home_page']?.toString();
            String? changelog;
            if (info['project_urls'] is Map) {
              final urls = info['project_urls'] as Map;
              changelog = urls['Changelog']?.toString() ??
                  urls['Release Notes']?.toString() ??
                  urls['Changes']?.toString();
              repoUrl ??= urls['Source']?.toString() ??
                  urls['Repository']?.toString() ??
                  urls['GitHub']?.toString();
            }

            final lic = info['license']?.toString();

            if (latest != null) {
              return (latest, pubDate, desc, repoUrl, changelog, lic);
            }
          }
          break;

        case Ecosystem.flutter:
          if (data is Map && data['latest'] is Map) {
            final latestMap = data['latest'] as Map;
            final latest = latestMap['version']?.toString();
            DateTime? pubDate;
            final pubStr = latestMap['published']?.toString();
            if (pubStr != null) pubDate = DateTime.tryParse(pubStr);

            String? desc;
            String? repoUrl;
            if (latestMap['pubspec'] is Map) {
              final pubspec = latestMap['pubspec'] as Map;
              desc = pubspec['description']?.toString();
              repoUrl = pubspec['repository']?.toString() ?? pubspec['homepage']?.toString();
            }

            final changelog = 'https://pub.dev/packages/$packageName/changelog';

            if (latest != null) {
              return (latest, pubDate, desc, repoUrl, changelog, null);
            }
          }
          break;

        case Ecosystem.go:
          if (data is Map && data['Version'] != null) {
            var v = data['Version']?.toString() ?? '';
            if (v.startsWith('v')) v = v.substring(1);
            DateTime? pubDate;
            final timeStr = data['Time']?.toString();
            if (timeStr != null) pubDate = DateTime.tryParse(timeStr);

            final repoUrl = packageName.startsWith('github.com/') ? 'https://$packageName' : null;

            return (v, pubDate, null, repoUrl, null, null);
          }
          break;

        case Ecosystem.rust:
          if (data is Map && data['crate'] is Map) {
            final crateMap = data['crate'] as Map;
            final latest = crateMap['max_version']?.toString();
            DateTime? pubDate;
            final updStr = crateMap['updated_at']?.toString();
            if (updStr != null) pubDate = DateTime.tryParse(updStr);

            final desc = crateMap['description']?.toString();
            final repoUrl = crateMap['repository']?.toString() ?? crateMap['documentation']?.toString();

            if (latest != null) {
              return (latest, pubDate, desc, repoUrl, null, null);
            }
          }
          break;
      }
    }
    return null;
  }

  Future<(List<String>, String?)> _checkOsvVulnerabilities(DependencyItem item) async {
    try {
      final url = Uri.parse('https://api.osv.dev/v1/query');
      final request = await _client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');

      final body = jsonEncode({
        'version': item.cleanCurrentVersion,
        'package': {
          'name': item.name,
          'ecosystem': item.ecosystem.osvEcosystem,
        },
      });

      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final resBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(resBody);

        if (data is Map && data['vulns'] is List) {
          final vulnList = data['vulns'] as List;
          final ids = <String>{};
          String? summary;

          for (final v in vulnList) {
            if (v is Map) {
              final id = v['id']?.toString();
              if (id != null) ids.add(id);

              final aliases = v['aliases'] as List?;
              if (aliases != null) {
                for (final a in aliases) {
                  if (a != null) ids.add(a.toString());
                }
              }

              if (summary == null && v['summary'] != null) {
                summary = v['summary'].toString();
              }
            }
          }

          return (ids.toList(), summary);
        }
      }
    } catch (_) {}

    return (const <String>[], null);
  }

  String _encodeGoModulePath(String path) {
    final sb = StringBuffer();
    for (int i = 0; i < path.length; i++) {
      final ch = path[i];
      if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
        sb.write('!${ch.toLowerCase()}');
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

  bool _isOutdated(String? currentConstraint, String latest) {
    if (currentConstraint == null || currentConstraint.isEmpty || currentConstraint == '*') {
      return false;
    }

    final currentClean = _cleanSemver(currentConstraint);
    final latestClean = _cleanSemver(latest);

    if (currentClean == null || latestClean == null) {
      return false;
    }

    return _compareSemver(latestClean, currentClean) > 0;
  }

  List<int>? _cleanSemver(String raw) {
    var str = raw.trim().replaceAll(RegExp(r'^[\^~>=<v]+'), '').trim();
    final parts = str.split('.').map((p) => int.tryParse(RegExp(r'^\d+').firstMatch(p)?.group(0) ?? '') ?? 0).toList();
    if (parts.isEmpty) return null;
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  int _compareSemver(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      final diff = a[i].compareTo(b[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
