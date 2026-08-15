import 'dart:convert';
import 'dart:io';

class ExclusionsConfig {
  static const List<String> defaultExclusions = [
    'node_modules',
    '.git',
    '.vscode',
    '.idea',
    'bin',
    'obj',
    'dist',
    'build',
    '.next',
    '*.log',
    '*.tmp',
    '.DS_Store',
    'Thumbs.db',
  ];

  static const Map<String, List<String>> presetTemplates = {
    'General': [
      '.git',
      '.vscode',
      '.idea',
      '*.log',
      '*.tmp',
      '.DS_Store',
      'Thumbs.db',
    ],
    'Web': [
      'node_modules',
      '.next',
      '.nuxt',
      '.astro',
      '.svelte-kit',
      'dist',
      'build',
      '.turbo',
      '.vercel',
      '.output',
      'bun.lockb',
      'npm-debug.log*',
    ],
    'Flutter': [
      '.dart_tool',
      '.flutter-plugins*',
      'build',
      '.pub-cache',
      'ephemeral',
    ],
    'Python': [
      '__pycache__',
      '*.pyc',
      '.venv',
      'venv',
      '.pytest_cache',
      '*.egg-info',
    ],
    'Rust': ['target', 'Cargo.lock'],
    'Go': ['vendor', 'bin', '*.exe', '*.test', '*.out'],
    'Kotlin': ['.gradle', 'build', 'out', 'target', '*.class', '.mvn'],
    'Docker': ['*.log', '.dockerignore'],
  };
  final List<String> patterns;
  final bool enabled;
  final bool gitignoreOnly;
  final List<String> gitignorePatterns;

  ExclusionsConfig({
    required this.patterns,
    this.enabled = true,
    this.gitignoreOnly = false,
    this.gitignorePatterns = const [],
  });

  factory ExclusionsConfig.defaults() {
    return ExclusionsConfig(patterns: List.from(defaultExclusions));
  }

