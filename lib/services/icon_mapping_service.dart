import 'dart:convert';
import 'package:flutter/services.dart';

class IconMappingConfig {
  final Map<String, String> extensionToIcon; // ext -> '00.svg'
  final Map<String, String> extensionToLanguage; // ext -> 'JavaScript'
  final String defaultIcon;
  final String folderIcon;

  const IconMappingConfig({
    required this.extensionToIcon,
    required this.extensionToLanguage,
    required this.defaultIcon,
    required this.folderIcon,
  });

  static IconMappingConfig? _instance;

  static IconMappingConfig get instance {
    return _instance ??
        const IconMappingConfig(
          extensionToIcon: {},
          extensionToLanguage: {},
          defaultIcon: '404.svg',
          folderIcon: '100.svg',
        );
  }

  static Future<void> load() async {
    try {
      final jsonString = await rootBundle.loadString('assets/iconMapping.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final languageConfig = data['languageConfig'] as Map<String, dynamic>? ?? {};

      final extMap = <String, String>{};
      final langMap = <String, String>{};

      for (final entry in languageConfig.entries) {
        final langName = entry.key;
        final langData = entry.value;
        if (langData is Map<String, dynamic>) {
          final icon = langData['icon'] as String? ?? '404.svg';
          final extensions = langData['extensions'] as List<dynamic>? ?? [];
          for (final ext in extensions) {
            final cleanExt = ext.toString().toLowerCase().replaceAll('.', '');
            extMap[cleanExt] = icon;
            langMap[cleanExt] = langName;
          }
        }
      }

      _instance = IconMappingConfig(
        extensionToIcon: extMap,
        extensionToLanguage: langMap,
        defaultIcon: data['defaultIcon'] as String? ?? '404.svg',
        folderIcon: data['folderIcon'] as String? ?? '100.svg',
      );
    } catch (_) {
      // Fallback
    }
  }

  List<String> get allKnownExtensions => extensionToIcon.keys.toList()..sort();

  String getIconForExtension(String rawExtension) {
    final cleanExt = rawExtension.toLowerCase().replaceAll('.', '');
    return extensionToIcon[cleanExt] ?? defaultIcon;
  }
}
