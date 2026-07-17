import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/impl/s3_sync.dart';

class S3FormSheet extends StatefulWidget {
  const S3FormSheet({super.key});

  @override
  State<S3FormSheet> createState() => _S3FormSheetState();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // 必须用 builder 自己的 context 取 viewInsets：外层 context 的 MediaQuery
      // 变化不会重建 builder，padding 会停在打开时的 0、表单被键盘遮住。
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const S3FormSheet(),
      ),
    );
  }
}

class _S3FormSheetState extends State<S3FormSheet> {
  late final TextEditingController _endpointCtl;
  late final TextEditingController _regionCtl;
  late final TextEditingController _accessKeyCtl;
  late final TextEditingController _secretKeyCtl;
  late final TextEditingController _bucketCtl;
  bool _useSSL = true;
  bool _obscureSecret = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final opts = MoodiaryKVs.s3Option.get() ?? const <String>[];
    String at(int i) => opts.length > i ? opts[i] : '';
    _endpointCtl = TextEditingController(text: at(0));
    _regionCtl = TextEditingController(text: at(1));
    _accessKeyCtl = TextEditingController(text: at(2));
    _secretKeyCtl = TextEditingController(text: at(3));
    _bucketCtl = TextEditingController(text: at(4));
    _useSSL = at(5) != '0';
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await S3SyncBackend.configure(
      endpoint: _endpointCtl.text,
      region: _regionCtl.text,
      accessKey: _accessKeyCtl.text,
      secretKey: _secretKeyCtl.text,
      bucket: _bucketCtl.text,
      useSSL: _useSSL,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _clear() async {
    await S3SyncBackend.clear();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'S3 / MinIO 配置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _endpointCtl,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'play.min.io / s3.amazonaws.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _regionCtl,
                decoration: const InputDecoration(
                  labelText: 'Region (可选)',
                  hintText: 'us-east-1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bucketCtl,
                decoration: const InputDecoration(
                  labelText: 'Bucket',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accessKeyCtl,
                decoration: const InputDecoration(
                  labelText: 'Access Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretKeyCtl,
                obscureText: _obscureSecret,
                decoration: InputDecoration(
                  labelText: 'Secret Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSecret
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSecret = !_obscureSecret),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用 HTTPS'),
                value: _useSSL,
                onChanged: (v) => setState(() => _useSSL = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: _clear, child: const Text('清除')),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
