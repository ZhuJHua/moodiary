import 'package:flutter/material.dart';
import 'package:mui/mui.dart';

/// 轻量提示工具，所有方法 fire-and-forget。[bindPage] 固定 false 让 toast 全局生效，
/// 避免页面 pop 时被强制收起。
class Toast {
  Toast._();

  static final Toast _instance = ._();

  factory Toast() => _instance;

  void info({required String message}) {
    SmartDialog.show(
      alignment: .center,
      animationType: .centerFade_otherSlide,
      clickMaskDismiss: false,
      usePenetrate: true,
      displayTime: const Duration(seconds: 2),
      backType: .ignore,
      debounce: true,
      bindPage: false,
      maskColor: Colors.transparent,
      builder: (context) {
        return _build(
          context: context,
          message: message,
          icon: Icon(
            LucideIcons.info,
            color: context.theme.colors.onInverseSurface,
            size: 24,
          ),
        );
      },
    );
  }

  void loading({String? message}) {
    SmartDialog.showLoading(
      msg: '',
      animationType: .centerFade_otherSlide,
      alignment: .center,
      clickMaskDismiss: false,
      maskColor: Colors.transparent,
      backType: .block,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.muiL10n.toastLoading,
          icon: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              padding: .zero,
              strokeWidth: 2.5,
              color: context.theme.colors.onInverseSurface,
            ),
          ),
        );
      },
    );
  }

  void error({String? message}) {
    SmartDialog.show(
      alignment: .center,
      animationType: .centerFade_otherSlide,
      displayTime: const Duration(seconds: 2),
      clickMaskDismiss: false,
      maskColor: Colors.transparent,
      backType: .ignore,
      usePenetrate: true,
      debounce: true,
      bindPage: false,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.muiL10n.toastError,
          icon: Icon(
            LucideIcons.circleX,
            color: context.theme.colors.onInverseSurface,
            size: 24,
          ),
        );
      },
    );
  }

  void success({String? message}) {
    SmartDialog.show(
      alignment: .center,
      animationType: .centerFade_otherSlide,
      displayTime: const Duration(seconds: 2),
      clickMaskDismiss: false,
      usePenetrate: true,
      backType: .ignore,
      maskColor: Colors.transparent,
      debounce: true,
      bindPage: false,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.muiL10n.toastSuccess,
          icon: Icon(
            LucideIcons.circleCheck,
            color: context.theme.colors.onInverseSurface,
            size: 24,
          ),
        );
      },
    );
  }

  Future<void> dismiss() async {
    await SmartDialog.dismiss();
  }

  Widget _build({
    required BuildContext context,
    required String message,
    required Widget icon,
  }) {
    Widget? widget;
    final size = MediaQuery.sizeOf(context);
    widget = Column(
      mainAxisSize: .min,
      spacing: 8.0,
      children: [
        icon,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.width, minWidth: 60),
          child: Text(
            message,
            textAlign: .center,
            style: context.theme.typography.titleSmall.onInverseSurface,
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colors.inverseSurface.withValues(alpha: 0.9),
        borderRadius: MuiRadius.md,
      ),
      child: Padding(padding: const .all(16.0), child: widget),
    );
  }
}

final toast = Toast();
