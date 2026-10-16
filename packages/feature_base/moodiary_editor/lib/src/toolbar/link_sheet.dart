import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

typedef LinkInput = ({String text, String href});

Future<LinkInput?> showLinkSheet(
  BuildContext context, {
  String text = '',
  String href = '',
}) {
  return MSheet.show<LinkInput>(
    context,
    builder: (_) => _LinkSheet(text: text, href: href),
  );
}

class _LinkSheet extends StatefulWidget {
  final String text;
  final String href;

  const _LinkSheet({required this.text, required this.href});

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _text = TextEditingController(text: widget.text);
  late final _href = TextEditingController(text: widget.href);

  @override
  void dispose() {
    _text.dispose();
    _href.dispose();
    super.dispose();
  }

  void _submit() {
    final href = _href.text.trim();
    if (href.isEmpty) return;
    // 预填的是截断过的选中文字，没改就别拿它覆盖正文
    final text = _text.text == widget.text ? '' : _text.text.trim();
    Navigator.of(context).pop((text: text, href: href));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return MSheetScaffold<void>(
      title: widget.href.isEmpty ? t.addLinkTitle : t.editLinkTitle,
      actions: [
        MAction(label: context.l10n.common.cancel),
        MAction(
          label: context.l10n.common.ok,
          isPrimary: true,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          MField(controller: _text, label: t.linkText, textInputAction: .next),
          MField(
            controller: _href,
            label: t.linkUrl,
            autofocus: widget.text.isNotEmpty && widget.href.isEmpty,
            keyboardType: .url,
            textInputAction: .done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

Future<String?> showDividerLabelSheet(BuildContext context, String? label) {
  return MSheet.show<String>(
    context,
    builder: (_) => _DividerLabelSheet(label: label ?? ''),
  );
}

class _DividerLabelSheet extends StatefulWidget {
  final String label;

  const _DividerLabelSheet({required this.label});

  @override
  State<_DividerLabelSheet> createState() => _DividerLabelSheetState();
}

class _DividerLabelSheetState extends State<_DividerLabelSheet> {
  late final _label = TextEditingController(text: widget.label);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_label.text.trim());

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return MSheetScaffold<void>(
      title: t.dividerText,
      actions: [
        MAction(label: context.l10n.common.cancel),
        MAction(
          label: context.l10n.common.ok,
          isPrimary: true,
          onPressed: _submit,
        ),
      ],
      child: MField(
        controller: _label,
        label: t.dividerLabel,
        autofocus: true,
        maxLength: 24,
        textInputAction: .done,
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}

Future<String?> showMediaNameSheet(
  BuildContext context,
  String? name, {
  required bool required,
  String? suffix,
}) {
  return MSheet.show<String>(
    context,
    builder: (_) =>
        _MediaNameSheet(name: name ?? '', required: required, suffix: suffix),
  );
}

class _MediaNameSheet extends StatefulWidget {
  final String name;
  final bool required;
  final String? suffix;

  const _MediaNameSheet({
    required this.name,
    required this.required,
    this.suffix,
  });

  @override
  State<_MediaNameSheet> createState() => _MediaNameSheetState();
}

class _MediaNameSheetState extends State<_MediaNameSheet> {
  late final _name = TextEditingController(text: widget.name)
    ..addListener(() => setState(() {}));

  bool get _valid => !widget.required || _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return MSheetScaffold<void>(
      title: context.l10n.editor.toolbar.rename,
      actions: [
        MAction(label: context.l10n.common.cancel),
        MAction(
          label: context.l10n.common.ok,
          isPrimary: true,
          enabled: _valid,
          onPressed: _submit,
        ),
      ],
      child: MField(
        controller: _name,
        label: context.l10n.common.name,
        suffixText: widget.suffix,
        autofocus: true,
        textInputAction: .done,
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
