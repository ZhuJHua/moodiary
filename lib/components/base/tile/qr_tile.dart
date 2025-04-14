import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/popup.dart';
import 'package:moodiary/components/base/qr/qr_code.dart';
import 'package:moodiary/components/base/qr/qr_scanner.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/notice_util.dart';

class QrInputTile extends StatelessWidget {
  final String title;
  final String? subtitle;

  final String? prefix;

  final String value;
  final bool withStyle;

  final void Function(String)? onValue;

  final Widget? leading;

  final VoidCallback? onScan;
  final VoidCallback? onInput;

  const QrInputTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onValue,
    this.withStyle = true,
    this.onScan,
    this.onInput,
    this.leading,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    const validDuration = Duration(minutes: 2);
    return AdaptiveListTile(
      title: Text(title),
      leading: leading,
      subtitle:
          subtitle ??
          (value.isNotNullOrBlank
              ? Text(context.l10n.hasOption)
              : Text(context.l10n.noOption)),
      tileColor:
          withStyle ? context.theme.colorScheme.surfaceContainerLow : null,
      shape:
          withStyle
              ? const RoundedRectangleBorder(
                borderRadius: AppBorderRadius.mediumBorderRadius,
              )
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              return IconButton.filled(
                tooltip: context.l10n.genQrCodeTooltip,
                onPressed: () {
                  if (value.isBlank) {
                    toast.info(message: context.l10n.genQrCodeError1(title));
                    return;
                  }
                  showPopupWidget(
                    targetContext: context,
                    child: EncryptQrCode(
                      data: value,
                      size: 96,
                      prefix: prefix,
                      validDuration: validDuration,
                    ),
                  );
                },
                icon: Icon(
                  Icons.qr_code_rounded,
                  color: context.theme.colorScheme.onPrimary,
                ),
              );
            },
          ),
          IconButton.filled(
            tooltip: context.l10n.inputTooltip,
            onPressed: () async {
              final choice = await showDialog<String?>(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: Text(context.l10n.inputMethodTitle),
                    children: [
                      SimpleDialogOption(
                        child: Row(
                          spacing: 8.0,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded),
                            Text(context.l10n.inputMethodScanQrCode),
                          ],
                        ),
                        onPressed: () {
                          Navigator.pop(context, 'qr');
                        },
                      ),
                      SimpleDialogOption(
                        child: Row(
                          spacing: 8.0,
                          children: [
                            const Icon(Icons.keyboard_rounded),
                            Text(context.l10n.inputMethodHandelInput),
                          ],
                        ),
                        onPressed: () {
                          Navigator.pop(context, 'input');
                        },
                      ),
                    ],
                  );
                },
              );
              if (choice == null) return;
              if (choice == 'qr' && context.mounted) {
                if (onScan != null) {
                  onScan?.call();
                  return;
                }
                final res = await showQrScanner(
                  context: context,
                  validDuration: validDuration,
                  prefix: prefix,
                );
                if (res != null) {
                  onValue?.call(res);
                }
              }
              if (choice == 'input' && context.mounted) {
                if (onInput != null) {
                  onInput?.call();
                  return;
                }
                final res = await showTextInputDialog(
                  context: context,
                  textFields: [DialogTextField(initialText: value)],
                  title: title,
                  message: context.l10n.getKeyFromConsole,
                  style: AdaptiveStyle.material,
                );
                if (res != null && res.isNotEmpty) {
                  final value = res[0];
                  onValue?.call(value);
                }
              }
            },
            icon: Icon(
              Icons.input_rounded,
              color: context.theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
