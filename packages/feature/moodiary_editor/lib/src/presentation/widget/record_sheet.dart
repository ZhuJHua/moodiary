import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:record/record.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;

/// 录音底栏。保存返回文件名（落地在 `getRealPath('audio', ...)`），取消返回 null。
/// 直接录到正式目录、不走缓存中转，取消 / 失败时主动清理文件。
class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key});

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  late final _iconAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  StreamSubscription<Amplitude>? _ampSub;

  String? _fileName;

  bool _started = false;
  bool _recording = false;
  Duration _elapsed = Duration.zero;

  final List<double> _amplitudes = [];

  /// amplitude 报告的最低值（接近 -45dB），归一化时做下界。
  double _amplitudeBaseline = 0;

  /// 波形可用宽度（build 时由 LayoutBuilder 写入），样本上限按它换算。
  double _maxWidth = 0;

  static const _sampleInterval = Duration(milliseconds: 40);

  @override
  void dispose() {
    _ampSub?.cancel();
    _iconAnimation.dispose();
    // 已保存（_stopAndSave 置空 _fileName）时只释放资源；此时绝不能再 cancel()——
    // record 原生层 stop() 后仍持有输出路径，cancel() 会把刚录好的文件删掉。
    final name = _fileName;
    if (name != null) {
      // 用户中途滑掉 sheet → 异步清理录音 + 文件。
      _recorder.cancel().catchError((_) {});
      // ignore: discarded_futures
      AppFiles.deleteFile(AppFiles.getRealPath('audio', name));
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final granted = await _recorder.hasPermission();
    if (!granted) return;
    final name = 'audio-${uuidV7()}.m4a';
    final path = AppFiles.getRealPath('audio', name);
    await _recorder.start(
      const RecordConfig(
        // Android 走 legacy MediaRecorder：兼容老设备的 m4a 编码。
        androidConfig: AndroidRecordConfig(useLegacy: true),
      ),
      path: path,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(_sampleInterval)
        .listen(_onAmplitude);
    _iconAnimation.forward();
    if (!mounted) return;
    setState(() {
      _fileName = name;
      _started = true;
      _recording = true;
      _elapsed = Duration.zero;
      _amplitudes.clear();
      _amplitudeBaseline = 0;
    });
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted) return;
    // 插件的振幅定时器在 pause 后仍会触发（isRecording 对 paused 也返回 true）：
    // 暂停期间既不该计时也不该追加样本。
    if (!_recording) return;
    final value = amp.current;
    setState(() {
      _elapsed += _sampleInterval;
      // ±Infinity（静音 / 初始化瞬间）补零高条；current == max 的帧跳过。
      if (!value.isFinite) {
        _pushSample(0);
      } else if (value != amp.max) {
        _amplitudeBaseline = min(_amplitudeBaseline, value);
        final normalized = _amplitudeBaseline == 0
            ? 0.0
            : (value + _amplitudeBaseline.abs()) / _amplitudeBaseline.abs();
        _pushSample(normalized);
      }
    });
  }

  /// 上限 = 可用宽度能放下的条数：填满前从左往右生长，满了滚动。
  void _pushSample(double value) {
    if (_amplitudes.length > _maxWidth ~/ _WaveformPainter.stride) {
      _amplitudes.removeAt(0);
    }
    _amplitudes.add(value);
  }

  Future<void> _pauseOrResume() async {
    if (_recording) {
      await _recorder.pause();
      _iconAnimation.reverse();
      if (!mounted) return;
      setState(() => _recording = false);
    } else {
      await _recorder.resume();
      _iconAnimation.forward();
      if (!mounted) return;
      setState(() => _recording = true);
    }
  }

  Future<void> _cancel() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _recorder.cancel();
    final name = _fileName;
    _fileName = null;
    if (name != null) {
      await AppFiles.deleteFile(AppFiles.getRealPath('audio', name));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _stopAndSave() async {
    await _ampSub?.cancel();
    _ampSub = null;
    final path = await _recorder.stop();
    if (path == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    final name = _fileName;
    // 标记已收尾，避免 dispose 把它当作"中途滑掉"再删一次。
    _fileName = null;
    if (!mounted) return;
    Navigator.of(context).pop(name);
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxWidth = constraints.maxWidth;
          return _buildBody(context, l10n);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _started
                // 波形靠左生长（与旧版一致），Align 撑满宽度避免 switcher 随波形宽度抖动。
                ? Align(
                    key: const ValueKey('wave'),
                    alignment: Alignment.centerLeft,
                    child: _Waveform(amplitudes: _amplitudes),
                  )
                : Center(
                    key: const ValueKey('start'),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.theme.colorScheme.outline,
                          width: 4,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          LucideIcons.circleDot,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        onPressed: _start,
                      ),
                    ),
                  ),
          ),
        ),
        if (_started) ...[
          const SizedBox(height: 8),
          Text(
            _fmt(_elapsed),
            style: context.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
              FilledButton(
                onPressed: _pauseOrResume,
                child: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _iconAnimation,
                ),
              ),
              TextButton(onPressed: _stopAndSave, child: Text(l10n.save)),
            ],
          ),
        ],
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  final List<double> amplitudes;

  const _Waveform({required this.amplitudes});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // 快照副本：painter 若持有会被原地 mutate 的原列表，shouldRepaint 永远比不出差异。
      painter: _WaveformPainter(
        List.of(amplitudes),
        color: context.theme.colorScheme.primary,
      ),
      size: Size(amplitudes.length * _WaveformPainter.stride, 100),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  static const double barWidth = 2.0;
  static const double spaceWidth = 2.0;
  static const double stride = barWidth + spaceWidth;

  _WaveformPainter(this.amplitudes, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.fill;
    // 底部基线，条形向上生长。
    final baseY = size.height - barWidth;
    for (var i = 0; i < amplitudes.length; i++) {
      final x = i * stride + barWidth / 2;
      final y = baseY * (1 - amplitudes[i]);
      canvas.drawLine(Offset(x, baseY), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.color != color || !listEquals(old.amplitudes, amplitudes);
}
