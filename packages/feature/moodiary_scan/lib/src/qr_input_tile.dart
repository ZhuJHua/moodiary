import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';

import 'encrypt_qr_code.dart';

/// 生成二维码 / 输入两键的 ListTile。[prefix] 用于扫码端校验，避免误扫到其他场景的二维码。
class QrInputTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final String? prefix;
  final Widget? leading;

  final bool isFirst;
  final bool isLast;

  final void Function(String value)? onValue;

  final VoidCallback? onInput;

  /// 二维码有效时间，也是扫码端解密容差。
  final Duration validDuration;

  final String? hintText;

  final bool obscureText;

  const QrInputTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.prefix,
    this.leading,
    this.onValue,
    this.onInput,
    this.isFirst = false,
    this.isLast = false,
    this.validDuration = const Duration(minutes: 2),
    this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final hasValue = value.trim().isNotEmpty;
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: title,
      leading: leading,
      subtitle: subtitle ?? (hasValue ? '已配置' : '未配置'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Builder 拿到按钮自身的 context —— showAttach 用它定位浮窗，
          // 否则会用 ListTile 的根 context（屏幕左上角）。
          Builder(
            builder: (btnContext) => IconButton.filledTonal(
              tooltip: '生成二维码',
              icon: const Icon(Icons.qr_code_rounded),
              onPressed: () {
                if (!hasValue) {
                  toast.info(message: '$title 暂未配置，无法生成');
                  return;
                }
                showPopupWidget(
                  targetContext: btnContext,
                  child: EncryptQrCode(
                    data: value,
                    prefix: prefix,
                    size: 160,
                    validDuration: validDuration,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: '输入',
            icon: Icon(Icons.input_rounded, color: scheme.onPrimary),
            onPressed: () => _showInputDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscureText,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onValue?.call(result);
  }
}
