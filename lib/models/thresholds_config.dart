import 'dart:convert';
import 'dart:io';

class ThresholdsConfig {
  // Default line threshold per file extension
  static const Map<String, int> defaultThresholds = {
    'dart': 300,
    'js': 300,
    'ts': 300,
    'jsx': 250,
    'tsx': 250,
    'py': 300,
    'java': 400,
    'c': 400,
    'cpp': 400,
    'h': 200,
    'cs': 400,
    'go': 350,
    'rs': 350,
    'kt': 300,
    'swift': 300,
    'html': 500,
    'css': 400,
    'scss': 400,
    'json': 1000,
    'yaml': 200,
    'yml': 200,
    'xml': 500,
    'md': 500,
    'sh': 200,
    'ps1': 200,
  };

  static const int fallbackThreshold = 300;

  final Map<String, int> thresholds; // extension -> max lines

  ThresholdsConfig({required this.thresholds});

  factory ThresholdsConfig.defaults() {
    return ThresholdsConfig(thresholds: Map.from(defaultThresholds));
  }

  int getThreshold(String rawExtension) {
    final cleanExt = rawExtension.toLowerCase().replaceAll('.', '');
    return thresholds[cleanExt] ?? fallbackThreshold;
  }

  static Future<ThresholdsConfig> loadFromFile(File configFile) async {
    try {
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final map = (data['thresholds'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key.toLowerCase(), (value as num).toInt()),
            ) ??
            Map.from(defaultThresholds);
        return ThresholdsConfig(thresholds: map);
      }
    } catch (_) {}
    return ThresholdsConfig.defaults();
  }

  Future<void> saveToFile(File configFile) async {
    final data = {
      'thresholds': thresholds,
    };
    const encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString(encoder.convert(data));
  }

  ThresholdsConfig copyWith({Map<String, int>? thresholds}) {
    return ThresholdsConfig(
      thresholds: thresholds ?? Map.from(this.thresholds),
    );
  }
}
