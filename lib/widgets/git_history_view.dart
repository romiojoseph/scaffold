import 'dart:io';
import 'package:flutter/material.dart';
import '../models/git_commit.dart';
import '../services/git_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/clipboard_utils.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';
import 'charts/code_frequency_chart.dart';
import 'charts/commit_activity_chart.dart';
import 'common/app_icon.dart';
import 'common/app_toast.dart';
import 'git/git_commit_card.dart';
import 'git/git_controls_bar.dart';
import 'git/git_sort_option.dart';
import 'git/git_stat_cards.dart';
import 'git/git_table_view.dart';
import 'git/git_view_mode_toggle.dart';

class GitHistoryView extends StatefulWidget {
  final String rootPath;

  const GitHistoryView({super.key, required this.rootPath});

  @override
  State<GitHistoryView> createState() => _GitHistoryViewState();
}

class _GitHistoryViewState extends State<GitHistoryView> {
  final GitService _gitService = const GitService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCommitHashes = {};

  GitSortOption _sortOption = GitSortOption.dateDesc;
  bool _isLoading = false;
  bool _isGitRepo = false;
  bool _isTableView = false;
  List<GitCommit> _commits = [];
  String? _errorMessage;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadGitHistory();
  }

  @override
  void didUpdateWidget(covariant GitHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _loadGitHistory();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGitHistory() async {
    final targetPath = widget.rootPath.trim();
    if (targetPath.isEmpty || !Directory(targetPath).existsSync()) {
      if (mounted) {
        setState(() {
          _isGitRepo = false;
          _commits = [];
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isRepo = await _gitService.isGitRepository(targetPath);
      if (!isRepo) {
        if (mounted) {
          setState(() {
            _isGitRepo = false;
            _commits = [];
            _isLoading = false;
          });
        }
        return;
      }

      final commits = await _gitService.getCommitHistory(targetPath);
      if (mounted) {
        setState(() {
          _isGitRepo = true;
          _commits = commits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String text, String message) async {
    final success = await ClipboardUtils.copy(text);
    if (!mounted) return;
    if (success) {
      AppToast.showSuccess(context, message);
    } else {
      AppToast.showError(context, 'Failed to copy to clipboard');
    }
  }

  Future<void> _openUrl(String url) async {
    final opened = await UrlUtils.openUrl(url);
    if (!opened && mounted) {
      _copyToClipboard(
        url,
        'Link copied to clipboard (could not open browser)',
      );
    }
  }

  bool _commitMatchesFilter(GitCommit commit, String query) {
    if (query.isEmpty) return true;
    if (commit.message.toLowerCase().contains(query)) return true;
    if (commit.description != null &&
        commit.description!.toLowerCase().contains(query)) {
      return true;
    }
    if (commit.author.toLowerCase().contains(query)) return true;
    if (commit.shortHash.toLowerCase().contains(query)) return true;
    if (commit.hash.toLowerCase().contains(query)) return true;
    if (commit.files.any((f) => f.path.toLowerCase().contains(query))) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBase,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading Git commit history...',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    if (!_isGitRepo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppSvgIcon.arrowCounterClockwise,
              size: 56,
              color: AppColors.neutral8,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Not a Git Repository',
              style: AppTypography.heading6(color: AppColors.neutral5),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No Git repository was detected in the selected folder.',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppSvgIcon.xBold,
              size: 48,
              color: AppColors.dangerBase,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to read Git history',
              style: AppTypography.heading6(color: AppColors.dangerBase),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorMessage!,
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    if (_commits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppSvgIcon.arrowCounterClockwise,
              size: 56,
              color: AppColors.neutral8,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Commits Found',
              style: AppTypography.heading6(color: AppColors.neutral5),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This Git repository has no commits yet.',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    final filteredCommits = _commits
        .where((c) => _commitMatchesFilter(c, _filter))
        .toList();

    switch (_sortOption) {
      case GitSortOption.dateDesc:
        filteredCommits.sort((a, b) => b.date.compareTo(a.date));
        break;
      case GitSortOption.dateAsc:
        filteredCommits.sort((a, b) => a.date.compareTo(b.date));
        break;
      case GitSortOption.additionsDesc:
        filteredCommits.sort(
          (a, b) => b.totalAdditions.compareTo(a.totalAdditions),
        );
        break;
      case GitSortOption.additionsAsc:
        filteredCommits.sort(
          (a, b) => a.totalAdditions.compareTo(b.totalAdditions),
        );
        break;
      case GitSortOption.deletionsDesc:
        filteredCommits.sort(
          (a, b) => b.totalDeletions.compareTo(a.totalDeletions),
        );
        break;
      case GitSortOption.deletionsAsc:
        filteredCommits.sort(
          (a, b) => a.totalDeletions.compareTo(b.totalDeletions),
        );
        break;
    }

    int totalAdditions = 0;
    int totalDeletions = 0;
    for (final commit in _commits) {
      totalAdditions += commit.totalAdditions;
      totalDeletions += commit.totalDeletions;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Metric Overview Cards
        Row(
          children: [
            gitStatCard(
              svgIcon: AppSvgIcon.gitCommitFill,
              label: 'Total Commits',
              value: FormatUtils.formatNumber(_commits.length),
              color: AppColors.primaryBase,
            ),
            const SizedBox(width: AppSpacing.md),
            gitStatCard(
              svgIcon: AppSvgIcon.circlesThreePlusFill,
              label: 'Additions',
              value: '+${FormatUtils.formatNumber(totalAdditions)}',
              color: AppColors.successBase,
            ),
            const SizedBox(width: AppSpacing.md),
            gitStatCard(
              svgIcon: AppSvgIcon.trashFill,
              label: 'Deletions',
              value: '-${FormatUtils.formatNumber(totalDeletions)}',
              color: AppColors.dangerBase,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Commit Activity & Code Frequency Charts in one row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: CommitActivityChart(commits: _commits)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: CodeFrequencyChart(commits: _commits)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Controls bar: Search + Actions
        gitControlsBar(
          searchController: _searchController,
          filter: _filter,
          onFilterChanged: (val) => setState(() => _filter = val),
          sortOption: _sortOption,
          onSortChanged: (option) => setState(() => _sortOption = option),
          onRefresh: _loadGitHistory,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Commits count subheader & View Mode Toggle
        Row(
          children: [
            Text(
              'Commit History',
              style: AppTypography.heading6(
                color: AppColors.neutral5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryBase.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${FormatUtils.formatNumber(filteredCommits.length)} ${_commits.length == filteredCommits.length ? 'commits' : 'of ${_commits.length} commits'}',
                style: AppTypography.body(
                  color: AppColors.primaryBase,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            gitViewModeToggle(
              isTableView: _isTableView,
              onTableViewChanged: (val) => setState(() => _isTableView = val),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Commit List Items (Accordion)
        if (filteredCommits.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.neutral11,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral10),
            ),
            child: Center(
              child: Text(
                'No commits match the search criteria.',
                style: AppTypography.body(color: AppColors.neutral6),
              ),
            ),
          )
        else if (_isTableView)
          gitTableView(
            commits: filteredCommits,
            onCopy: _copyToClipboard,
            onOpenUrl: (url) => _openUrl(url),
          )
        else
          ...List.generate(filteredCommits.length, (index) {
            final commit = filteredCommits[index];
            final isExpanded = _expandedCommitHashes.contains(commit.hash);
            final isLast = index == filteredCommits.length - 1;

            return gitCommitCard(
              commit: commit,
              isExpanded: isExpanded,
              isFirst: index == 0,
              isLast: isLast,
              index: index,
              onToggle: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCommitHashes.remove(commit.hash);
                  } else {
                    _expandedCommitHashes.add(commit.hash);
                  }
                });
              },
              onCopy: _copyToClipboard,
              onOpenUrl: (url) => _openUrl(url),
            );
          }),
      ],
    );
  }
}
