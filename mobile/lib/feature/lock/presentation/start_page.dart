import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_router/moodiary_router.dart';

class _StartSlide {
  final IconData icon;
  final String title;
  final String body;
  const _StartSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const _slides = <_StartSlide>[
  _StartSlide(
    icon: Icons.book_outlined,
    title: '欢迎使用 Moodiary',
    body: '一款离线优先的心情日记，所有数据默认保存在本机。',
  ),
  _StartSlide(
    icon: Icons.palette_outlined,
    title: '记录每一种情绪',
    body: '心情滑块 + 分类 + 标签 + 字数与写作计时，按你需要的维度组织内容。',
  ),
  _StartSlide(
    icon: Icons.cloud_sync_outlined,
    title: '数据归你掌控',
    body: '随时导出 JSON 备份；按需启用 WebDAV / LocalSend 同步，端到端加密可选。',
  ),
];

class StartPage extends ConsumerStatefulWidget {
  const StartPage({super.key});

  @override
  ConsumerState<StartPage> createState() => _StartPageState();
}

class _StartPageState extends ConsumerState<StartPage> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    await MoodiaryKVs.firstStart.set(false);
    if (!mounted) return;
    const DiaryHomeRoute().go(context);
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _enter();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: isLast ? null : _enter,
                child: const Text('跳过'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final s = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(s.icon, size: 56),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.title,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final selected = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: selected ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: FilledButton.icon(
                onPressed: _next,
                icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                label: Text(isLast ? '开始记录' : '下一步'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => const AgreementRoute().push(context),
                    child: const Text('用户协议'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => const PrivacyRoute().push(context),
                    child: const Text('隐私政策'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
