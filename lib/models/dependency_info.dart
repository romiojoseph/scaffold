enum Ecosystem {
  node('Node.js / JS', 'package.json', 'js'),
  python('Python', 'pyproject.toml / requirements.txt', 'py'),
  flutter('Dart / Flutter', 'pubspec.yaml', 'dart'),
  go('Go', 'go.mod', 'go'),
  rust('Rust', 'Cargo.toml', 'rs');

  final String label;
  final String manifestName;
  final String defaultExtension;
  const Ecosystem(this.label, this.manifestName, this.defaultExtension);

  String get osvEcosystem {
    switch (this) {
      case Ecosystem.node:
        return 'npm';
      case Ecosystem.python:
        return 'PyPI';
      case Ecosystem.flutter:
        return 'Pub';
      case Ecosystem.go:
        return 'Go';
      case Ecosystem.rust:
        return 'crates.io';
    }
  }
}

enum DependencyStatus {
  idle,
  checking,
  upToDate,
  outdated,
  error,
}

class DependencyItem {
  final String name;
  final String currentConstraint;
  final String? cleanCurrentVersion;
  final String? latestVersion;
  final DateTime? latestPublishedAt;
  final bool isDev;
  final String manifestPath;
  final Ecosystem ecosystem;
  final DependencyStatus status;
  final String? packageUrl;
  final String? repositoryUrl;
  final String? changelogUrl;
  final String? license;
  final String? description;
  final String? errorMessage;
  final List<String> vulnerabilityIds;
  final String? vulnerabilitySummary;

  const DependencyItem({
    required this.name,
    required this.currentConstraint,
    this.cleanCurrentVersion,
    this.latestVersion,
    this.latestPublishedAt,
    this.isDev = false,
    required this.manifestPath,
    required this.ecosystem,
    this.status = DependencyStatus.idle,
    this.packageUrl,
    this.repositoryUrl,
    this.changelogUrl,
    this.license,
    this.description,
    this.errorMessage,
    this.vulnerabilityIds = const [],
    this.vulnerabilitySummary,
  });

  bool get isOutdated => status == DependencyStatus.outdated;
  bool get hasVulnerabilities => vulnerabilityIds.isNotEmpty;

  String get cliUpgradeCommand {
    switch (ecosystem) {
      case Ecosystem.node:
        return isDev ? 'npm i -D $name@latest' : 'npm i $name@latest';
      case Ecosystem.python:
        return 'pip install -U $name';
      case Ecosystem.flutter:
        return 'flutter pub upgrade $name';
      case Ecosystem.go:
        return 'go get $name@latest';
      case Ecosystem.rust:
        return 'cargo update -p $name';
    }
  }

  DependencyItem copyWith({
    String? name,
    String? currentConstraint,
    String? cleanCurrentVersion,
    String? latestVersion,
    DateTime? latestPublishedAt,
    bool? isDev,
    String? manifestPath,
    Ecosystem? ecosystem,
    DependencyStatus? status,
    String? packageUrl,
    String? repositoryUrl,
    String? changelogUrl,
    String? license,
    String? description,
    String? errorMessage,
    List<String>? vulnerabilityIds,
    String? vulnerabilitySummary,
  }) {
    return DependencyItem(
      name: name ?? this.name,
      currentConstraint: currentConstraint ?? this.currentConstraint,
      cleanCurrentVersion: cleanCurrentVersion ?? this.cleanCurrentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      latestPublishedAt: latestPublishedAt ?? this.latestPublishedAt,
      isDev: isDev ?? this.isDev,
      manifestPath: manifestPath ?? this.manifestPath,
      ecosystem: ecosystem ?? this.ecosystem,
      status: status ?? this.status,
      packageUrl: packageUrl ?? this.packageUrl,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      changelogUrl: changelogUrl ?? this.changelogUrl,
      license: license ?? this.license,
      description: description ?? this.description,
      errorMessage: errorMessage ?? this.errorMessage,
      vulnerabilityIds: vulnerabilityIds ?? this.vulnerabilityIds,
      vulnerabilitySummary: vulnerabilitySummary ?? this.vulnerabilitySummary,
    );
  }
}

class ManifestFile {
  final String path;
  final String fileName;
  final Ecosystem ecosystem;
  final List<DependencyItem> dependencies;

  const ManifestFile({
    required this.path,
    required this.fileName,
    required this.ecosystem,
    required this.dependencies,
  });

  int get totalDependencies => dependencies.length;
  int get outdatedCount => dependencies.where((d) => d.isOutdated).length;
  int get vulnerableCount => dependencies.where((d) => d.hasVulnerabilities).length;
  int get upToDateCount =>
      dependencies.where((d) => d.status == DependencyStatus.upToDate).length;

  String get batchUpgradeCommand {
    final outdated = dependencies.where((d) => d.isOutdated).toList();
    if (outdated.isEmpty) return '';

    switch (ecosystem) {
      case Ecosystem.node:
        final prod = outdated.where((d) => !d.isDev).map((d) => '${d.name}@latest').join(' ');
        final dev = outdated.where((d) => d.isDev).map((d) => '${d.name}@latest').join(' ');
        final commands = <String>[];
        if (prod.isNotEmpty) commands.add('npm i $prod');
        if (dev.isNotEmpty) commands.add('npm i -D $dev');
        return commands.join(' && ');

      case Ecosystem.python:
        return 'pip install -U ${outdated.map((d) => d.name).join(' ')}';

      case Ecosystem.flutter:
        return 'flutter pub upgrade ${outdated.map((d) => d.name).join(' ')}';

      case Ecosystem.go:
        return outdated.map((d) => 'go get ${d.name}@latest').join(' && ');

      case Ecosystem.rust:
        return 'cargo update ${outdated.map((d) => '-p ${d.name}').join(' ')}';
    }
  }
}
