import 'dart:io';

class FsNode {
  final String name;
  final String type; // 'Directory' or 'File'
  final String path;
  final int size;
  final String sizeFormatted;
  final String extension;
  final DateTime? lastModified;
  final DateTime? lastAccessed;
  final DateTime? created;
  final List<FsNode>? children;
  bool isExpanded;

  final int lineCount;
  final int codeLineCount;
  final int blankLineCount;
  final int commentLineCount;

  FsNode({
    required this.name,
    required this.type,
    required this.path,
    this.size = 0,
    this.sizeFormatted = '',
    this.extension = '',
    this.lastModified,
    this.lastAccessed,
    this.created,
    this.children,
    this.isExpanded = true,
    this.lineCount = 0,
    this.codeLineCount = 0,
    this.blankLineCount = 0,
    this.commentLineCount = 0,
  });

  bool get isDirectory => type == 'Directory';

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() {
    if (isDirectory) {
      return {
        'Name': name,
        'Type': 'Directory',
        'Path': path,
        'Children': children?.map((c) => c.toJson()).toList() ?? [],
      };
    } else {
      return {
        'Name': name,
        'Type': 'File',
        'Path': path,
        'Size': size,
        'SizeFormatted': sizeFormatted,
        'Extension': extension,
        'LastModified': lastModified?.toIso8601String() ?? '',
        'LastAccessed': lastAccessed?.toIso8601String() ?? '',
        'Created': created?.toIso8601String() ?? '',
        'LineCount': lineCount,
        'CodeLineCount': codeLineCount,
        'BlankLineCount': blankLineCount,
        'CommentLineCount': commentLineCount,
      };
    }
  }

  static FsNode fromFileSystemEntity(
    FileSystemEntity entity, {
    List<FsNode>? children,
    int lineCount = 0,
    int codeLineCount = 0,
    int blankLineCount = 0,
    int commentLineCount = 0,
  }) {
    final stat = entity.statSync();
    final name = entity.path.split(Platform.pathSeparator).last;

    if (entity is Directory) {
      // Calculate directory total size from children if available
      int dirSize = 0;
      if (children != null) {
        for (final child in children) {
          dirSize += child.size;
        }
      }

      return FsNode(
        name: name.isEmpty ? entity.path : name,
        type: 'Directory',
        path: entity.path,
        size: dirSize,
        sizeFormatted: formatBytes(dirSize),
        lastModified: stat.modified,
        lastAccessed: stat.accessed,
        created: stat.changed,
        children: children,
      );
    } else {
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';
      return FsNode(
        name: name,
        type: 'File',
        path: entity.path,
        size: stat.size,
        sizeFormatted: formatBytes(stat.size),
        extension: ext,
        lastModified: stat.modified,
        lastAccessed: stat.accessed,
        created: stat.changed,
        lineCount: lineCount,
        codeLineCount: codeLineCount,
        blankLineCount: blankLineCount,
        commentLineCount: commentLineCount,
      );
    }
  }

  String toAsciiTree({String prefix = ''}) {
    final buffer = StringBuffer();
    if (children == null || children!.isEmpty) {
      return buffer.toString();
    }

    for (int i = 0; i < children!.length; i++) {
      final child = children![i];
      final isLast = i == children!.length - 1;
      final branch = isLast ? '└── ' : '├── ';
      final extension = isLast ? '    ' : '│   ';

      buffer.writeln('$prefix$branch${child.name}');
      if (child.isDirectory) {
        buffer.write(child.toAsciiTree(prefix: '$prefix$extension'));
      }
    }
    return buffer.toString();
  }
}
