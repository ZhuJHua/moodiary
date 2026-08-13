import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

class _StartSlide {
  final IconData icon;

  /// 文案是取串函数而不是字面量：这份列表是顶层常量，拿不到 `BuildContext`。
  final String Function(Translations l10n) title;
  final String Function(Translations l10n) body;

  const _StartSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const _slides = <_StartSlide>[
  _StartSlide(
    icon: LucideIcons.bookOpen,
    title: _welcomeTitle,
    body: _welcomeBody,
  ),
  _StartSlide(icon: LucideIcons.smile, title: _moodTitle, body: _moodBody),
  _StartSlide(
    icon: LucideIcons.cloudCheck,
    title: _ownershipTitle,
    body: _ownershipBody,
  ),
];

String _welcomeTitle(Translations l10n) => l10n.onboarding.welcomeTitle;
String _welcomeBody(Translations l10n) => l10n.onboarding.welcomeBody;
String _moodTitle(Translations l10n) => l10n.onboarding.moodTitle;
String _moodBody(Translations l10n) => l10n.onboarding.moodBody;
String _ownershipTitle(Translations l10n) => l10n.onboarding.ownershipTitle;
String _ownershipBody(Translations l10n) => l10n.onboarding.ownershipBody;

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

  /// 当前页相对 [index] 的位移（-1~1 区间做淡入淡出）。首帧未布局时退回整数页。
  double _offsetFor(int index) {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return (_page - index).toDouble();
    }
    return (_pageController.page ?? _page.toDouble()) - index;
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
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: .centerRight,
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: isLast,
                    child: Padding(
                      padding: const .only(right: 8),
                      child: TextButton(
                        onPressed: _enter,
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                        child: Text(context.l10n.onboarding.skip),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      final t = _offsetFor(index).abs().clamp(0.0, 1.0);
                      return Opacity(
                        opacity: 1 - t,
                        child: Transform.translate(
                          offset: Offset(0, t * 24),
                          child: child,
                        ),
                      );
                    },
                    child: _SlideView(slide: _slides[index]),
                  );
                },
              ),
            ),
            _Dots(count: _slides.length, page: _page),
            Padding(
              padding: const .fromLTRB(24, 28, 24, 12),
              child: SizedBox(
                height: 54,
                width: .infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    textStyle:
                        theme.typography.titleMedium.emphasized.onPrimary,
                  ),
                  child: Text(
                    isLast
                        ? context.l10n.onboarding.start
                        : context.l10n.onboarding.next,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const .only(bottom: 12),
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  TextButton(
                    onPressed: () => const AgreementRoute().push(context),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: Text(context.l10n.onboarding.userAgreement),
                  ),
                  Text('·', style: theme.typography.labelLarge.outline),
                  TextButton(
                    onPressed: () => const PrivacyRoute().push(context),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: Text(context.l10n.onboarding.privacyPolicy),
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

class _SlideView extends StatelessWidget {
  final _StartSlide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    return Padding(
      padding: const .symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: .topLeft,
                end: .bottomRight,
                colors: [
                  scheme.primaryContainer,
                  .alphaBlend(
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.primaryContainer,
                  ),
                ],
              ),
              borderRadius: .circular(36),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 60, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title(context.l10n),
            textAlign: .center,
            style: theme.typography.headlineMedium.emphasized.onSurface
                .copyWith(height: 1.15),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body(context.l10n),
            textAlign: .center,
            style: theme.typography.bodyLarge.onSurfaceVariant.copyWith(
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int page;
  const _Dots({required this.count, required this.page});

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colors.primary;
    return Row(
      mainAxisAlignment: .center,
      children: .generate(count, (i) {
        final selected = i == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const .symmetric(horizontal: 4),
          width: selected ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.22),
            borderRadius: .circular(4),
          ),
        );
      }),
    );
  }
}
