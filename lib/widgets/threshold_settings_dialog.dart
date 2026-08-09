import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/thresholds_config.dart';
import '../services/icon_mapping_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';

class ThresholdSliderItem extends StatelessWidget {
  final String extension;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onResetSingle;

  const ThresholdSliderItem({
    super.key,
    required this.extension,
    required this.value,
    required this.onChanged,
    required this.onResetSingle,
  });

  @override
  Widget build(BuildContext context) {
    final iconSvg = IconMappingConfig.instance.getIconForExtension(extension);
    final isCustom =
        value !=
        (ThresholdsConfig.defaultThresholds[extension] ??
            ThresholdsConfig.fallbackThreshold);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.neutral12,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isCustom
                ? AppColors.primaryBase.withValues(alpha: 0.6)
                : AppColors.neutral10,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/mapping/$iconSvg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.neutral11,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '.$extension',
                  style: AppTypography.label(color: AppColors.primaryBase),
                ),
              ),
              const Spacer(),
              Text(
                '$value lines',
                style: AppTypography.body(
                  color: isCustom ? AppColors.primaryBase : AppColors.neutral4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Reset to default',
                  child: AppButton(
                    svgIcon: AppSvgIcon.arrowCounterClockwise,
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.small,
                    foregroundColor: AppColors.neutral6,
                    onPressed: onResetSingle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppColors.primaryBase,
              inactiveTrackColor: AppColors.neutral10,
              thumbColor: AppColors.primaryBase,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayColor: AppColors.primaryBase.withValues(alpha: 0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble().clamp(50, 3000),
              min: 50,
              max: 3000,
              divisions: 59,
              onChanged: (val) => onChanged(val.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class ThresholdSettingsDialog extends StatefulWidget {
  final ThresholdsConfig config;
  final ValueChanged<ThresholdsConfig> onSave;

  const ThresholdSettingsDialog({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<ThresholdSettingsDialog> createState() =>
      _ThresholdSettingsDialogState();
}

class _ThresholdSettingsDialogState extends State<ThresholdSettingsDialog> {
  late Map<String, int> _thresholds;
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _thresholds = Map.from(widget.config.thresholds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetAll() {
    setState(() {
      _thresholds = Map.from(ThresholdsConfig.defaultThresholds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allExts = IconMappingConfig.instance.allKnownExtensions;
    final filteredExts = allExts.where((ext) {
      if (_filter.isEmpty) return true;
      return ext.toLowerCase().contains(_filter);
    }).toList();

    return Dialog(
      backgroundColor: AppColors.neutral11,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        height: 720,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Line Threshold Settings',
                      style: AppTypography.heading5(
                        color: AppColors.neutral3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Adjust line limit thresholds per file extension to highlight large files in Stats',
                      style: AppTypography.caption(color: AppColors.neutral6),
                    ),
                  ],
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
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: 'Search extension (e.g. dart, js, py)...',
                    svgPrefixIcon: AppSvgIcon.magnifyingGlass,
                    size: AppInputSize.small,
                    onChanged: (v) =>
                        setState(() => _filter = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Reset All Defaults',
                  svgIcon: AppSvgIcon.arrowCounterClockwise,
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.small,
                  foregroundColor: AppColors.infoBase,
                  onPressed: _resetAll,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.builder(
                itemCount: filteredExts.length,
                itemBuilder: (context, index) {
                  final ext = filteredExts[index];
                  final currentVal =
                      _thresholds[ext] ??
                      (ThresholdsConfig.defaultThresholds[ext] ??
                          ThresholdsConfig.fallbackThreshold);

                  return ThresholdSliderItem(
                    extension: ext,
                    value: currentVal,
                    onChanged: (newVal) {
                      setState(() {
                        _thresholds[ext] = newVal;
                      });
                    },
                    onResetSingle: () {
                      setState(() {
                        _thresholds[ext] =
                            ThresholdsConfig.defaultThresholds[ext] ??
                            ThresholdsConfig.fallbackThreshold;
                      });
                    },
                  );
                },
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
                  label: 'Save & Apply',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  onPressed: () {
                    widget.onSave(ThresholdsConfig(thresholds: _thresholds));
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
