import 'dart:convert';

/// Builds a skeleton (schema-shape) of a JSON value, stripping actual values.
/// Runs in an isolate via compute() — must be a top-level function.
dynamic buildSkeleton(dynamic value) {
  if (value == null) return null;
  if (value is String) return 'string';
  if (value is int) return 0;
  if (value is double) return 0.0;
  if (value is bool) return true;
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: buildSkeleton(entry.value),
    };
  }
  if (value is List) {
    if (value.isEmpty) return <dynamic>[];
    return [buildSkeleton(value[0])];
  }
  return null;
}

/// Top-level function for compute(): parses + skeletonizes + re-encodes.
String computeSkeletonJson(String content) {
  final root = jsonDecode(content);
  final skeleton = buildSkeleton(root);
  return const JsonEncoder.withIndent('  ').convert(skeleton);
}

String formatPrimitive(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  return '$value';
}