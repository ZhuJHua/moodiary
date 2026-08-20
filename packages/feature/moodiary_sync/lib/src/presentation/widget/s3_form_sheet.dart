import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/impl/s3_sync.dart';

/// S3 / MinIO 后端配置。字段按连接 / 凭证 / 选项分三节，装不下一屏时只有中间
/// 内容滚动，动作条始终贴在卡片底边。
class S3FormSheet extends StatefulWidget {
  const S3FormSheet({super.key});

  @override
  State<S3FormSheet> createState() => _S3FormSheetState();

  static Future<bool?> show(BuildContext context) {
    return MSheet.show<bool>(context, builder: (_) => const S3FormSheet());
  }
}

class _S3FormSheetState extends State<S3FormSheet> {
  late final TextEditingController _endpointCtl;
  late final TextEditingController _regionCtl;
  late final TextEditingController _accessKeyCtl;
  late final TextEditingController _secretKeyCtl;
  late final TextEditingController _bucketCtl;

  late final bool _configured = S3SyncBackend.isConfigured();
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
    final opts = S3SyncBackend.options.value;
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

  /// Endpoint 存的是裸主机名，协议由下面的 HTTPS 开关决定。粘进来一整条 URL 时
  /// 就地拆开：主机留在框里、协议翻到开关上，改动是看得见的。
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

  /// 校验口径与 [S3SyncBackend.isConfigured] 一致：region 可空，其余四项必填。
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
      await S3SyncBackend.configure(
        endpoint: _endpointCtl.text,
        region: _regionCtl.text,
        accessKey: _accessKeyCtl.text,
        secretKey: _secretKeyCtl.text,
        bucket: _bucketCtl.text,
        useSSL: _useSSL,
      );
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
      await S3SyncBackend.clear();
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
    final l10n = context.l10n;
    return MSheetScaffold<bool>(
      title: l10n.sync.backupSyncS3,
      subtitle: _configured ? _savedBucket : l10n.sync.backupSyncWebdavNoOption,
      icon: LucideIcons.database,
      actions: [
        MAction(label: l10n.common.cancel, value: false, enabled: !_saving),
        MAction(
          label: l10n.common.save,
          isPrimary: true,
          busy: _saving,
          enabled: !_saving,
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
            enabled: !_saving,
            keyboardType: .url,
            textInputAction: .next,
            onChanged: _normalizeEndpoint,
          ),
          MField(
            controller: _bucketCtl,
            label: l10n.sync.s3OptionBucket,
            errorText: _bucketError,
            enabled: !_saving,
            textInputAction: .next,
          ),
          MField(
            controller: _regionCtl,
            label: l10n.sync.s3OptionRegion,
            hintText: l10n.sync.fieldOptional,
            enabled: !_saving,
            textInputAction: .next,
          ),
          MFormSection(l10n.sync.sectionCredentials),
          MField(
            controller: _accessKeyCtl,
            label: l10n.sync.s3OptionAccessKey,
            errorText: _accessKeyError,
            enabled: !_saving,
            textInputAction: .next,
          ),
          MField(
            controller: _secretKeyCtl,
            label: l10n.sync.s3OptionSecretKey,
            errorText: _secretKeyError,
            enabled: !_saving,
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
              onPressed: _saving ? null : _clear,
            ),
        ],
      ),
    );
  }
}
