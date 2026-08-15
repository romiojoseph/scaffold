import 'package:flutter/material.dart';
import '../models/dependency_info.dart';
import '../models/fs_node.dart';
import '../services/global_dependency_service.dart';
import '../services/manifest_parser_service.dart';
import '../services/version_checker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/clipboard_utils.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';
import 'common/app_button.dart';
import 'common/app_icon.dart';
import 'common/app_toast.dart';
import 'deps/deps_controls_bar.dart';
import 'deps/deps_progress_banner.dart';
import 'deps/deps_stat_cards.dart';
import 'deps/manifest_card.dart';

class DependenciesView extends StatefulWidget {
  final List<FsNode> nodes;
  final String rootPath;

  const DependenciesView({
    super.key,
    required this.nodes,
    required this.rootPath,
  });

  @override
  State<DependenciesView> createState() => _DependenciesViewState();
}

class _DependenciesViewState extends State<DependenciesView> {
  final ManifestParserService _parserService = const ManifestParserService();
  final VersionCheckerService _checkerService = VersionCheckerService();
  final TextEditingController _searchController = TextEditingController();

  List<ManifestFile> _manifests = [];
  bool _isLoadingManifests = false;
  bool _isCheckingVersions = false;
  String _checkingStatusMessage = '';
  int _checkedCount = 0;
  int _totalToCheck = 0;

