import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

import 'app_icon.dart';

enum AppInputSize { small, medium, large }

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final AppSvgIcon? svgPrefixIcon;
  final VoidCallback? onPrefixTap;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final AppInputSize size;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.svgPrefixIcon,
    this.onPrefixTap,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.size = AppInputSize.medium,
    this.focusNode,
  });


  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _effectiveFocusNode;
  bool _isHovered = false;
  bool _isFocused = false;
  Color? _previousIconColor;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    // Sizing
    final double height;
    final EdgeInsets contentPadding;
    final TextStyle textStyle;
    final TextStyle hintStyle;
    final double iconSize;

    switch (widget.size) {
      case AppInputSize.small:
        height = 32.0;
        contentPadding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 0,
        );
        textStyle = AppTypography.caption();
        hintStyle = AppTypography.caption(color: AppColors.neutral7);
        iconSize = 16.0;
        break;
      case AppInputSize.medium:
        height = 40.0;
        contentPadding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 0,
        );
        textStyle = AppTypography.body();
        hintStyle = AppTypography.body(color: AppColors.neutral7);
        iconSize = 18.0;
        break;
      case AppInputSize.large:
        height = 48.0;
        contentPadding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 0,
        );
        textStyle = AppTypography.subtitle();
        hintStyle = AppTypography.subtitle(color: AppColors.neutral7);
        iconSize = 20.0;
        break;
    }

    // Border and Fill state colors
    Color fillColor = AppColors.neutral12;
    BorderSide borderSide = const BorderSide(
      color: AppColors.neutral11,
      width: 2,
    );
    Color iconColor = AppColors.neutral7;
    Color textColor = AppColors.neutral0;

    if (!widget.enabled) {
      fillColor = AppColors.neutral11;
      borderSide = const BorderSide(color: AppColors.neutral11, width: 2);
      iconColor = AppColors.neutral7;
      textColor = AppColors.neutral7;
    } else if (hasError) {
      borderSide = const BorderSide(color: AppColors.dangerBase, width: 2);
      iconColor = AppColors.dangerBase;
    } else if (_isFocused) {
      borderSide = const BorderSide(color: AppColors.neutral8, width: 2);
      iconColor = AppColors.primaryBase;
    } else if (_isHovered) {
      borderSide = const BorderSide(color: AppColors.neutral10, width: 2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: height,
            decoration: ShapeDecoration(
              color: fillColor,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(
                  widget.size == AppInputSize.small
                      ? 16
                      : widget.size == AppInputSize.medium
                      ? 20
                      : 24,
                ),
                side: borderSide,
              ),
            ),
            child: Row(
              children: [
                if (widget.svgPrefixIcon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: widget.onPrefixTap != null
                        ? IconButton(
                            icon: AppIcon(
                              widget.svgPrefixIcon!,
                              size: iconSize,
                              color: iconColor,
                            ),
                            color: iconColor,
                            onPressed: widget.enabled
                                ? widget.onPrefixTap
                                : null,
                            tooltip: 'Browse directory',
                            splashRadius: 16,
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: TweenAnimationBuilder<Color?>(
                              duration: const Duration(milliseconds: 150),
                              tween: ColorTween(
                                begin: _previousIconColor,
                                end: iconColor,
                              ),
                              onEnd: () => setState(
                                () => _previousIconColor = iconColor,
                              ),
                              builder: (context, animatedColor, child) {
                                final color = animatedColor ?? iconColor;
                                return AppIcon(
                                  widget.svgPrefixIcon!,
                                  size: iconSize,
                                  color: color,
                                );
                              },
                            ),
                          ),
                  ),
                ],
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: textStyle.copyWith(color: textColor),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _effectiveFocusNode,
                      enabled: widget.enabled,
                      readOnly: widget.readOnly,
                      autofocus: widget.autofocus,
                      obscureText: widget.obscureText,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: textStyle,

                      cursorColor: AppColors.primaryBase,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: hintStyle,
                        contentPadding: contentPadding,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                if (widget.suffixIcon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: widget.suffixIcon!,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: AppTypography.caption(color: AppColors.dangerBase),
          ),
        ],
      ],
    );
  }
}
