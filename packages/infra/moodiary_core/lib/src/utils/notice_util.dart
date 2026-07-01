import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary_core/src/values/border.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_core/src/utils/theme_util.dart';

/// 轻量提示工具，所有方法 fire-and-forget。[bindPage] 固定 false 让 toast 全局生效，
/// 避免页面 pop 时被强制收起。
class NoticeUtil {
  NoticeUtil._();

  static final NoticeUtil _instance = NoticeUtil._();

  factory NoticeUtil() => _instance;

  void info({required String message}) {
    SmartDialog.show(
      alignment: Alignment.center,
      animationType: SmartAnimationType.centerFade_otherSlide,
      clickMaskDismiss: false,
      usePenetrate: true,
      displayTime: const Duration(seconds: 2),
      backType: SmartBackType.ignore,
      debounce: true,
      bindPage: false,
      maskColor: Colors.transparent,
      builder: (context) {
        return _build(
          context: context,
          message: message,
          icon: FaIcon(
            FontAwesomeIcons.circleInfo,
            color: context.theme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
        );
      },
    );
  }

  void loading({String? message}) {
    SmartDialog.showLoading(
      msg: '',
      animationType: SmartAnimationType.centerFade_otherSlide,
      alignment: Alignment.center,
      clickMaskDismiss: false,
      maskColor: Colors.transparent,
      backType: SmartBackType.block,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.l10n.toastLoading,
          icon: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              padding: EdgeInsets.zero,
              strokeWidth: 2.5,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  void error({String? message}) {
    SmartDialog.show(
      alignment: Alignment.center,
      animationType: SmartAnimationType.centerFade_otherSlide,
      displayTime: const Duration(seconds: 2),
      clickMaskDismiss: false,
      maskColor: Colors.transparent,
      backType: SmartBackType.ignore,
      usePenetrate: true,
      debounce: true,
      bindPage: false,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.l10n.toastError,
          icon: FaIcon(
            FontAwesomeIcons.solidCircleXmark,
            color: context.theme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
        );
      },
    );
  }

  void success({String? message}) {
    SmartDialog.show(
      alignment: Alignment.center,
      animationType: SmartAnimationType.centerFade_otherSlide,
      displayTime: const Duration(seconds: 2),
      clickMaskDismiss: false,
      usePenetrate: true,
      backType: SmartBackType.ignore,
      maskColor: Colors.transparent,
      debounce: true,
      bindPage: false,
      builder: (context) {
        return _build(
          context: context,
          message: message ?? context.l10n.toastSuccess,
          icon: FaIcon(
            FontAwesomeIcons.solidCircleCheck,
            color: context.theme.colorScheme.onSurfaceVariant,
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
      mainAxisSize: MainAxisSize.min,
      spacing: 8.0,
      children: [
        icon,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.width, minWidth: 60),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.9,
        ),
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: Padding(padding: const EdgeInsets.all(16.0), child: widget),
    );
  }
}

final toast = NoticeUtil();