  String _searchFilter = '';
  Ecosystem? _selectedEcosystemFilter;
  bool _showOutdatedOnly = false;
  bool _showVulnerableOnly = false;
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _loadManifests();
  }

  @override
  void didUpdateWidget(covariant DependenciesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath || oldWidget.nodes != widget.nodes) {
      _loadManifests();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _checkerService.dispose();
    super.dispose();
  }

  Future<void> _loadManifests() async {
    final targetPath = widget.rootPath.trim();
    if (targetPath.isEmpty) return;

    setState(() {
      _isLoadingManifests = true;
      _manifests = [];
      _isCheckingVersions = false;
    });

    try {
      final results = await _parserService.findAndParseManifests(
        nodes: widget.nodes,
        rootPath: targetPath,
      );

      if (mounted) {
        setState(() {
          _manifests = results;
          _isLoadingManifests = false;
        });

        if (_manifests.isNotEmpty) {
          GlobalDependencyService().saveProject(targetPath, results);
          _checkAllVersions();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingManifests = false);
      }
    }
  }

  Future<void> _checkAllVersions({bool forceRefresh = false}) async {
    final allItems = <DependencyItem>[];
    for (final m in _manifests) {
      allItems.addAll(m.dependencies);
    }

    if (allItems.isEmpty) return;

    setState(() {
      _isCheckingVersions = true;
      _checkedCount = 0;
      _totalToCheck = allItems.length;
      _checkingStatusMessage =
          forceRefresh ? 'Refreshing dependencies from registries...' : 'Loading dependencies info...';
    });

    try {
      await _checkerService.checkDependencies(
        allItems,
        forceRefresh: forceRefresh,
        onProgress: (completed, total, current) {
          if (!mounted) return;
          setState(() {
            _checkedCount = completed;
            _totalToCheck = total;
            _checkingStatusMessage =
                'Checking $completed/$total: ${current.ecosystem.name}/${current.name}...';

            // Update item in manifests list
            _manifests = _manifests.map((m) {
              if (m.path == current.manifestPath) {
                final updatedDeps = m.dependencies.map((d) {
                  return d.name == current.name ? current : d;
                }).toList();
                return ManifestFile(
                  path: m.path,
                  fileName: m.fileName,
                  ecosystem: m.ecosystem,
                  dependencies: updatedDeps,
                );
              }
              return m;
            }).toList();
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVersions = false;
          _checkingStatusMessage = '';
        });
      }
    }
  }

  void _copyToClipboard(String text, String message) async {
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
      _copyToClipboard(url, 'Link copied to clipboard');
    }
  }

  String _relativePath(String fullPath) {
    final root = widget.rootPath;
    if (fullPath.startsWith(root)) {
      var rel = fullPath.substring(root.length);
      while (rel.startsWith('/') || rel.startsWith('\\')) {
        rel = rel.substring(1);
      }
      return rel.isEmpty ? fullPath : rel;
    }
    return fullPath;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingManifests) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBase),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Searching for dependency manifests...',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    if (_manifests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppSvgIcon.fileCode,
              size: 56,
              color: AppColors.neutral8,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Manifests Found',
              style: AppTypography.heading6(
                color: AppColors.neutral4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No package.json, pubspec.yaml, go.mod, Cargo.toml, or requirements.txt files were detected.',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Scan Again',
              svgIcon: AppSvgIcon.arrowCounterClockwise,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: _loadManifests,
            ),
          ],
        ),
      );
    }

    // Totals calculations
    int totalDeps = 0;
    int outdatedDeps = 0;
    int upToDateDeps = 0;
    int vulnerableDeps = 0;

    for (final m in _manifests) {
      for (final d in m.dependencies) {
        totalDeps++;
        if (d.status == DependencyStatus.outdated) outdatedDeps++;
        if (d.status == DependencyStatus.upToDate) upToDateDeps++;
        if (d.hasVulnerabilities) vulnerableDeps++;
      }
    }

    // Filtered manifests
    final filteredManifests = _manifests.where((m) {
      if (_selectedEcosystemFilter != null && m.ecosystem != _selectedEcosystemFilter) {
        return false;
      }
      return true;
    }).map((m) {
      final matchingDeps = m.dependencies.where((d) {
        if (_showOutdatedOnly && d.status != DependencyStatus.outdated) {
          return false;
        }
        if (_showVulnerableOnly && !d.hasVulnerabilities) {
          return false;
        }
        if (_searchFilter.isNotEmpty) {
          final query = _searchFilter.toLowerCase();
          return d.name.toLowerCase().contains(query) ||
              d.currentConstraint.toLowerCase().contains(query) ||
              m.path.toLowerCase().contains(query) ||
              (d.description != null && d.description!.toLowerCase().contains(query));
        }
        return true;
      }).toList();

      return ManifestFile(
        path: m.path,
        fileName: m.fileName,
        ecosystem: m.ecosystem,
        dependencies: matchingDeps,
      );
    }).where((m) => m.dependencies.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Metric Overview Cards
        depsStatCards(
          manifestsCount: _manifests.length,
          totalDeps: totalDeps,
          upToDateDeps: upToDateDeps,
          outdatedDeps: outdatedDeps,
          vulnerableDeps: vulnerableDeps,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Live Checking Progress Banner
        if (_isCheckingVersions) ...[
          depsProgressBanner(
            message: _checkingStatusMessage,
            checkedCount: _checkedCount,
            totalToCheck: _totalToCheck,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Controls bar: Search + Filters + Check Action
        depsControlsBar(
          searchController: _searchController,
          searchFilter: _searchFilter,
          onFilterChanged: (val) => setState(() => _searchFilter = val),
          showOutdatedOnly: _showOutdatedOnly,
          onOutdatedToggled: () =>
              setState(() => _showOutdatedOnly = !_showOutdatedOnly),
          showVulnerableOnly: _showVulnerableOnly,
          onVulnerableToggled: () =>
              setState(() => _showVulnerableOnly = !_showVulnerableOnly),
          isChecking: _isCheckingVersions,
          onCheckUpdates: _isCheckingVersions
              ? null
              : () => _checkAllVersions(forceRefresh: true),
        ),
        const SizedBox(height: AppSpacing.md),

        // Ecosystem Filters Tabs
        depsEcosystemChips(
          manifests: _manifests,
          selectedEcosystemFilter: _selectedEcosystemFilter,
          onEcosystemSelected: (eco) =>
              setState(() => _selectedEcosystemFilter = eco),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Manifest Cards List
        if (filteredManifests.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: ShapeDecoration(
              color: AppColors.neutral12,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.neutral11),
              ),
            ),
            child: Center(
              child: Text(
                _showVulnerableOnly
                    ? 'No vulnerable packages found! All dependencies are secure.'
                    : (_showOutdatedOnly
                        ? 'No outdated packages found! All dependencies are up to date.'
                        : 'No dependencies match the search criteria.'),
                style: AppTypography.body(color: AppColors.neutral6),
              ),
            ),
          )
        else
          ...filteredManifests.map(
            (manifest) => manifestCard(
              manifest: manifest,
              relPath: _relativePath(manifest.path),
              isExpanded: (key) => _expandedItems.contains(key),
              onToggle: (key) {
                setState(() {
                  if (_expandedItems.contains(key)) {
                    _expandedItems.remove(key);
                  } else {
                    _expandedItems.add(key);
                  }
                });
              },
              onCopy: _copyToClipboard,
              onOpenUrl: (url) => _openUrl(url),
              formatRelativeDate: FormatUtils.formatRelativeDate,
            ),
          ),
      ],
    );
  }
}