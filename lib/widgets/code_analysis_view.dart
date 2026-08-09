import 'package:flutter/material.dart';
import '../models/fs_node.dart';
import '../models/scan_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

import 'common/app_icon.dart';

class LanguageStats {
  final String language;
  final List<FsNode> files;
  int lines = 0;
  int code = 0;
  int comments = 0;
  int blanks = 0;

  LanguageStats({required this.language, List<FsNode>? files}) : files = files ?? [];
}

class CodeAnalysisView extends StatefulWidget {
  final List<FsNode> nodes;
  final ScanStats stats;

  const CodeAnalysisView({
    super.key,
    required this.nodes,
    required this.stats,
  });

  @override
  State<CodeAnalysisView> createState() => _CodeAnalysisViewState();
}

class _CodeAnalysisViewState extends State<CodeAnalysisView> {
  final Set<String> _expandedLanguages = {};

  String _mapLanguage(String ext) {
    switch (ext.toLowerCase()) {
      case '.dart':
        return 'Dart';
      case '.cpp':
      case '.cc':
      case '.cxx':
        return 'C++';
      case '.h':
      case '.hpp':
        return 'C Header';
      case '.c':
        return 'C';
      case '.js':
      case '.mjs':
      case '.cjs':
        return 'JavaScript';
      case '.ts':
        return 'TypeScript';
      case '.jsx':
        return 'JSX';
      case '.tsx':
        return 'TSX';
      case '.json':
        return 'JSON';
      case '.html':
      case '.htm':
        return 'HTML';
      case '.css':
      case '.scss':
      case '.less':
        return 'CSS';
      case '.yaml':
      case '.yml':
        return 'YAML';
      case '.md':
      case '.markdown':
        return 'Markdown';
      case '.py':
        return 'Python';
      case '.rs':
        return 'Rust';
      case '.go':
        return 'Go';
      case '.java':
        return 'Java';
      case '.cs':
        return 'C#';
      case '.kt':
        return 'Kotlin';
      case '.swift':
        return 'Swift';
      case '.sh':
      case '.ps1':
      case '.bat':
        return 'Shell Script';
      case '.xml':
        return 'XML';
      case 'cmakelists.txt':
      case '.cmake':
        return 'CMake';
      default:
        return ext.isEmpty ? 'Plain Text' : ext.toUpperCase().replaceAll('.', '');
    }
  }

  Map<String, LanguageStats> _buildLanguageBreakdown() {
    final map = <String, LanguageStats>{};

    void recurse(FsNode node) {
      if (node.isDirectory) {
        if (node.children != null) {
          for (final child in node.children!) {
            recurse(child);
          }
        }
      } else {
        if (node.lineCount == 0 && node.codeLineCount == 0 && node.blankLineCount == 0) return;

        final lang = node.name.toLowerCase() == 'cmakelists.txt'
            ? 'CMake'
            : _mapLanguage(node.extension);

        final group = map.putIfAbsent(lang, () => LanguageStats(language: lang));
        group.files.add(node);
        group.lines += node.lineCount;
        group.code += node.codeLineCount;
        group.comments += node.commentLineCount;
        group.blanks += node.blankLineCount;
      }
    }

    for (final node in widget.nodes) {
      recurse(node);
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final languageMap = _buildLanguageBreakdown();
    final sortedLanguages = languageMap.values.toList()
      ..sort((a, b) => b.lines.compareTo(a.lines));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Overview Bar
          Row(
            children: [
              _buildSummaryCard('Languages', '${sortedLanguages.length}', AppSvgIcon.treeStructure, AppColors.infoBase),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard('Total Lines', '${widget.stats.totalLines}', AppSvgIcon.listNumbers, AppColors.warningBase),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard('Code', '${widget.stats.totalCodeLines}', AppSvgIcon.code, AppColors.successBase),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard('Comments', '${widget.stats.totalCommentLines}', AppSvgIcon.chat, AppColors.primaryBase),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard('Blanks', '${widget.stats.totalBlankLines}', AppSvgIcon.lineVertical, AppColors.neutral6),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.neutral10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Language / File', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral0))),
                Expanded(flex: 2, child: Text('Files', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral0))),
                Expanded(flex: 2, child: Text('Lines', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral0))),
                Expanded(flex: 2, child: Text('Code', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.successBase))),
                Expanded(flex: 2, child: Text('Comments', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.infoBase))),
                Expanded(flex: 2, child: Text('Blanks', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral6))),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Table Content
          Expanded(
            child: sortedLanguages.isEmpty
                ? Center(child: Text('No code files found in selected directory', style: AppTypography.body(color: AppColors.neutral6)))
                : ListView.builder(
                    itemCount: sortedLanguages.length,
                    itemBuilder: (context, index) {
                      final group = sortedLanguages[index];
                      final isExpanded = _expandedLanguages.contains(group.language);

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.neutral11,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutral10),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedLanguages.remove(group.language);
                                  } else {
                                    _expandedLanguages.add(group.language);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                                child: Row(
                                  children: [
                                    AppIcon(
                                      isExpanded ? AppSvgIcon.caretDownBold : AppSvgIcon.caretRightBold,
                                      size: 16,
                                      color: AppColors.primaryBase,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        group.language,
                                        style: AppTypography.body(color: AppColors.neutral0, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(flex: 2, child: Text('${group.files.length}', textAlign: TextAlign.right, style: AppTypography.body(color: AppColors.neutral3))),
                                    Expanded(flex: 2, child: Text('${group.lines}', textAlign: TextAlign.right, style: AppTypography.body(color: AppColors.neutral0, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('${group.code}', textAlign: TextAlign.right, style: AppTypography.body(color: AppColors.successBase))),
                                    Expanded(flex: 2, child: Text('${group.comments}', textAlign: TextAlign.right, style: AppTypography.body(color: AppColors.infoBase))),
                                    Expanded(flex: 2, child: Text('${group.blanks}', textAlign: TextAlign.right, style: AppTypography.body(color: AppColors.neutral6))),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                color: AppColors.neutral12,
                                child: Column(
                                  children: group.files.map((file) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 20, vertical: AppSpacing.xs),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              file.path,
                                              style: AppTypography.caption(color: AppColors.neutral5),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Expanded(flex: 2, child: Text('1', textAlign: TextAlign.right)),
                                          Expanded(flex: 2, child: Text('${file.lineCount}', textAlign: TextAlign.right, style: AppTypography.caption(color: AppColors.neutral4))),
                                          Expanded(flex: 2, child: Text('${file.codeLineCount}', textAlign: TextAlign.right, style: AppTypography.caption(color: AppColors.successBase))),
                                          Expanded(flex: 2, child: Text('${file.commentLineCount}', textAlign: TextAlign.right, style: AppTypography.caption(color: AppColors.infoBase))),
                                          Expanded(flex: 2, child: Text('${file.blankLineCount}', textAlign: TextAlign.right, style: AppTypography.caption(color: AppColors.neutral6))),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, AppSvgIcon svgIcon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.neutral11,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral10),
        ),
        child: Row(
          children: [
            AppIcon(svgIcon, size: 20, color: color),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.caption(color: AppColors.neutral6)),
                Text(value, style: AppTypography.label(color: AppColors.neutral0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
