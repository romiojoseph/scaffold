import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'json_skeleton.dart';

enum NodeType { map, list, primitive }

class JsonNode {
  JsonNode({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.type,
    required this.keyLabel,
    this.rawKey,
    this.valueLabel,
    this.rawValue,
    this.valueColor,
    this.childCount = 0,
  });

  final int id;
  final int parentId;
  final int depth;
  final NodeType type;
  final String? keyLabel;
  final String? rawKey;
  final String? valueLabel;
  final dynamic rawValue;
  final Color? valueColor;
  final int childCount;

  bool get isContainer => type != NodeType.primitive;
}

/// Runs in a background isolate so large files don't block the UI thread.
List<JsonNode> flattenJson(String content) {
  // jsonDecode in Dart preserves key insertion order of JSON objects.
  final root = jsonDecode(content);
  final nodes = <JsonNode>[];
  var id = 0;

  void visit(dynamic value, String? key, int parentId, int depth) {
    final nodeId = id++;
    if (depth > 128) {
      nodes.add(
        JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: NodeType.primitive,
          keyLabel: key,
          rawKey: key,
          valueLabel: '... (Max recursion depth reached)',
          rawValue: '... (Max recursion depth reached)',
          valueColor: AppColors.warningBase,
        ),
      );
      return;
    }
    if (value is Map) {
      nodes.add(
        JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: NodeType.map,
          keyLabel: keyLabel(key),
          rawKey: key,
          childCount: value.length,
        ),
      );
      for (final entry in value.entries) {
        visit(entry.value, entry.key.toString(), nodeId, depth + 1);
      }
    } else if (value is List) {
      nodes.add(
        JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: NodeType.list,
          keyLabel: keyLabel(key),
          rawKey: key,
          childCount: value.length,
        ),
      );
      for (var i = 0; i < value.length; i++) {
        visit(value[i], '[$i]', nodeId, depth + 1);
      }
    } else {
      nodes.add(
        JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: NodeType.primitive,
          keyLabel: keyLabel(key),
          rawKey: key,
          valueLabel: formatPrimitive(value),
          rawValue: value,
          valueColor: primitiveColor(value),
        ),
      );
    }
  }

  visit(root, null, -1, 0);
  return nodes;
}

String? keyLabel(String? key) {
  if (key == null) return null;
  return key.startsWith('[') ? '$key: ' : '"$key": ';
}

Color primitiveColor(dynamic value) {
  if (value == null) {
    return const Color(0xFF569CD6); // VS Code Blue for null
  }
  if (value is String) {
    return const Color(0xFFCE9178); // VS Code Terracotta Red/Orange for Strings
  }
  if (value is num) {
    return const Color(0xFFB5CEA8); // VS Code Mint Green for Numbers
  }
  if (value is bool) {
    return const Color(0xFF569CD6); // VS Code Blue for Booleans
  }
  return AppColors.neutral6;
}