  static Future<ExclusionsConfig> loadFromFile(File configFile) async {
    try {
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final list =
            (data['exclusions'] as List<dynamic>?)
                ?.map((e) => e.toString().replaceAll('\\', '/'))
                .toList() ??
            List.from(defaultExclusions);
        final enabled = data['enabled'] as bool? ?? true;
        final gitignoreOnly = data['gitignoreOnly'] as bool? ?? false;
        return ExclusionsConfig(
          patterns: list,
          enabled: enabled,
          gitignoreOnly: gitignoreOnly,
        );
      }
    } catch (_) {}
    return ExclusionsConfig.defaults();
  }

  Future<void> saveToFile(File configFile) async {
    final data = {
      'enabled': enabled,
      'gitignoreOnly': gitignoreOnly,
      'exclusions': patterns,
    };
    const encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString(encoder.convert(data));
  }

  /// [name] is the bare entry name (last path segment).
  /// [relativePath] is the path relative to the scan root, using forward
  /// slashes, e.g. "build/flutter_assets".  When supplied, patterns that
  /// contain a slash are matched against it in addition to the bare name.
  bool isExcluded(String name, {String? relativePath}) {
    if (gitignoreOnly) {
      if (name == '.git') return true;
      // Check gitignore patterns
      for (final pattern in gitignorePatterns) {
        if (_isFoldersOnlyPattern(pattern)) {
          continue; // handled by isFoldersOnly
        }
        if (_matchesPattern(name, pattern)) return true;
        if (relativePath != null &&
            _isPathPattern(pattern) &&
            _matchesPathPattern(relativePath, pattern)) {
          return true;
        }
      }
      // Also apply manual patterns on top of gitignore mode (if enabled)
      if (enabled) {
        for (final pattern in patterns) {
          if (_isFoldersOnlyPattern(pattern)) {
            continue; // handled by isFoldersOnly
          }
          if (_matchesPattern(name, pattern)) return true;
          if (relativePath != null &&
              _isPathPattern(pattern) &&
              _matchesPathPattern(relativePath, pattern)) {
            return true;
          }
        }
      }
      return false;
    }

    if (!enabled) return false;

    for (final pattern in patterns) {
      if (_isFoldersOnlyPattern(pattern)) continue; // handled by isFoldersOnly
      if (_matchesPattern(name, pattern)) return true;
      if (relativePath != null &&
          _isPathPattern(pattern) &&
          _matchesPathPattern(relativePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if [pattern] is a "folders-only" marker (ends with `/*`).
  /// These patterns are intentionally skipped in [isExcluded] and handled
  /// separately by [isFoldersOnly].
  static bool _isFoldersOnlyPattern(String pattern) =>
      pattern.trimRight().endsWith('/*');

  /// Returns true if the given folder's [relativePath] has a "folders only"
  /// pattern — i.e. a pattern of the form `<path>/*` or bare `*` meaning
  /// "show the folder itself but hide all its direct files".
  ///
  /// Example: pattern `assets/icons/*` matches relativePath `assets/icons`.
  bool isFoldersOnly(String relativePath) {
    if (!enabled && !gitignoreOnly) return false;

    final rp = relativePath.replaceAll('\\', '/').toLowerCase();

    bool check(String pattern) {
      var p = pattern.trim().replaceAll('\\', '/');
      if (!p.endsWith('/*')) return false;
      // Strip the trailing /*
      final base = p.substring(0, p.length - 2).toLowerCase();
      // Strip optional leading slash
      final cleanBase = base.startsWith('/') ? base.substring(1) : base;
      return cleanBase == rp;
    }

    for (final pattern in patterns) {
      if (check(pattern)) return true;
    }
    return false;
  }

  /// Returns true if the pattern contains a path separator (/ or \),
  /// meaning it should be matched against the relative path, not just the name.
  static bool _isPathPattern(String pattern) =>
      pattern.contains('/') || pattern.contains('\\');

  static List<String> parseGitignoreFile(File file) {
    try {
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        final patterns = <String>[];
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          var pattern = line;
          if (pattern.startsWith('/')) pattern = pattern.substring(1);
          if (pattern.endsWith('/')) {
            pattern = pattern.substring(0, pattern.length - 1);
          }
          if (pattern.isNotEmpty) {
            patterns.add(pattern);
          }
        }
        return patterns;
      }
    } catch (_) {}
    return [];
  }

  static final Map<String, RegExp> _patternRegexCache = {};
  static final Map<String, RegExp> _pathPatternRegexCache = {};

  /// Matches [relativePath] (e.g. "build/flutter_assets") against a
  /// path-style [pattern] (e.g. "build/flutter_assets" or "build/*").
  ///
  /// The pattern is normalised to forward slashes and may optionally start
  /// with a leading slash.  A trailing slash is treated as "directory only"
  /// but we don't enforce that here — excluding by name is sufficient.
  static bool _matchesPathPattern(String relativePath, String pattern) {
    // Normalise separators
    var p = pattern.trim().replaceAll('\\', '/');
    var rp = relativePath.replaceAll('\\', '/');

    // Strip optional leading/trailing slashes from the pattern
    if (p.startsWith('/')) p = p.substring(1);
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (p.isEmpty) return false;

    // Exact match (case-insensitive)
    if (rp.toLowerCase() == p.toLowerCase()) return true;

    // The relative path starts with the pattern (i.e. the entire pattern
    // matches a prefix segment, not just a substring of a name).
    // e.g. pattern "build/flutter_assets" should match
    // "build/flutter_assets/fonts" as well.
    final lowerRp = rp.toLowerCase();
    final lowerP = p.toLowerCase();
    if (lowerRp.startsWith('$lowerP/')) return true;

    // Wildcard support
    if (p.contains('*') || p.contains('?')) {
      final regex = _pathPatternRegexCache.putIfAbsent(p, () {
        final regexString =
            '^${RegExp.escape(p).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
        return RegExp(regexString, caseSensitive: false);
      });
      return regex.hasMatch(rp) || regex.hasMatch('$rp/');
    }

    return false;
  }

  static bool _matchesPattern(String text, String pattern) {
    var p = pattern.trim();
    if (p.isEmpty) return false;

    // Handle extension pattern like '.svg' or '.png' -> treat as '*.svg' or '*.png'
    if (p.startsWith('.') && !p.contains('*') && !p.contains('?')) {
      if (text.toLowerCase().endsWith(p.toLowerCase())) {
        return true;
      }
    }

    if (p == text) return true;
    if (p.contains('*') || p.contains('?')) {
      final regex = _patternRegexCache.putIfAbsent(p, () {
        final regexString =
            '^${RegExp.escape(p).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
        return RegExp(regexString, caseSensitive: false);
      });
      return regex.hasMatch(text);
    }
    return text.toLowerCase() == p.toLowerCase();
  }
}

