import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import '../audio_player.dart';

/// 音频全屏播放页 —— 普通主题页面（跟随深 / 浅色，配色全走 colorScheme），不是
/// 视频那种纯黑「暗室」：AppBar 关闭键、唱盘 + 名称居中、底部刮擦条 + 播放键。
/// 手势取子集：横拖刮擦、双击播放 / 暂停；关闭走 AppBar 或系统返回。进入即自动播放。
class MoodiaryAudioPlayerPage extends StatefulWidget {
  final String audioPath;

  /// 显示名（调用方已做默认名兜底）。
  final String title;

  /// 次要信息行（如所属日记日期），可空。
  final String? subtitle;

  /// 表内已知总时长：进场即显示，不必等播放器初始化回报。
  final Duration? knownDuration;

  const MoodiaryAudioPlayerPage({
    super.key,
    required this.audioPath,
    required this.title,
    this.subtitle,
    this.knownDuration,
  });

  /// 防双开：快速双击卡片会推两个路由。
  static bool _opening = false;

  static Future<void> show(
    BuildContext context, {
    required String audioPath,
    required String title,
    String? subtitle,
    Duration? knownDuration,
  }) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          transitionDuration: Durations.medium2,
          reverseTransitionDuration: Durations.medium1,
          pageBuilder: (_, _, _) => MoodiaryAudioPlayerPage(
            audioPath: audioPath,
            title: title,
            subtitle: subtitle,
            knownDuration: knownDuration,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  /// 按媒体文件名打开（媒体库入口）。
  static Future<void> showByName(
    BuildContext context, {
    required String name,
    required String title,
    String? subtitle,
    Duration? knownDuration,
  }) {
    return show(
      context,
      audioPath: AppFiles.getRealPath('audio', name),
      title: title,
      subtitle: subtitle,
      knownDuration: knownDuration,
    );
  }

  @override
  State<MoodiaryAudioPlayerPage> createState() =>
      _MoodiaryAudioPlayerPageState();
}

class _MoodiaryAudioPlayerPageState extends State<MoodiaryAudioPlayerPage>
    with SingleTickerProviderStateMixin {
  final AudioPlaybackController _controller = AudioPlaybackController();

  /// 刮擦草稿进度（0..1）；null = 没在刮。拖动中只改显示，松手才 seek。
  final _draftFraction = ValueNotifier<double?>(null);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    _controller.progress.addListener(_syncSpin);
    // 进入即自动播放。
    _controller.toggle(widget.audioPath);
  }

