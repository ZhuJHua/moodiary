part of 'tile_view.dart';

// 看图页 tile 调试叠层（长按 ⓘ 开）。颜色是状态编码 —— 绿 / 黄绿 / 橙 / 红 = sample 1 / 2 / 4 / 8，
// 黄 = 解码中，灰 = 排队，蓝 = 视口 —— 画在照片上，刻意不跟主题；闸门里整文件放行。

class _DebugSnapshot {
  final FastTilePlan? plan;
  final Set<String> inflight;
  final Set<String> queued;
  final double scale;
  final bool? randomAccess;
  final String format;
  final int batches;
  final int decoded;
  final int cacheBytes;

  const _DebugSnapshot({
    required this.plan,
    required this.inflight,
    required this.queued,
    required this.scale,
    required this.randomAccess,
    required this.format,
    required this.batches,
    required this.decoded,
    required this.cacheBytes,
  });
}

extension _TileDebugPainting on _TilePainter {
  /// 画在 child 坐标里，线宽与字号按 1/scale 反缩，屏幕上恒定。
  void _paintDebug(
    Canvas canvas,
    Rect rect,
    List<_Tile> shown,
    _DebugSnapshot d,
  ) {
    final k = 1 / d.scale;
    Color tint(int sample) => switch (sample) {
      1 => const Color(0xFF4CAF50),
      2 => const Color(0xFFCDDC39),
      4 => const Color(0xFFFF9800),
      _ => const Color(0xFFF44336),
    };
    for (final tile in shown) {
      final c = tint(tile.spec.sample);
      canvas.drawRect(tile.covered, Paint()..color = c.withValues(alpha: 0.12));
      canvas.drawRect(
        tile.covered,
        Paint()
          ..color = c
          ..style = .stroke
          ..strokeWidth = 2 * k,
      );
      _label(
        canvas,
        '#${tile.order} s${tile.spec.sample} r${tile.spec.row} c${tile.spec.col}',
        tile.covered.topLeft + Offset(6 * k, 6 * k),
        k,
        c,
      );
    }
    final plan = d.plan;
    if (plan != null) {
      for (final spec in [...plan.visible, ...plan.prefetch]) {
        if (tiles.containsKey(spec.key)) continue;
        final inflight = d.inflight.contains(spec.key);
        final queued = d.queued.contains(spec.key);
        if (!inflight && !queued) continue;
        final c = inflight ? const Color(0xFFFFEB3B) : const Color(0xFF9E9E9E);
        canvas.drawRect(
          spec.sourceRect.deflate(3 * k),
          Paint()
            ..color = c
            ..style = .stroke
            ..strokeWidth = (inflight ? 3 : 1.5) * k,
        );
        _label(
          canvas,
          '${inflight ? '解码中' : '排队'} s${spec.sample} r${spec.row} c${spec.col}',
          spec.sourceRect.topLeft + Offset(6 * k, 6 * k),
          k,
          c,
        );
      }
    }
    canvas.drawRect(
      rect.deflate(1 * k),
      Paint()
        ..color = const Color(0xFF2196F3)
        ..style = .stroke
        ..strokeWidth = 2 * k,
    );
    final line1 = StringBuffer()
      ..write('sample ${plan?.sample ?? '-'}  ')
      ..write(
        '可见 ${plan?.visible.length ?? 0}  预取 ${plan?.prefetch.length ?? 0}  ',
      )
      ..write(
        '缓存 ${tiles.length} 块 ${(d.cacheBytes / 1048576).toStringAsFixed(1)}MB',
      );
    final line2 = StringBuffer()
      ..write('在飞 ${d.inflight.length}  排队 ${d.queued.length}  ')
      ..write('批 ${d.batches}  已解 ${d.decoded}  ')
      ..write('scale ${d.scale.toStringAsFixed(3)}  ')
      ..write('${d.format}  ')
      ..write(switch (d.randomAccess) {
        null => 'RST ?',
        true => 'RST 随机访问',
        false => 'RST 无',
      });
    _label(
      canvas,
      line1.toString(),
      rect.topLeft + Offset(8 * k, 48 * k),
      k,
      const Color(0xFFFFFFFF),
      background: const Color(0xAA000000),
    );
    _label(
      canvas,
      line2.toString(),
      rect.topLeft + Offset(8 * k, 68 * k),
      k,
      const Color(0xFFFFFFFF),
      background: const Color(0xAA000000),
    );
  }

  /// 标签按文字缓存排版结果；画的时候把画布缩到屏幕空间，字号不随 scale 变。
  static final _labels = <String, TextPainter>{};

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double k,
    Color color, {
    Color background = const Color(0x99000000),
  }) {
    final key = '${color.toARGB32()}|$text';
    final painter = _labels.putIfAbsent(key, () {
      if (_labels.length > 512) {
        for (final p in _labels.values) {
          p.dispose();
        }
        _labels.clear();
      }
      return TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(color: color, fontSize: 11, height: 1.2),
        ),
        textDirection: .ltr,
      )..layout();
    });
    canvas.save();
    canvas.scale(k);
    final o = at / k;
    canvas.drawRect(
      Rect.fromLTWH(o.dx - 3, o.dy - 2, painter.width + 6, painter.height + 4),
      Paint()..color = background,
    );
    painter.paint(canvas, o);
    canvas.restore();
  }
}
