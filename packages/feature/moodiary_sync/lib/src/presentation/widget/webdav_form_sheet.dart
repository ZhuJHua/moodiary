import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';

class WebDavFormSheet extends ConsumerStatefulWidget {
  const WebDavFormSheet({
    super.key,
    required this.initial,
    required this.configured,
  });

  final List<String> initial;
  final bool configured;

  @override
  ConsumerState<WebDavFormSheet> createState() => _WebDavFormSheetState();

  static Future<bool?> show(BuildContext context, WidgetRef ref) async {
    final backend = ref.read(syncBackendProvider(.webdav));
    final (initial, configured) = await (
      backend.savedOptions(),
      backend.isReady(),
    ).wait;
    if (!context.mounted) return null;
    return MSheet.show<bool>(
      context,
      builder: (_) => WebDavFormSheet(initial: initial, configured: configured),
    );
  }
}

class _WebDavFormSheetState extends ConsumerState<WebDavFormSheet> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _userCtl;
  late final TextEditingController _passCtl;

  late final bool _configured = widget.configured;
  late final String? _savedHost;

  String? _urlError;
  String? _userError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final opts = widget.initial;
    String at(int i) => opts.length > i ? opts[i] : '';
    _urlCtl = TextEditingController(text: at(0));
    _userCtl = TextEditingController(text: at(1));
    _passCtl = TextEditingController(text: at(2));
    final host = Uri.tryParse(at(0))?.host ?? '';
    _savedHost = host.isEmpty ? null : host;
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final url = _urlCtl.text.trim();
    final uri = Uri.tryParse(url);
    final urlError = url.isEmpty
        ? l10n.sync.fieldRequired(field: l10n.sync.webdavOptionServer)
        : (uri == null ||
              !(uri.isScheme('http') || uri.isScheme('https')) ||
              uri.host.isEmpty)
        ? l10n.sync.fieldInvalidUrl
        : null;
    final userError = _userCtl.text.trim().isEmpty
        ? l10n.sync.fieldRequired(field: l10n.sync.webdavOptionUsername)
        : null;
    setState(() {
      _urlError = urlError;
      _userError = userError;
    });
    return urlError == null && userError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      if (!await ref.read(activeSyncProviderTypeProvider.notifier).saveOptions(
        .webdav,
        [_urlCtl.text.trim(), _userCtl.text.trim(), _passCtl.text],
      )) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.sync.configClearConfirmTitle,
      message: l10n.sync.configClearConfirmMessage,
      confirmLabel: l10n.sync.configClear,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      if (!await ref
          .read(activeSyncProviderTypeProvider.notifier)
          .clearOptions(.webdav)) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    toast.success(message: l10n.sync.configCleared);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || ref.watch(syncOperationBusyProvider);
    final l10n = context.l10n;
    return MSheetScaffold<bool>(
      title: l10n.sync.backupSyncWebdav,
      subtitle: _configured
          ? (_savedHost ?? l10n.sync.backupSyncWebdavOption)
          : l10n.sync.backupSyncWebdavNoOption,
      icon: LucideIcons.cloud,
      actions: [
        MAction(label: l10n.common.cancel, value: false, enabled: !busy),
        MAction(
          label: l10n.common.save,
          isPrimary: true,
          busy: _saving,
          enabled: !busy,
          onPressed: _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        spacing: 14,
        children: [
          MField(
            controller: _urlCtl,
            label: l10n.sync.webdavOptionServer,
            errorText: _urlError,
            enabled: !busy,
            keyboardType: .url,
            textInputAction: .next,
          ),
          MField(
            controller: _userCtl,
            label: l10n.sync.webdavOptionUsername,
            errorText: _userError,
            enabled: !busy,
            textInputAction: .next,
          ),
          MField(
            controller: _passCtl,
            label: l10n.sync.webdavOptionPassword,
            enabled: !busy,
            obscureText: true,
            onSubmitted: (_) => _save(),
          ),
          if (_configured)
            MDangerRow(
              label: l10n.sync.configClear,
              onPressed: busy ? null : _clear,
            ),
        ],
      ),
    );
  }
}
