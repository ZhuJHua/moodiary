part of '../moodiary_editor.dart';

extension on _MediaNodeState {
  Widget _mediaButton(
    String label,
    Widget icon,
    VoidCallback? onTap, {
    double size = 44,
    bool filled = false,
  }) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: SizedBox(
        width: size,
        height: size,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? context.theme.colors.onSurface
                  : Colors.transparent,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    ),
  );

  Widget _audioControls(String? path) {
    final audio = _audio,
        progress = audio?.progress.value ?? components.AudioProgress.zero,
        scale = widget.host._configuration.fontScale,
        family = widget.host._configuration.fontResolver?.call()?.family,
        line = widget.host._configuration.typography.lineHeight;
    final colors = context.theme.colors;
    final time =
        '${_formatDuration(progress.position)} / ${_formatDuration(progress.duration)}';
    final timeStyle = _textStyle(
      family: family,
      size: 12 * scale,
      height: line,
      color: colors.onSurfaceVariant,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      width: widget.view.width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _mediaButton(
            progress.playing
                ? context.l10n.editor.content.pause
                : context.l10n.editor.content.play,
            CustomPaint(
              size: const Size(18, 18),
              painter: _MediaGlyph(colors.surface, progress.playing),
            ),
            path == null || audio == null
                ? null
                : () => unawaited(audio.toggle(path)),
            size: 40,
            filled: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 14 * scale * 1.3,
                  child: Text(
                    widget.view.node.attrs['name'] as String? ??
                        context.l10n.editor.toolbar.audio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _textStyle(
                      family: family,
                      size: 14 * scale,
                      height: 1.3,
                      weight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: math.max(20, 12 * scale * line),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = TextPainter(
                        text: TextSpan(text: time, style: timeStyle),
                        textDirection: TextDirection.ltr,
                      )..layout();
                      final width = math.min(
                        painter.width,
                        math.max(0.0, constraints.maxWidth - 8),
                      );
                      painter.dispose();
                      return Row(
                        children: [
                          Expanded(
                            child: _SeekBar(
                              value: progress.duration.inMilliseconds <= 0
                                  ? 0
                                  : progress.position.inMilliseconds /
                                        progress.duration.inMilliseconds,
                              onChanged:
                                  progress.duration > Duration.zero &&
                                      audio != null
                                  ? (v) => unawaited(audio.seek(v))
                                  : null,
                              label: context.l10n.editor.content.audioProgress,
                              description: time,
                              color: colors.onSurface,
                              rail: colors.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: width,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(time, maxLines: 1, style: timeStyle),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoControls(MVideoPlaybackController? video) {
    final progress = video?.progress.value;
    final playing = video?.state.value.isPlayIntent == true;
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            for (final opacity in [.58, .4, .2, .07, .0])
              context.theme.colors.scrim.withValues(alpha: opacity),
          ],
          stops: const [0, .26, .52, .76, 1],
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: context.theme.onMedia, size: 20),
        child: Row(
          children: [
            _mediaButton(
              playing
                  ? context.l10n.editor.content.pause
                  : context.l10n.editor.content.play,
              CustomPaint(
                size: const Size(20, 20),
                painter: _MediaGlyph(
                  context.theme.onMedia,
                  playing,
                  filled: false,
                ),
              ),
              video == null
                  ? null
                  : () {
                      unawaited(video.togglePlay());
                      _keepControls();
                    },
              size: math.min(44, math.max(16, (widget.view.width - 16) / 2)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SeekBar(
                value: progress == null || progress.duration.inMilliseconds <= 0
                    ? 0
                    : progress.position.inMilliseconds /
                          progress.duration.inMilliseconds,
                onChanged:
                    video == null ||
                        progress == null ||
                        progress.duration <= Duration.zero
                    ? null
                    : (value) {
                        unawaited(
                          video.seekTo(
                            Duration(
                              milliseconds:
                                  (value * progress.duration.inMilliseconds)
                                      .round(),
                            ),
                          ),
                        );
                        _keepControls();
                      },
                label: context.l10n.editor.content.videoProgress,
                description:
                    '${_formatDuration(progress?.position ?? Duration.zero)} / ${_formatDuration(progress?.duration ?? Duration.zero)}',
                color: context.theme.onMedia,
                rail: context.theme.onMedia.withValues(alpha: .12),
                video: true,
              ),
            ),
            if (widget.view.width >= 240) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(progress?.position ?? Duration.zero),
                    style: _videoTimeStyle(
                      FontWeight.w600,
                      context.theme.onMedia,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '/',
                    style: _videoTimeStyle(
                      FontWeight.w400,
                      context.theme.onMedia.withValues(alpha: .3),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatDuration(progress?.duration ?? Duration.zero),
                    style: _videoTimeStyle(
                      FontWeight.w400,
                      context.theme.onMedia.withValues(alpha: .62),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 4),
            if (widget.view.width >= 240) ...[
              _mediaButton(
                context.l10n.editor.content.mute,
                Icon(
                  video?.settings.value.volume == 0
                      ? LucideIcons.volumeX
                      : LucideIcons.volume2,
                  size: 20,
                  color: context.theme.onMedia,
                ),
                video == null
                    ? null
                    : () => unawaited(
                        video.setVolume(
                          video.settings.value.volume == 0 ? 1 : 0,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
            ],
            _mediaButton(
              context.l10n.editor.content.fullscreen,
              Icon(
                LucideIcons.maximize,
                size: 20,
                color: context.theme.onMedia,
              ),
              _fullscreen,
              size: math.min(44, math.max(16, (widget.view.width - 16) / 2)),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _videoTimeStyle(FontWeight weight, Color color) =>
      _textStyle(
        size: 12 * widget.host._configuration.fontScale,
        weight: weight,
        color: color,
        height: widget.host._configuration.typography.lineHeight,
      ).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 2,
            color: context.theme.colors.scrim.withValues(alpha: .5),
          ),
        ],
      );
}

class _MediaGlyph extends CustomPainter {
  const _MediaGlyph(this.color, this.paused, {this.filled = true});
  final Color color;
  final bool paused, filled;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Rounded Lucide play/pause paths.
    final path = Path();
    if (paused) {
      for (final x in [5.0, 14.0]) {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 3, 5, 18),
            const Radius.circular(1),
          ),
        );
      }
    } else {
      path
        ..moveTo(5, 5)
        ..arcToPoint(
          const Offset(8.008, 3.272),
          radius: const Radius.circular(2),
        )
        ..lineTo(20.005, 10.270)
        ..arcToPoint(
          const Offset(20.008, 13.728),
          radius: const Radius.circular(2),
        )
        ..lineTo(8.008, 20.728)
        ..arcToPoint(const Offset(5, 19), radius: const Radius.circular(2))
        ..close();
    }
    if (filled) canvas.drawPath(path, paint);
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MediaGlyph old) =>
      old.color != color || old.paused != paused || old.filled != filled;
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.description,
    required this.color,
    required this.rail,
    this.video = false,
  });
  final double value;
  final ValueChanged<double>? onChanged;
  final String label, description;
  final Color color, rail;
  final bool video;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      void seek(Offset point) {
        final inset = widget.video
            ? 0.0
            : math.min(7.0, constraints.maxWidth / 2);
        final width = constraints.maxWidth - inset * 2;
        if (width > 0) {
          widget.onChanged?.call(((point.dx - inset) / width).clamp(0, 1));
        }
      }

      return Semantics(
        slider: true,
        label: widget.label,
        value: widget.description,
        onIncrease: widget.onChanged == null
            ? null
            : () => widget.onChanged!((widget.value + .05).clamp(0, 1)),
        onDecrease: widget.onChanged == null
            ? null
            : () => widget.onChanged!((widget.value - .05).clamp(0, 1)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onChanged == null
              ? null
              : (d) {
                  if (widget.video) setState(() => _pressed = true);
                  seek(d.localPosition);
                },
          onTap: widget.onChanged == null
              ? null
              : () => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onHorizontalDragStart: widget.onChanged == null
              ? null
              : (d) {
                  setState(() => _pressed = true);
                  seek(d.localPosition);
                },
          onHorizontalDragUpdate: widget.onChanged == null
              ? null
              : (d) => seek(d.localPosition),
          onHorizontalDragEnd: (_) => setState(() => _pressed = false),
          onHorizontalDragCancel: () => setState(() => _pressed = false),
          child: CustomPaint(
            size: Size(double.infinity, widget.video ? 28 : 20),
            painter: _SeekPainter(
              widget.value.clamp(0, 1),
              widget.color,
              widget.rail,
              widget.video,
              _pressed,
              context.theme.colors.scrim,
            ),
          ),
        ),
      );
    },
  );
}

class _SeekPainter extends CustomPainter {
  const _SeekPainter(
    this.value,
    this.color,
    this.rail,
    this.video,
    this.pressed,
    this.shadow,
  );
  final double value;
  final Color color, rail, shadow;
  final bool video, pressed;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final y = size.height / 2 - (video && pressed ? 2 : 0);
    final height = video ? (pressed ? 6.0 : 3.0) : 4.0;
    final inset = video ? 0.0 : math.min(7.0, size.width / 2);
    final x = inset + (size.width - inset * 2) * value;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y - height / 2, size.width, height),
      const Radius.circular(99),
    );
    if (video) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = shadow.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawRRect(rect, Paint()..color = rail);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - height / 2, x, height),
        const Radius.circular(99),
      ),
      Paint()..color = color,
    );
    final radius = video ? (pressed ? 7.0 : 4.0) : 7.0;
    // Video thumbs always cast a shadow; audio thumbs only on iOS, more softly.
    if (video || defaultTargetPlatform == TargetPlatform.iOS) {
      canvas.drawCircle(
        Offset(x, y + 1),
        radius,
        Paint()
          ..color = shadow.withValues(alpha: video ? .5 : .2)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(3),
          ),
      );
    }
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.value != value ||
      old.color != color ||
      old.rail != rail ||
      old.video != video ||
      old.shadow != shadow ||
      old.pressed != pressed;
}
