import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_router/moodiary_router.dart';

class UserPage extends ConsumerWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uuid = MoodiaryKVs.uuid.get();
    return Scaffold(
      appBar: AppBar(title: const Text('用户')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Icon(Icons.person, size: 40),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '本地用户',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              uuid ?? '(未生成 uuid)',
              style: theme.textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('复制 uuid'),
            subtitle: Text(uuid ?? '当前没有 uuid'),
            enabled: uuid != null,
            onTap: uuid == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: uuid));
                    toast.success(message: 'uuid 已复制到剪贴板');
                  },
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('登录 / 注册'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const LoginRoute().push(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('备份与同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const BackupSyncRoute().push(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              '重置本地数据',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('清空所有日记 / 分类 / 同步配置 / 密码，不可恢复'),
            onTap: () => _onReset(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _onReset(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认重置本地数据？'),
        content: const Text(
          '将清空全部日记、分类、回收站、WebDAV 配置、密码与同步开关。\n'
          '建议先到「备份与同步」导出 JSON 备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    await IsarDatabase.get().clear();
    await Future.wait([
      MoodiaryKVs.webDavOption.remove(),
      MoodiaryKVs.password.remove(),
      MoodiaryKVs.lock.set(false),
      MoodiaryKVs.lockNow.set(false),
      MoodiaryKVs.autoSync.set(false),
    ]);
    if (!context.mounted) return;
    toast.success(message: '本地数据已重置');
    if (!context.mounted) return;
    const DiaryHomeRoute().go(context);
  }
}
