import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';

class S3FormSheet extends ConsumerStatefulWidget {
  const S3FormSheet({
    super.key,
    required this.initial,
    required this.configured,
  });

  final List<String> initial;
  final bool configured;

  @override
  ConsumerState<S3FormSheet> createState() => _S3FormSheetState();

  static Future<bool?> show(BuildContext context, WidgetRef ref) async {
    final backend = ref.read(syncBackendProvider(.s3));
    final (initial, configured) = await (
      backend.savedOptions(),
      backend.isReady(),
    ).wait;
    if (!context.mounted) return null;
    return MSheet.show<bool>(
      context,
      builder: (_) => S3FormSheet(initial: initial, configured: configured),
    );
  }
}

class _S3FormSheetState extends ConsumerState<S3FormSheet> {
  late final TextEditingController _endpointCtl;
  late final TextEditingController _regionCtl;
  late final TextEditingController _accessKeyCtl;
  late final TextEditingController _secretKeyCtl;
  late final TextEditingController _bucketCtl;

  late final bool _configured = widget.configured;
  late final String _savedBucket;

  bool _useSSL = true;
  bool _saving = false;
  String? _endpointError;
  String? _bucketError;
  String? _accessKeyError;
  String? _secretKeyError;

  @override
  void initState() {
    super.initState();
    final opts = widget.initial;
    String at(int i) => opts.length > i ? opts[i] : '';
    _endpointCtl = TextEditingController(text: at(0));
    _regionCtl = TextEditingController(text: at(1));
    _accessKeyCtl = TextEditingController(text: at(2));
    _secretKeyCtl = TextEditingController(text: at(3));
    _bucketCtl = TextEditingController(text: at(4));
    _useSSL = at(5) != '0';
    _savedBucket = at(4);
  }

  @override
  void dispose() {
    _endpointCtl.dispose();
    _regionCtl.dispose();
    _accessKeyCtl.dispose();
    _secretKeyCtl.dispose();
    _bucketCtl.dispose();
    super.dispose();
  }

  void _normalizeEndpoint(String value) {
    if (!value.contains('://')) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return;
    final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    setState(() => _useSSL = uri.isScheme('https'));
    _endpointCtl.value = TextEditingValue(
      text: host,
      selection: .collapsed(offset: host.length),
    );
  }

  bool _validate() {
    final l10n = context.l10n;
    String? required(TextEditingController controller, String field) =>
        controller.text.trim().isEmpty
        ? l10n.sync.fieldRequired(field: field)
        : null;

    final endpointError = required(_endpointCtl, l10n.sync.s3OptionEndpoint);
    final bucketError = required(_bucketCtl, l10n.sync.s3OptionBucket);
    final accessKeyError = required(_accessKeyCtl, l10n.sync.s3OptionAccessKey);
    final secretKeyError = required(_secretKeyCtl, l10n.sync.s3OptionSecretKey);
    setState(() {
      _endpointError = endpointError;
      _bucketError = bucketError;
      _accessKeyError = accessKeyError;
      _secretKeyError = secretKeyError;
    });
    return endpointError == null &&
        bucketError == null &&
        accessKeyError == null &&
        secretKeyError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      if (!await ref.read(activeSyncProviderTypeProvider.notifier).saveOptions(
        .s3,
        [
          _endpointCtl.text.trim(),
          _regionCtl.text.trim(),
          _accessKeyCtl.text.trim(),
          _secretKeyCtl.text,
          _bucketCtl.text.trim(),
          _useSSL ? '1' : '0',
        ],
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
          .clearOptions(.s3)) {
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
      title: l10n.sync.backupSyncS3,
      subtitle: _configured ? _savedBucket : l10n.sync.backupSyncWebdavNoOption,
      icon: LucideIcons.database,
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
          MFormSection(l10n.sync.sectionConnection),
          MField(
            controller: _endpointCtl,
            label: l10n.sync.s3OptionEndpoint,
            errorText: _endpointError,
            enabled: !busy,
            keyboardType: .url,
            textInputAction: .next,
            onChanged: _normalizeEndpoint,
          ),
          MField(
            controller: _bucketCtl,
            label: l10n.sync.s3OptionBucket,
            errorText: _bucketError,
            enabled: !busy,
            textInputAction: .next,
          ),
          MField(
            controller: _regionCtl,
            label: l10n.sync.s3OptionRegion,
            hintText: l10n.sync.fieldOptional,
            enabled: !busy,
            textInputAction: .next,
          ),
          MFormSection(l10n.sync.sectionCredentials),
          MField(
            controller: _accessKeyCtl,
            label: l10n.sync.s3OptionAccessKey,
            errorText: _accessKeyError,
            enabled: !busy,
            textInputAction: .next,
          ),
          MField(
            controller: _secretKeyCtl,
            label: l10n.sync.s3OptionSecretKey,
            errorText: _secretKeyError,
            enabled: !busy,
            obscureText: true,
            onSubmitted: (_) => _save(),
          ),
          MFormSection(l10n.sync.sectionOptions),
          MSwitchField(
            label: l10n.sync.s3OptionUseSsl,
            value: _useSSL,
            onChanged: _saving ? null : (v) => setState(() => _useSSL = v),
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
