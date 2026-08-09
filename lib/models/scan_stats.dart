import 'fs_node.dart';

class ScanStats {
  final int totalFiles;
  final int totalDirectories;
  final int totalBytes;
  final String formattedTotalSize;
  final int totalLines;
  final int totalCodeLines;
  final int totalBlankLines;
  final int totalCommentLines;
  final Map<String, int> extensionCounts;
  final Map<String, int> extensionSizes;
  final Map<String, int> extensionLines;

  ScanStats({
    required this.totalFiles,
    required this.totalDirectories,
    required this.totalBytes,
    required this.formattedTotalSize,
    required this.totalLines,
    required this.totalCodeLines,
    required this.totalBlankLines,
    required this.totalCommentLines,
    required this.extensionCounts,
    required this.extensionSizes,
    required this.extensionLines,
  });

  factory ScanStats.fromNodes(List<FsNode> nodes) {
    int files = 0;
    int dirs = 0;
    int bytes = 0;
    int lines = 0;
    int codeLines = 0;
    int blankLines = 0;
    int commentLines = 0;
    final extCounts = <String, int>{};
    final extSizes = <String, int>{};
    final extLines = <String, int>{};

    void recurse(FsNode node) {
      if (node.isDirectory) {
        dirs++;
        if (node.children != null) {
          for (final child in node.children!) {
            recurse(child);
          }
        }
      } else {
        files++;
        bytes += node.size;
        lines += node.lineCount;
        codeLines += node.codeLineCount;
        blankLines += node.blankLineCount;
        commentLines += node.commentLineCount;

        final ext = node.extension.isEmpty ? 'No Ext' : node.extension.toLowerCase();
        extCounts[ext] = (extCounts[ext] ?? 0) + 1;
        extSizes[ext] = (extSizes[ext] ?? 0) + node.size;
        extLines[ext] = (extLines[ext] ?? 0) + node.lineCount;
      }
    }

    for (final n in nodes) {
      recurse(n);
    }

    return ScanStats(
      totalFiles: files,
      totalDirectories: dirs,
      totalBytes: bytes,
      formattedTotalSize: FsNode.formatBytes(bytes),
      totalLines: lines,
      totalCodeLines: codeLines,
      totalBlankLines: blankLines,
      totalCommentLines: commentLines,
      extensionCounts: extCounts,
      extensionSizes: extSizes,
      extensionLines: extLines,
    );
  }
}
