import '../models/dependency_info.dart';

/// Registry URL for a package in the given ecosystem.
String getPackageRegistryUrl(Ecosystem ecosystem, String packageName) {
  switch (ecosystem) {
    case Ecosystem.node:
      return 'https://www.npmjs.com/package/$packageName';
    case Ecosystem.python:
      return 'https://pypi.org/project/$packageName/';
    case Ecosystem.flutter:
      return 'https://pub.dev/packages/$packageName';
    case Ecosystem.go:
      return 'https://pkg.go.dev/$packageName';
    case Ecosystem.rust:
      return 'https://crates.io/crates/$packageName';
  }
}

/// CLI command that upgrades the given package in the given ecosystem.
String generateProjectUpgradeCommand(
  Ecosystem ecosystem,
  String packageName,
  bool isDev,
) {
  switch (ecosystem) {
    case Ecosystem.node:
      return isDev ? 'npm i -D $packageName@latest' : 'npm i $packageName@latest';
    case Ecosystem.python:
      return 'pip install -U $packageName';
    case Ecosystem.flutter:
      return 'flutter pub upgrade $packageName';
    case Ecosystem.go:
      return 'go get $packageName@latest';
    case Ecosystem.rust:
      return 'cargo update -p $packageName';
  }
}