import 'fs_node.dart';

enum DiffType { added, removed, modified, unchanged }

class DiffNode {
  final String name;
  final String path;
  final bool isDirectory;
  final DiffType diffType;
  final String details;
  final List<DiffNode>? children;

  DiffNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.diffType,
    this.details = '',
    this.children,
  });
}

class SnapshotDiff {
  static List<DiffNode> compareTrees(
    List<FsNode> baseline,
    List<FsNode> current, {
    String parentRelativePath = '',
  }) {
    final diffs = <DiffNode>[];

    // Helper to get relative path key for comparison (so path diffs work regardless of root drive/folder)
    String getRelPath(FsNode node) {
      final rel = parentRelativePath.isEmpty ? node.name : '$parentRelativePath/${node.name}';
      return rel.toLowerCase();
    }

    final baselineMap = <String, FsNode>{};
    for (final node in baseline) {
      baselineMap[getRelPath(node)] = node;
    }

    final currentMap = <String, FsNode>{};
    for (final node in current) {
      currentMap[getRelPath(node)] = node;
    }

    // Process current nodes against baseline
    for (final currNode in current) {
      final relKey = getRelPath(currNode);
      final baseNode = baselineMap[relKey];
      final currentRelPath = parentRelativePath.isEmpty ? currNode.name : '$parentRelativePath/${currNode.name}';

      if (baseNode == null) {
        // Node was added
        diffs.add(_buildDiffSubtree(currNode, DiffType.added, 'Added', currentRelPath));
      } else {
        if (currNode.isDirectory || baseNode.isDirectory) {
          // Compare directory children recursively
          final childDiffs = compareTrees(
            baseNode.children ?? [],
            currNode.children ?? [],
            parentRelativePath: currentRelPath,
          );

          final hasChanges = childDiffs.any((c) => c.diffType != DiffType.unchanged);
          diffs.add(DiffNode(
            name: currNode.name,
            path: currNode.path,
            isDirectory: true,
            diffType: hasChanges ? DiffType.modified : DiffType.unchanged,
            details: hasChanges ? 'Modified contents' : 'Unchanged',
            children: childDiffs,
          ));
        } else {
          // File comparison: check size and timestamp if present
          final sizeChanged = baseNode.size != currNode.size;
          bool timeChanged = false;
          if (baseNode.lastModified != null && currNode.lastModified != null) {
            timeChanged = baseNode.lastModified!.millisecondsSinceEpoch != currNode.lastModified!.millisecondsSinceEpoch;
          }

          if (sizeChanged || timeChanged) {
            final String detail = sizeChanged
                ? 'Size: ${baseNode.sizeFormatted.isEmpty ? FsNode.formatBytes(baseNode.size) : baseNode.sizeFormatted} ➔ ${currNode.sizeFormatted}'
                : 'Modified timestamp updated';

            diffs.add(DiffNode(
              name: currNode.name,
              path: currNode.path,
              isDirectory: false,
              diffType: DiffType.modified,
              details: detail,
            ));
          } else {
            diffs.add(DiffNode(
              name: currNode.name,
              path: currNode.path,
              isDirectory: false,
              diffType: DiffType.unchanged,
              details: 'Unchanged',
            ));
          }
        }
      }
    }

    // Process removed nodes (present in baseline but missing in current)
    for (final baseNode in baseline) {
      final relKey = getRelPath(baseNode);
      if (!currentMap.containsKey(relKey)) {
        final baseRelPath = parentRelativePath.isEmpty ? baseNode.name : '$parentRelativePath/${baseNode.name}';
        diffs.add(_buildDiffSubtree(baseNode, DiffType.removed, 'Deleted', baseRelPath));
      }
    }

    return diffs;
  }

  static DiffNode _buildDiffSubtree(FsNode node, DiffType type, String details, String relPath) {
    return DiffNode(
      name: node.name,
      path: node.path,
      isDirectory: node.isDirectory,
      diffType: type,
      details: details,
      children: node.isDirectory && node.children != null
          ? node.children!.map((c) {
              final childRelPath = '$relPath/${c.name}';
              return _buildDiffSubtree(c, type, details, childRelPath);
            }).toList()
          : null,
    );
  }
}
