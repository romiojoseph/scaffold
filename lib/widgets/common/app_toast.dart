import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icon.dart';

enum AppToastType { success, error, warning, info }

class AppToast {
  static OverlayEntry? _currentEntry;
  static _AppToastWidgetState? _currentState;

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 6),
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    if (_currentEntry != null &&
        _currentState != null &&
        _currentState!.mounted) {
      _currentState!.update(message: message, type: type, duration: duration);
      return;
    }

    _currentEntry?.remove();
    _currentEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _AppToastWidget(
          message: message,
          type: type,
          duration: duration,
          onDismiss: () {
            if (_currentEntry == entry) {
              entry.remove();
              _currentEntry = null;
              _currentState = null;
            }
          },
          onStateCreated: (state) {
            _currentState = state;
          },
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.error,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.info,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.warning,
      duration: duration,
    );
  }
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final AppToastType type;
  final Duration duration;
  final VoidCallback onDismiss;
  final ValueChanged<_AppToastWidgetState> onStateCreated;

  const _AppToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
    required this.onStateCreated,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  late String _message;
  late AppToastType _type;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    _type = widget.type;
    _duration = widget.duration;
    widget.onStateCreated(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_duration, _dismiss);
  }

  void update({
    required String message,
    required AppToastType type,
    required Duration duration,
  }) {
    setState(() {
      _message = message;
      _type = type;
      _duration = duration;
    });
    _controller.forward(from: 0.7);
    _startTimer();
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (_type) {
      case AppToastType.success:
        return AppColors.successBase;
      case AppToastType.error:
        return AppColors.dangerBase;
      case AppToastType.warning:
        return AppColors.warningBase;
      case AppToastType.info:
        return AppColors.primaryBase;
    }
  }

  AppSvgIcon get _icon {
    switch (_type) {
      case AppToastType.success:
        return AppSvgIcon.checkCircleFill;
      case AppToastType.error:
        return AppSvgIcon.xBold;
      case AppToastType.warning:
        return AppSvgIcon.shieldWarningFill;
      case AppToastType.info:
        return AppSvgIcon.infoDuotone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: ShapeDecoration(
                color: AppColors.neutral12,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: accent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: AppColors.neutral13.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(_icon, size: 15, color: accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      _message,
                      style: AppTypography.body(
                        color: AppColors.neutral1,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AppIcon(
                        AppSvgIcon.xBold,
                        size: 12,
                        color: AppColors.neutral6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
