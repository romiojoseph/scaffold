import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exclusions_config.dart';
import '../services/shell_integration_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';
import 'common/app_toggle_switch.dart';

import '../models/thresholds_config.dart';
import 'threshold_settings_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final ExclusionsConfig config;
  final ThresholdsConfig thresholdsConfig;
  final ValueChanged<ExclusionsConfig> onSave;
  final ValueChanged<ThresholdsConfig> onSaveThresholds;

  const SettingsDialog({
    super.key,
    required this.config,
    required this.thresholdsConfig,
    required this.onSave,
    required this.onSaveThresholds,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late List<String> _patterns;
  late bool _enabled;
  late bool _gitignoreOnly;
  final TextEditingController _addController = TextEditingController();

  bool _shellUpdating = false;
  bool _jsonUpdating = false;
  bool? _enabledShell;
  bool? _jsonDefaultEnabled;
  String? _configDirPath;

  @override
  void initState() {
    super.initState();
    _patterns = List.from(widget.config.patterns);
    _enabled = widget.config.enabled;
    _gitignoreOnly = widget.config.gitignoreOnly;
    _loadShellState();
    _loadConfigDir();
  }

  Future<void> _loadConfigDir() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (mounted) {
        setState(() => _configDirPath = dir.path);
      }
    } catch (e) {
      debugPrint('Failed to load config directory: $e');
    }
  }

  Future<void> _openConfigFolder() async {
    final path = _configDirPath;
    if (path == null || !Directory(path).existsSync()) return;
    try {
      await Process.start('explorer.exe', [path]);
    } catch (e) {
      debugPrint('Failed to open config folder: $e');
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadShellState() async {
    final installed = await ShellIntegrationService.isInstalled();
    final jsonInstalled =
        await ShellIntegrationService.isJsonDefaultInstalled();
    if (mounted) {
      setState(() {
        _enabledShell = installed;
        _jsonDefaultEnabled = jsonInstalled;
      });
    }
  }

  Future<void> _toggleShell(bool enable) async {
    setState(() => _shellUpdating = true);
    if (enable) {
      await ShellIntegrationService.install();
    } else {
      await ShellIntegrationService.uninstall();
    }
    if (!mounted) return;
    setState(() {
      _enabledShell = enable;
      _shellUpdating = false;
    });
  }

  Future<void> _toggleJsonDefault(bool enable) async {
    setState(() => _jsonUpdating = true);
    final success = enable
        ? await ShellIntegrationService.installJsonDefault()
        : await ShellIntegrationService.uninstallJsonDefault();
    if (!mounted) return;
    setState(() {
      _jsonDefaultEnabled = success ? enable : _jsonDefaultEnabled;
      _jsonUpdating = false;
    });
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Windows registry update failed.')),
      );
    }
  }

  void _addPattern() {
    final input = _addController.text.trim();
    if (input.isEmpty) return;

    final newItems = input
        .split(',')
        .map((e) => e.trim().replaceAll('\\', '/')) // normalise separators
        .where((e) => e.isNotEmpty && !_patterns.contains(e))
        .toList();

    setState(() {
      _patterns.addAll(newItems);
      _addController.clear();
    });
  }

  void _togglePreset(String presetName, List<String> presetItems) {
    setState(() {
      final allPresent = presetItems.every((item) => _patterns.contains(item));
      if (allPresent) {
        _patterns.removeWhere((item) => presetItems.contains(item));
      } else {
        for (final item in presetItems) {
          if (!_patterns.contains(item)) {
            _patterns.add(item);
          }
        }
      }
    });
  }

  void _removePattern(int index) {
    setState(() {
      _patterns.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _patterns.clear();
    });
  }

  void _resetDefaults() {
    setState(() {
      _patterns = List.from(ExclusionsConfig.defaultExclusions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shellEnabled = _enabledShell ?? false;
    final jsonDefaultEnabled = _jsonDefaultEnabled ?? false;

    return Dialog(
      backgroundColor: AppColors.neutral11,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        height: 720,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Settings',
                  style: AppTypography.heading5(
                    color: AppColors.neutral3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.xBold,
                    color: AppColors.neutral6,
                    size: 18,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Shell Integration',
                    style: AppTypography.subtitle(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppToggleSwitch(
                    value: shellEnabled,
                    onChanged: _shellUpdating ? null : _toggleShell,
                    title: "Add 'Open with Scaffold' to folder context menu",
                    subtitle: _shellUpdating
                        ? 'Updating Windows registry...'
                        : (shellEnabled
                              ? 'Right-click any folder and choose "Open with Scaffold" to scan it instantly.'
                              : 'Disabled - right-clicking folders will not show Scaffold.'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppToggleSwitch(
                    value: jsonDefaultEnabled,
                    onChanged: _jsonUpdating ? null : _toggleJsonDefault,
                    title: "Set Scaffold as default app for .json files",
                    subtitle: _jsonUpdating
                        ? 'Updating Windows registry...'
                        : (jsonDefaultEnabled
                              ? 'Registered in Windows shell to handle .json files automatically.'
                              : 'Disabled - double-clicking .json files will use default viewer.'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.neutral12,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: AppColors.neutral10, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executable Path:',
                          style: AppTypography.body(color: AppColors.neutral3),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          Platform.resolvedExecutable,
                          style: AppTypography.caption(
                            color: AppColors.neutral5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.neutral12,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: AppColors.neutral10, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Config Folder Location:',
                          style: AppTypography.body(color: AppColors.neutral3),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          _configDirPath ?? 'Loading...',
                          style: AppTypography.caption(
                            color: AppColors.neutral5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'Open Folder',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.medium,
                          onPressed: _configDirPath == null
                              ? null
                              : _openConfigFolder,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.neutral10),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'File Line Thresholds',
                    style: AppTypography.subtitle(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Highlight files and show warning metrics in Statistics when lines exceed certain thresholds.',
                    style: AppTypography.caption(color: AppColors.neutral7),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => ThresholdSettingsDialog(
                          config: widget.thresholdsConfig,
                          onSave: widget.onSaveThresholds,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: ShapeDecoration(
                        color: AppColors.neutral12,
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: AppColors.neutral10,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configure Line Threshold Sliders',
                                  style: AppTypography.body(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.neutral3,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Customize maximum line thresholds for each extension',
                                  style: AppTypography.caption(
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.neutral6,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AppIcon(
                            AppSvgIcon.caretRightBold,
                            size: 16,
                            color: AppColors.neutral6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.neutral10),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'Exclusions & Filters',
                    style: AppTypography.subtitle(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppToggleSwitch(
                    value: _gitignoreOnly,
                    onChanged: (v) => setState(() => _gitignoreOnly = v),
                    title: 'Scan based on .gitignore',
                    subtitle: _gitignoreOnly
                        ? 'Active - uses root .gitignore file. Manual patterns still apply on top.'
                        : 'Disabled - standard exclusions config & manual patterns are applied.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppToggleSwitch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: 'Enable exclusions engine',
                    subtitle: _enabled
                        ? 'Manual exclusion patterns are applied during scanning.'
                        : 'Disabled - manual patterns are ignored (gitignore patterns still apply if that mode is on).',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Quick Preset Templates:',
                    style: AppTypography.body(
                      color: AppColors.neutral5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: ExclusionsConfig.presetTemplates.entries.map((
                      entry,
                    ) {
                      final active = entry.value.every(
                        (item) => _patterns.contains(item),
                      );
                      return FilterChip(
                        label: Text(entry.key),
                        selected: active,
                        selectedColor: AppColors.primaryBase.withAlpha(32),
                        checkmarkColor: AppColors.primaryBase,
                        labelStyle: AppTypography.caption(
                          color: active
                              ? AppColors.primaryBase
                              : AppColors.neutral6,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.neutral12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: active
                                ? AppColors.neutral13
                                : AppColors.neutral10,
                            width: 2,
                          ),
                        ),
                        onSelected: (_) =>
                            _togglePreset(entry.key, entry.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Add Custom Patterns',
                    style: AppTypography.caption(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _addController,
                          hintText: 'e.g. node_modules, *.log, assets/icons/*',
                          size: AppInputSize.medium,
                          onSubmitted: (_) => _addPattern(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: 'Add Pattern',
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.medium,
                        onPressed: _addPattern,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    children: [
                      Text(
                        'Active Exclusions (${_patterns.length}):',
                        style: AppTypography.subtitle(
                          color: AppColors.neutral6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      AppButton(
                        label: 'Reset Defaults',
                        variant: AppButtonVariant.text,
                        size: AppButtonSize.medium,
                        foregroundColor: AppColors.infoBase,
                        onPressed: _resetDefaults,
                      ),
                      AppButton(
                        label: 'Clear All',
                        variant: AppButtonVariant.text,
                        size: AppButtonSize.medium,
                        foregroundColor: AppColors.dangerBase,
                        onPressed: _patterns.isEmpty ? null : _clearAll,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_patterns.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.neutral12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'No exclusion patterns configured.',
                          style: AppTypography.body(color: AppColors.neutral7),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_patterns.length, (index) {
                      final item = _patterns[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.neutral12,
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppColors.neutral10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${index + 1}.',
                              style: AppTypography.body(
                                color: AppColors.neutral7,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                item,
                                style: AppTypography.body(
                                  color: AppColors.neutral3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const AppIcon(
                                AppSvgIcon.trash,
                                color: AppColors.neutral7,
                                size: 16,
                              ),
                              onPressed: () => _removePattern(index),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Save & Done',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  onPressed: () {
                    widget.onSave(
                      ExclusionsConfig(
                        patterns: _patterns,
                        enabled: _enabled,
                        gitignoreOnly: _gitignoreOnly,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
