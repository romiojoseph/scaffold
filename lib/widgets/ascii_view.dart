import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

import 'common/app_icon.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';

import '../models/fs_node.dart';

class AsciiView extends StatefulWidget {
  final String asciiContent;
  final List<FsNode>? nodes;

  const AsciiView({super.key, required this.asciiContent, this.nodes});

  @override
  State<AsciiView> createState() => _AsciiViewState();
}

class _AsciiViewState extends State<AsciiView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _copied = false;
  bool _trimEnabled = false;
  bool _foldersOnly = false;
  bool _showCounts = false;
  static const int _maxFilesPerDir = 3;

  String? _cachedVisibleContent;
  List<String>? _cachedLines;
  bool? _cachedTrim;
  bool? _cachedFoldersOnly;
  bool? _cachedShowCounts;
  List<FsNode>? _cachedNodes;
  String? _cachedAsciiContent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getVisibleContent()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _getVisibleContent() {
    if (_cachedVisibleContent != null &&
        _cachedTrim == _trimEnabled &&
        _cachedFoldersOnly == _foldersOnly &&
        _cachedShowCounts == _showCounts &&
        identical(_cachedNodes, widget.nodes) &&
        _cachedAsciiContent == widget.asciiContent) {
      return _cachedVisibleContent!;
    }

    String result;
    if (widget.nodes != null && widget.nodes!.isNotEmpty) {
      if (!_trimEnabled && !_foldersOnly) {
        result = widget.asciiContent;
      } else {
        result = _generateAsciiFromNodes(
          widget.nodes!,
          foldersOnly: _foldersOnly,
          showCounts: _foldersOnly && _showCounts,
          trimEnabled: _trimEnabled,
          maxFiles: _maxFilesPerDir,
        );
      }
    } else if (widget.asciiContent.isEmpty || (!_trimEnabled && !_foldersOnly)) {
      result = widget.asciiContent;
    } else {
      result = _trimAscii(
        widget.asciiContent,
        foldersOnly: _foldersOnly,
        showCounts: _foldersOnly && _showCounts,
      );
    }

    _cachedVisibleContent = result;
    _cachedLines = result.split('\n');
    _cachedTrim = _trimEnabled;
    _cachedFoldersOnly = _foldersOnly;
    _cachedShowCounts = _showCounts;
    _cachedNodes = widget.nodes;
    _cachedAsciiContent = widget.asciiContent;

    return result;
  }


  String _generateAsciiFromNodes(
    List<FsNode> nodes, {
    required bool foldersOnly,
    required bool showCounts,
    required bool trimEnabled,
    int maxFiles = 3,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('.');

    void buildBranch(List<FsNode> items, String prefix) {
      if (items.isEmpty) return;

      final dirs = items.where((n) => n.isDirectory).toList();
      final files = items.where((n) => !n.isDirectory).toList();

      final List<FsNode> effectiveFiles;
      int hiddenFileCount = 0;

      if (foldersOnly) {
        effectiveFiles = [];
      } else if (trimEnabled && files.length > maxFiles) {
        effectiveFiles = files.sublist(0, maxFiles);
        hiddenFileCount = files.length - maxFiles;
      } else {
        effectiveFiles = files;
      }

      final totalEntries =
          dirs.length + effectiveFiles.length + (hiddenFileCount > 0 ? 1 : 0);
      int entryIndex = 0;

      // 1. Directories
      for (final dir in dirs) {
        final isLast = entryIndex == totalEntries - 1;
        final branch = isLast ? '└── ' : '├── ';
        final nextPrefix = prefix + (isLast ? '    ' : '│   ');

        String label = dir.name;
        if (showCounts) {
          final directFiles =
              dir.children?.where((c) => !c.isDirectory).length ?? 0;
          final directDirs =
              dir.children?.where((c) => c.isDirectory).length ?? 0;

          final String suffix;
          if (directFiles == 0 && directDirs == 0) {
            suffix = '(empty)';
          } else if (directFiles > 0 && directDirs == 0) {
            suffix = '($directFiles ${directFiles == 1 ? 'file' : 'files'})';
          } else if (directFiles == 0 && directDirs > 0) {
            suffix = '($directDirs ${directDirs == 1 ? 'folder' : 'folders'})';
          } else {
            suffix =
                '($directFiles ${directFiles == 1 ? 'file' : 'files'}, $directDirs ${directDirs == 1 ? 'folder' : 'folders'})';
          }
          label = '$label $suffix';
        }

        buffer.writeln('$prefix$branch$label');
        entryIndex++;

        if (dir.children != null && dir.children!.isNotEmpty) {
          buildBranch(dir.children!, nextPrefix);
        }
      }

      // 2. Files
      for (final file in effectiveFiles) {
        final isLast = entryIndex == totalEntries - 1;
        final branch = isLast ? '└── ' : '├── ';

        buffer.writeln('$prefix$branch${file.name}');
        entryIndex++;
      }

      // 3. Trimmed files summary
      if (hiddenFileCount > 0) {
        final isLast = entryIndex == totalEntries - 1;
        final branch = isLast ? '└── ' : '├── ';
        buffer.writeln('$prefix$branch... and $hiddenFileCount more files');
      }
    }

    buildBranch(nodes, '');
    return buffer.toString().trimRight();
  }

  String _trimAscii(
    String content, {
    required bool foldersOnly,
    required bool showCounts,
  }) {
    if (content.isEmpty) return content;

    final lines = content.split('\n');
    if (lines.isEmpty) return content;

    final isDir = List<bool>.filled(lines.length, false);
    for (int i = 0; i < lines.length - 1; i++) {
      final currentDepth = _getDepth(lines[i]);
      final nextDepth = _getDepth(lines[i + 1]);
      isDir[i] = nextDepth > currentDepth;
    }

    final output = <String>[];
    final fileCountAtDepth = <int, int>{};
    final depthHasFiles = <int, bool>{};
    var prevDepth = -1;

    for (int i = 0; i < lines.length; i++) {
      final depth = _getDepth(lines[i]);

      if (depth < prevDepth) {
        if (showCounts &&
            fileCountAtDepth.containsKey(prevDepth) &&
            output.isNotEmpty) {
          final count = fileCountAtDepth[prevDepth]!;
          final suffix = count == 0 ? '(empty)' : '($count files)';
          final lastLine = output.removeLast();
          output.add('$lastLine $suffix');
        }
        for (final d in fileCountAtDepth.keys.toList()) {
          if (d > depth) {
            fileCountAtDepth[d] = 0;
            depthHasFiles[d] = false;
          }
        }
      }

      if (!isDir[i]) {
        if (depth != prevDepth) {
          fileCountAtDepth.putIfAbsent(depth, () => 0);
          depthHasFiles.putIfAbsent(depth, () => false);
        }

        final count = (fileCountAtDepth[depth] ?? 0) + 1;
        fileCountAtDepth[depth] = count;

        if (foldersOnly || (!_foldersOnly && count > _maxFilesPerDir)) {
          if (depthHasFiles[depth] == true && !foldersOnly) {
            output.add('${'  ' * depth}... and ${count - 1} more files');
          }
          depthHasFiles[depth] = false;
          prevDepth = depth;
          continue;
        }

        depthHasFiles[depth] = true;
        if (!foldersOnly) output.add(lines[i]);
      } else {
        if (showCounts &&
            fileCountAtDepth.containsKey(depth) &&
            output.isNotEmpty) {
          final count = fileCountAtDepth[depth]!;
          final suffix = count == 0 ? '(empty)' : '($count files)';
          final lastLine = output.removeLast();
          output.add('$lastLine $suffix');
        }
        fileCountAtDepth[depth] = 0;
        depthHasFiles[depth] = false;
        output.add(lines[i]);
      }

      prevDepth = depth;
    }

    if (showCounts &&
        fileCountAtDepth.containsKey(prevDepth) &&
        output.isNotEmpty) {
      final count = fileCountAtDepth[prevDepth]!;
      final suffix = count == 0 ? '(empty)' : '($count files)';
      final lastLine = output.removeLast();
      output.add('$lastLine $suffix');
    }

    return output.join('\n');
  }

  int _getDepth(String line) {
    int depth = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '│' || line[i] == ' ') {
        if (i + 4 <= line.length && line.substring(i, i + 4) == '│   ') {
          depth++;
          i += 3;
        } else if (i + 4 <= line.length && line.substring(i, i + 4) == '    ') {
          depth++;
          i += 3;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    _getVisibleContent();
    final lines = _cachedLines ?? const [];
    final filteredLines = _query.isEmpty
        ? lines
        : lines.where((line) => line.toLowerCase().contains(_query)).toList();


    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: AppColors.neutral11,
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _searchController,
                  hintText: 'Search ASCII output...',
                  svgPrefixIcon: AppSvgIcon.magnifyingGlass,
                  size: AppInputSize.small,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Trim',
                svgIcon: _trimEnabled
                    ? AppSvgIcon.checkSquareFill
                    : AppSvgIcon.squareDuotone,
                variant: _trimEnabled
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: widget.asciiContent.isEmpty
                    ? null
                    : () => setState(() {
                        _trimEnabled = !_trimEnabled;
                        if (_trimEnabled) _foldersOnly = false;
                      }),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Folders',
                svgIcon: _foldersOnly
                    ? AppSvgIcon.checkSquareFill
                    : AppSvgIcon.squareDuotone,
                variant: _foldersOnly
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: widget.asciiContent.isEmpty
                    ? null
                    : () => setState(() {
                        _foldersOnly = !_foldersOnly;
                        if (_foldersOnly) {
                          _trimEnabled = false;
                        } else {
                          _showCounts = false;
                        }
                      }),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Counts',
                svgIcon: _showCounts
                    ? AppSvgIcon.checkSquareFill
                    : AppSvgIcon.squareDuotone,
                variant: _showCounts && _foldersOnly
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: widget.asciiContent.isEmpty || !_foldersOnly
                    ? null
                    : () => setState(() => _showCounts = !_showCounts),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: _copied ? 'Copied!' : 'Copy Tree',
                svgIcon: _copied ? AppSvgIcon.checkBold : AppSvgIcon.copy,
                variant: _copied
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: widget.asciiContent.isEmpty
                    ? null
                    : _copyToClipboard,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.neutral12,
            child: SelectionArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Text(
                    filteredLines.join('\n'),
                    style: GoogleFonts.googleSansCode(
                      color: AppColors.successBase,
                      fontSize: AppTypography.bodySize,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
