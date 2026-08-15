import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

import 'app_icon.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, text }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String? label;
  final AppSvgIcon? svgIcon;
  final Widget? customIcon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool fullWidth;
  final bool isLoading;
  final Color? foregroundColor;
  final Color? hoverForegroundColor;
  final Color? disabledForegroundColor;

  const AppButton({
    super.key,
    this.label,
    this.svgIcon,
    this.customIcon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.fullWidth = false,
    this.isLoading = false,
    this.foregroundColor,
    this.hoverForegroundColor,
    this.disabledForegroundColor,
  }) : assert(
         label != null || svgIcon != null || customIcon != null,
         'AppButton must have a label or an icon',
       );

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  Color? _previousForeground;
  Color? _previousBackground;
  Color? _previousBorder;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    // Dimensions
    final double height;
    final EdgeInsets padding;
    final TextStyle textStyle;
    final double iconSize;

    switch (widget.size) {
      case AppButtonSize.small:
        height = 32.0;
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 0,
        );
        textStyle = AppTypography.caption(fontWeight: FontWeight.w500);
        iconSize = 14.0;
        break;
      case AppButtonSize.medium:
        height = 40.0;
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 0,
        );
        textStyle = AppTypography.body(fontWeight: FontWeight.w500);
        iconSize = 18.0;
        break;
      case AppButtonSize.large:
        height = 48.0;
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 0,
        );
        textStyle = AppTypography.subtitle(fontWeight: FontWeight.w500);
        iconSize = 20.0;
        break;
    }

    // Colors according to variant & state
    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide = BorderSide.none;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        if (isDisabled) {
          backgroundColor = AppColors.neutral9;
          foregroundColor = AppColors.neutral7;
          borderSide = const BorderSide(color: AppColors.neutral10, width: 2);
        } else if (_isHovered) {
          backgroundColor = AppColors.primaryHover;
          foregroundColor = AppColors.neutral13;
          borderSide = const BorderSide(
            color: AppColors.primaryAccent,
            width: 2,
          );
        } else {
          backgroundColor = AppColors.primaryBase;
          foregroundColor = AppColors.neutral13;
          borderSide = const BorderSide(
            color: AppColors.primaryAccent,
            width: 2,
          );
        }
        break;

      case AppButtonVariant.secondary:
        if (isDisabled) {
          backgroundColor = AppColors.neutral11;
          foregroundColor = AppColors.neutral8;
        } else if (_isHovered) {
          backgroundColor = AppColors.neutral9;
          foregroundColor = AppColors.neutral0;
        } else {
          backgroundColor = AppColors.neutral10;
          foregroundColor = AppColors.neutral1;
        }
        break;

      case AppButtonVariant.outline:
        backgroundColor = _isHovered && !isDisabled
            ? AppColors.neutral11
            : Colors.transparent;
        if (isDisabled) {
          foregroundColor = AppColors.neutral8;
          borderSide = const BorderSide(color: AppColors.neutral11, width: 2);
        } else if (_isHovered) {
          foregroundColor = AppColors.neutral0;
          borderSide = const BorderSide(color: AppColors.neutral10, width: 2);
        } else {
          foregroundColor = AppColors.neutral5;
          borderSide = const BorderSide(color: AppColors.neutral10, width: 2);
        }
        break;

      case AppButtonVariant.ghost:
        if (isDisabled) {
          backgroundColor = Colors.transparent;
          foregroundColor = AppColors.neutral8;
        } else if (_isHovered) {
          backgroundColor = AppColors.neutral11;
          foregroundColor = AppColors.neutral0;
        } else {
          backgroundColor = Colors.transparent;
          foregroundColor = AppColors.neutral4;
        }
        break;

      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        if (isDisabled) {
          foregroundColor = AppColors.neutral8;
        } else if (_isHovered) {
          foregroundColor = AppColors.neutral0;
        } else {
          foregroundColor = AppColors.neutral4;
        }
        break;
    }

    final Color? baseColor = widget.foregroundColor;
    if (baseColor != null) {
      foregroundColor = baseColor;
    }
    if (isDisabled) {
      if (widget.disabledForegroundColor != null) {
        foregroundColor = widget.disabledForegroundColor!;
      } else if (baseColor != null) {
        foregroundColor = baseColor.withValues(alpha: 0.4);
      }
    } else if (_isHovered) {
      foregroundColor =
          widget.hoverForegroundColor ??
          (baseColor != null ? _brighten(baseColor) : foregroundColor);
    }

    final BorderRadius borderRadius;
    switch (widget.size) {
      case AppButtonSize.small:
        borderRadius = const BorderRadius.all(Radius.circular(16));
        break;
      case AppButtonSize.medium:
        borderRadius = const BorderRadius.all(Radius.circular(20));
        break;
      case AppButtonSize.large:
        borderRadius = const BorderRadius.all(Radius.circular(24));
        break;
    }

    final Color borderColor;
    final double borderWidth;
    if (_isFocused && !isDisabled) {
      borderColor = AppColors.primaryBase;
      borderWidth = 2;
    } else {
      borderColor = borderSide.color;
      borderWidth = borderSide.width;
    }

    return FocusableActionDetector(
      onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
      onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        constraints: BoxConstraints(
          minWidth: widget.label == null ? height : 0,
        ),
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 150),
          tween: ColorTween(begin: _previousBackground, end: backgroundColor),
          onEnd: () => setState(() => _previousBackground = backgroundColor),
          builder: (context, animatedBackground, child) {
            return TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 150),
              tween: ColorTween(begin: _previousBorder, end: borderColor),
              onEnd: () => setState(() => _previousBorder = borderColor),
              builder: (context, animatedBorder, child) {
                return Material(
                  color: animatedBackground ?? backgroundColor,
                  shape: ContinuousRectangleBorder(
                    borderRadius: borderRadius,
                    side: borderWidth > 0
                        ? BorderSide(
                            color: animatedBorder ?? borderColor,
                            width: borderWidth,
                          )
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isDisabled ? null : widget.onPressed,
                    mouseCursor: isDisabled
                        ? SystemMouseCursors.forbidden
                        : SystemMouseCursors.click,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: widget.variant == AppButtonVariant.text
                        ? Colors.transparent
                        : AppColors.neutral0.withValues(alpha: 0.1),
                    highlightColor: widget.variant == AppButtonVariant.text
                        ? Colors.transparent
                        : AppColors.neutral0.withValues(alpha: 0.05),
                    borderRadius: widget.size == AppButtonSize.small
                        ? BorderRadius.circular(16)
                        : widget.size == AppButtonSize.medium
                        ? BorderRadius.circular(20)
                        : BorderRadius.circular(24),
                    child: Padding(
                      padding: widget.label == null ? EdgeInsets.zero : padding,
                      child: Center(
                        widthFactor: widget.fullWidth ? double.infinity : 1.0,
                        child: TweenAnimationBuilder<Color?>(
                          duration: const Duration(milliseconds: 150),
                          tween: ColorTween(
                            begin: _previousForeground,
                            end: foregroundColor,
                          ),
                          onEnd: () => setState(
                            () => _previousForeground = foregroundColor,
                          ),
                          builder: (context, animatedColor, child) {
                            final color = animatedColor ?? foregroundColor;
                            return _buildContent(iconSize, textStyle, color);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _brighten(Color color, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + amount).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + amount * 0.3).clamp(0.0, 1.0))
        .toColor();
  }

  Widget _buildContent(double iconSize, TextStyle textStyle, Color color) {
    final iconWidget = widget.isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        : widget.customIcon ??
              (widget.svgIcon != null
                  ? AppIcon(widget.svgIcon!, size: iconSize, color: color)
                  : null);

    if (iconWidget != null && widget.label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            widget.label!,
            style: textStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (iconWidget != null) {
      return iconWidget;
    } else {
      return Text(
        widget.label!,
        style: textStyle.copyWith(
          color: color,
          fontWeight: widget.variant == AppButtonVariant.text
              ? FontWeight.w600
              : textStyle.fontWeight,
        ),
      );
    }
  }
}
