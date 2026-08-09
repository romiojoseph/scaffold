import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/fs_node.dart';

class ExportService {
  static Future<File> exportToJson({
    required String rootPath,
    required List<String> excludedPatterns,
    required List<FsNode> structure,
    required String outputPath,
  }) async {
    final folderName = rootPath.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last;
    final nowStr = DateTime.now().toString().split('.').first;

    final jsonData = {
      'RootPath': rootPath,
      'RootFolder': folderName,
      'ScanDate': nowStr,
      'ExcludedPatterns': excludedPatterns,
      'Structure': structure.map((node) => node.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    final jsonFile = File(outputPath);
    await jsonFile.writeAsString(encoder.convert(jsonData));
    return jsonFile;
  }

  static Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }
}
