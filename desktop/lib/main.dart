import 'package:flutter/material.dart';

void main() {
  runApp(const MoodiaryDesktopApp());
}

/// Moodiary 桌面端骨架。当前仅占位、可运行；shell / 双栏 / 各页面待重建，
/// 业务逻辑后续从 workspace 共享包（foundation/infra/product）接入。
class MoodiaryDesktopApp extends StatelessWidget {
  const MoodiaryDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moodiary Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7E57C2),
        useMaterial3: true,
      ),
      home: const _DesktopHomeScaffold(),
    );
  }
}

class _DesktopHomeScaffold extends StatelessWidget {
  const _DesktopHomeScaffold();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.desktop_windows_outlined,
              size: 64,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Moodiary Desktop', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '骨架占位 — 桌面端实现待补',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
