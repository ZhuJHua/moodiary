import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';

@visibleForTesting
const Duration kLockClearDelay = Duration(milliseconds: 280);

class LockPage extends StatefulWidget {
  final String? lockType;

  const LockPage({super.key, this.lockType});

  factory LockPage.fromRoute(GoRouterState state) =>
      LockPage(lockType: state.params['lock_type'] as String?);

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  bool _unlocked = false;

  void _unlock() {
    setState(() => _unlocked = true);
    Future.delayed(kLockClearDelay, () {
      if (!mounted) return;
      if (widget.lockType == 'pause') {
        // 命令式 pop 不受 PopScope(canPop:false) 拦截
        Navigator.of(context).pop();
      } else {
        const DiaryHomeRoute().go(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.lockType != 'pause') {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        extendBodyBehindAppBar: true,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _unlocked
                      ? Icon(
                          LucideIcons.lockOpen,
                          key: const ValueKey('unlock'),
                          size: 28,
                          color: scheme.primary,
                        )
                      : Icon(
                          LucideIcons.lock,
                          key: const ValueKey('lock'),
                          size: 28,
                          color: scheme.onSurface,
                        ),
                ),
                const SizedBox(height: 24),
                PasscodeGate(
                  title: context.l10n.lock.prompt,
                  onVerified: _unlock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
