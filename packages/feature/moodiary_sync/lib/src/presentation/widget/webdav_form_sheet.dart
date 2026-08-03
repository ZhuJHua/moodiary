import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/impl/webdav_sync.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;

class WebDavFormSheet extends StatefulWidget {
  const WebDavFormSheet({super.key});

  @override
  State<WebDavFormSheet> createState() => _WebDavFormSheetState();

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
        child: const WebDavFormSheet(),
      ),
    );
  }
}

class _WebDavFormSheetState extends State<WebDavFormSheet> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _userCtl;
  late final TextEditingController _passCtl;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final opts = MoodiaryKVs.webDavOption.get() ?? const <String>[];
    _urlCtl = TextEditingController(text: opts.isNotEmpty ? opts[0] : '');
    _userCtl = TextEditingController(text: opts.length > 1 ? opts[1] : '');
    _passCtl = TextEditingController(text: opts.length > 2 ? opts[2] : '');
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await WebDavSyncBackend.configure(
      baseUrl: _urlCtl.text,
      username: _userCtl.text,
      password: _passCtl.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _clear() async {
    await WebDavSyncBackend.clear();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 键盘顶起后剩余高度可能装不下整个表单（小屏/横屏），可滚动兜底。
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WebDAV 配置',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://dav.example.com/moodiary',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtl,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _clear,
                  child: const Text('清除'),
                ),
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
    );
  }
}