  @override
  void dispose() {
    _controller.progress.removeListener(_syncSpin);
    _spin.dispose();
    _draftFraction.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncSpin() {
    final playing = _controller.progress.value.playing;
    if (playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  Duration get _totalDuration {
    final reported = _controller.progress.value.duration;
    if (reported > Duration.zero) return reported;
    return widget.knownDuration ?? Duration.zero;
  }

  double get _currentFraction {
    final total = _totalDuration;
    if (total <= Duration.zero) return 0;
    final position = _controller.progress.value.position;
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  // —— 手势：横拖刮擦（全页）、双击播放/暂停 —— //

  void _onHorizontalDragStart(DragStartDetails d) {
    if (_totalDuration <= Duration.zero) return;
    _draftFraction.value = _currentFraction;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    final draft = _draftFraction.value;
    if (draft == null) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    _draftFraction.value = (draft + (d.primaryDelta ?? 0) / width).clamp(
      0.0,
      1.0,
    );
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final draft = _draftFraction.value;
    _draftFraction.value = null;
    if (draft != null) {
      _controller.seek(draft, fallbackTotal: widget.knownDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          tooltip: l10n.audioPlayerClose,
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      // 横拖刮擦挂整页（拖动识别不拖延点击）；双击只覆盖唱盘区——双击识别器会把
      // 手势竞技场按住 ~300ms 等第二击，罩住底部控制条会让播放键点按明显迟钝。
      body: GestureDetector(
        behavior: .opaque,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: .opaque,
                onDoubleTap: () => _controller.toggle(widget.audioPath),
                child: Center(
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      RotationTransition(turns: _spin, child: const _Disc()),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const .symmetric(horizontal: 32),
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: .ellipsis,
                          textAlign: .center,
                          style: context
                              .theme
                              .typography
                              .titleLarge
                              .emphasized
                              .onSurface,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle!,
                          style: context
                              .theme
                              .typography
                              .bodySmall
                              .onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(l10n, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, MuiColorScheme scheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller.progress, _draftFraction]),
        builder: (context, _) {
          final p = _controller.progress.value;
          final total = _totalDuration;
          final draft = _draftFraction.value;
          final fraction = draft ?? _currentFraction;
          final shownPosition = draft == null
              ? p.position
              : Duration(milliseconds: (draft * total.inMilliseconds).round());
          return Column(
            mainAxisSize: .min,
            children: [
              _ScrubBar(
                fraction: fraction,
                dragging: draft != null,
                semanticLabel: l10n.audioPlayerProgress,
                onSeek: (f) =>
                    _controller.seek(f, fallbackTotal: widget.knownDuration),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 播完回到起点显示播放键，点按即重播（toggle 内部处理 completed）。
                  IconButton.filled(
                    onPressed: () => _controller.toggle(widget.audioPath),
                    tooltip: p.playing
                        ? l10n.audioPlayerPause
                        : l10n.audioPlayerPlay,
                    iconSize: 24,
                    icon: Icon(
                      p.playing ? LucideIcons.pause : LucideIcons.play,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${TimeFormat.mediaDuration(shownPosition)} / '
                    '${TimeFormat.mediaDuration(total)}',
                    style:
                        (draft != null
                                ? context.theme.typography.labelMedium.primary
                                : context
                                      .theme
                                      .typography
                                      .labelMedium
                                      .onSurfaceVariant)
                            .copyWith(fontFeatures: const [.tabularFigures()]),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 中央唱盘：同心圆 + 音符图标，播放时由外层 RotationTransition 缓慢旋转。
class _Disc extends StatelessWidget {
  const _Disc();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: .circle,
        color: scheme.surfaceContainerHighest,
        border: .all(color: scheme.outlineVariant),
      ),
      child: Container(
        margin: const .all(14),
        decoration: BoxDecoration(
          shape: .circle,
          border: .all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Icon(
            LucideIcons.music,
            size: 44,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 底部刮擦条：视觉 3dp（按下 6dp），命中整行高；拖动 / 点按都按横向比例 seek。
class _ScrubBar extends StatelessWidget {
  final double fraction;
  final bool dragging;
  final String semanticLabel;
  final ValueChanged<double> onSeek;

  const _ScrubBar({
    required this.fraction,
    required this.dragging,
    required this.semanticLabel,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Semantics(
      label: semanticLabel,
      value: '${(fraction * 100).round()}%',
      child: GestureDetector(
        behavior: .opaque,
        onTapUp: (d) {
          final width = context.size?.width ?? 0;
          if (width > 0) onSeek((d.localPosition.dx / width).clamp(0.0, 1.0));
        },
        child: SizedBox(
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: Durations.short3,
              height: dragging ? 6 : 3,
              child: CustomPaint(
                size: const Size(double.infinity, 6),
                painter: _ScrubPainter(
                  fraction: fraction,
                  track: scheme.surfaceContainerHighest,
                  fill: scheme.primary,
                  thumbRadius: dragging ? 7 : 5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrubPainter extends CustomPainter {
  final double fraction;
  final Color track;
  final Color fill;
  final double thumbRadius;

  _ScrubPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.thumbRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    final w = math.max(size.width * fraction, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), radius),
      Paint()..color = fill,
    );
    canvas.drawCircle(
      Offset(size.width * fraction, size.height / 2),
      thumbRadius,
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.thumbRadius != thumbRadius;
}
