import 'package:flutter/material.dart';
import '../models/dependency_info.dart';
import '../services/global_dependency_service.dart';
import '../services/version_checker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/clipboard_utils.dart';
import '../utils/dep_utils.dart';
import '../utils/url_utils.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_icon.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/deps/deps_progress_banner.dart';
import '../widgets/global_deps/global_deps_controls_bar.dart';
import '../widgets/global_deps/global_deps_ecosystem_chips.dart';
import '../widgets/global_deps/global_deps_stat_cards.dart';
import '../widgets/global_deps/global_matrix_container.dart';

class GlobalDependenciesScreen extends StatefulWidget {
  const GlobalDependenciesScreen({super.key});

  @override
  State<GlobalDependenciesScreen> createState() =>
      _GlobalDependenciesScreenState();
}

class _GlobalDependenciesScreenState extends State<GlobalDependenciesScreen> {
  final GlobalDependencyService _globalService = GlobalDependencyService();
  final VersionCheckerService _checkerService = VersionCheckerService();
  final TextEditingController _searchController = TextEditingController();

  List<GlobalPackageGroup> _packages = [];
  int _projectCount = 0;
  bool _isLoading = true;
  bool _isChecking = false;
  String _checkingMessage = '';
  int _checkedCount = 0;

  String _searchFilter = '';
  Ecosystem? _selectedEcosystem;
  bool _showDivergentOnly = false;
  bool _showOutdatedOnly = false;
  bool _showVulnerableOnly = false;
  final Set<String> _expandedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadGlobalCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _checkerService.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalCatalog() async {
    setState(() => _isLoading = true);
    try {
      final list = await _globalService.getGlobalPackageCatalog();
      final pCount = await _globalService.getProjectCount();
      if (mounted) {
        setState(() {
          _packages = list;
          _projectCount = pCount;
          _isLoading = false;
        });

        if (_packages.isNotEmpty) {
          _checkAllRegistries();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAllRegistries({bool forceRefresh = false}) async {
    if (_packages.isEmpty) return;

    setState(() {
      _isChecking = true;
      _checkedCount = 0;
      _checkingMessage = forceRefresh
          ? 'Refreshing latest versions across registries...'
          : 'Loading package details...';
    });

    final itemsToCheck = _packages.map((pkg) {
      final firstUsage = pkg.usages.first;
      return DependencyItem(
        name: pkg.name,
        currentConstraint: firstUsage.currentConstraint,
        cleanCurrentVersion: firstUsage.cleanCurrentVersion,
        manifestPath: firstUsage.projectPath,
        ecosystem: pkg.ecosystem,
      );
    }).toList();

    try {
      await _checkerService.checkDependencies(
        itemsToCheck,
        forceRefresh: forceRefresh,
        onProgress: (completed, total, current) {
          if (!mounted) return;
          setState(() {
            _checkedCount = completed;
            _checkingMessage =
                'Checking $completed/$total: ${current.ecosystem.name}/${current.name}...';

            final index = _packages.indexWhere(
              (p) => p.name == current.name && p.ecosystem == current.ecosystem,
            );
            if (index != -1) {
              final group = _packages[index];
              group.latestVersion = current.latestVersion;
              group.latestPublishedAt = current.latestPublishedAt;
              group.description = current.description;
              group.repositoryUrl = current.repositoryUrl;
              group.changelogUrl = current.changelogUrl;
              group.license = current.license;
              group.vulnerabilityIds = current.vulnerabilityIds;
              group.vulnerabilitySummary = current.vulnerabilitySummary;
            }
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checkingMessage = '';
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

  @override
  Widget build(BuildContext context) {
    // Metric totals
    int totalPackages = _packages.length;
    int divergentCount = _packages.where((p) => p.hasVersionDivergence).length;
    int vulnerableCount = _packages.where((p) => p.hasVulnerabilities).length;
    int totalOutdatedUsages = 0;

    for (final p in _packages) {
      totalOutdatedUsages += p.outdatedUsagesCount;
    }

    // Filtered list
    final filtered = _packages.where((p) {
      if (_selectedEcosystem != null && p.ecosystem != _selectedEcosystem) {
        return false;
      }
      if (_showDivergentOnly && !p.hasVersionDivergence) {
        return false;
      }
      if (_showOutdatedOnly && p.outdatedUsagesCount == 0) {
        return false;
      }
      if (_showVulnerableOnly && !p.hasVulnerabilities) {
        return false;
      }
      if (_searchFilter.isNotEmpty) {
        final q = _searchFilter.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesDesc = p.description?.toLowerCase().contains(q) ?? false;
        final matchesProject = p.usages.any(
          (u) =>
              u.projectName.toLowerCase().contains(q) ||
              u.projectPath.toLowerCase().contains(q),
        );
        return matchesName || matchesDesc || matchesProject;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral12,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.neutral13,
                border: Border(bottom: BorderSide(color: AppColors.neutral11)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const AppIcon(
                      AppSvgIcon.arrowLeftBold,
                      size: 16,
                      color: AppColors.neutral4,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back to Scanner',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Global Dependency Matrix',
                    style: AppTypography.subtitle(
                      color: AppColors.neutral4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    label: _isChecking ? 'Checking...' : 'Refresh All',
                    svgIcon: AppSvgIcon.arrowCounterClockwise,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                    isLoading: _isChecking,
                    onPressed: _isChecking
                        ? null
                        : () => _checkAllRegistries(forceRefresh: true),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBase,
                        ),
                      ),
                    )
                  : _packages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppIcon(
                            AppSvgIcon.folders,
                            size: 56,
                            color: AppColors.neutral8,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No Global Dependencies Recorded',
                            style: AppTypography.heading6(
                              color: AppColors.neutral5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Scan any project in the main window and its dependencies will be indexed here automatically.',
                            style: AppTypography.body(
                              color: AppColors.neutral6,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        // Metric Overview Cards
                        globalDepsStatCards(
                          projectCount: _projectCount,
                          totalPackages: totalPackages,
                          divergentCount: divergentCount,
                          totalOutdatedUsages: totalOutdatedUsages,
                          vulnerableCount: vulnerableCount,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Checking Progress Banner
                        if (_isChecking) ...[
                          depsProgressBanner(
                            message: _checkingMessage,
                            checkedCount: _checkedCount,
                            totalToCheck: _packages.length,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Controls Bar
                        globalDepsControlsBar(
                          searchController: _searchController,
                          searchFilter: _searchFilter,
                          onFilterChanged: (val) =>
                              setState(() => _searchFilter = val),
                          showDivergentOnly: _showDivergentOnly,
                          onDivergentToggled: () => setState(
                            () => _showDivergentOnly = !_showDivergentOnly,
                          ),
                          showOutdatedOnly: _showOutdatedOnly,
                          onOutdatedToggled: () => setState(
                            () => _showOutdatedOnly = !_showOutdatedOnly,
                          ),
                          showVulnerableOnly: _showVulnerableOnly,
                          onVulnerableToggled: () => setState(
                            () => _showVulnerableOnly = !_showVulnerableOnly,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Ecosystem Filter Chips
                        globalDepsEcosystemChips(
                          packages: _packages,
                          selectedEcosystem: _selectedEcosystem,
                          onEcosystemSelected: (eco) =>
                              setState(() => _selectedEcosystem = eco),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Main Matrix Table
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: AppColors.neutral11,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.neutral10),
                            ),
                            child: Center(
                              child: Text(
                                'No packages match the current filters.',
                                style: AppTypography.body(
                                  color: AppColors.neutral6,
                                ),
                              ),
                            ),
                          )
                        else
                          globalMatrixContainer(
                            packages: filtered,
                            isExpanded: (pkg) => _expandedKeys.contains(
                              '${pkg.ecosystem.name}:${pkg.name}',
                            ),
                            onToggle: (pkg) {
                              final key = '${pkg.ecosystem.name}:${pkg.name}';
                              setState(() {
                                if (_expandedKeys.contains(key)) {
                                  _expandedKeys.remove(key);
                                } else {
                                  _expandedKeys.add(key);
                                }
                              });
                            },
                            onCopy: _copyToClipboard,
                            onOpenUrl: (url) => _openUrl(url),
                            generateUpgradeCommand:
                                generateProjectUpgradeCommand,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
