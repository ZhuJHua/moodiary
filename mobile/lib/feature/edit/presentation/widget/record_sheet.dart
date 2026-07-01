import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:record/record.dart';

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

  static const _maxSamples = 80;

  @override
  void dispose() {
    _ampSub?.cancel();
    _iconAnimation.dispose();
    // 用户中途滑掉 sheet → 异步清理录音 + 文件。
    _recorder.cancel().catchError((_) {});
    _recorder.dispose();
    final name = _fileName;
    if (name != null) {
      // ignore: discarded_futures
      FileUtil.deleteFile(FileUtil.getRealPath('audio', name));
    }
    super.dispose();
  }

  Future<void> _start() async {
    final granted = await _recorder.hasPermission();
    if (!granted) return;
    final name = 'audio-${uuidV7()}.m4a';
    final path = FileUtil.getRealPath('audio', name);
    await _recorder.start(
      const RecordConfig(
        // Android 走 legacy MediaRecorder：兼容老设备的 m4a 编码。
        androidConfig: AndroidRecordConfig(useLegacy: true),
      ),
      path: path,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
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
    final value = amp.current;
    // record 库偶发返回 ±Infinity（静音 / 初始化瞬间）；忽略，避免归一化崩。
    if (!value.isFinite) return;
    _amplitudeBaseline = min(_amplitudeBaseline, value);
    final normalized = _amplitudeBaseline == 0
        ? 0.0
        : ((value + _amplitudeBaseline.abs()) / _amplitudeBaseline.abs()).clamp(
            0.0,
            1.0,
          );
    setState(() {
      _elapsed += const Duration(milliseconds: 80);
      _amplitudes.add(normalized);
      if (_amplitudes.length > _maxSamples) {
        _amplitudes.removeAt(0);
      }
    });
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
      await FileUtil.deleteFile(FileUtil.getRealPath('audio', name));
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 120,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _started
                  ? _Waveform(
                      key: const ValueKey('wave'),
                      amplitudes: _amplitudes,
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
                            Icons.circle,
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
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final List<double> amplitudes;

  const _Waveform({super.key, required this.amplitudes});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(
        amplitudes,
        color: context.theme.colorScheme.primary,
      ),
      size: const Size.fromHeight(120),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  static const double barWidth = 2.0;
  static const double spaceWidth = 2.0;

  _WaveformPainter(this.amplitudes, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.fill;
    const stride = barWidth + spaceWidth;
    final total = amplitudes.length * stride;
    // 从右往左绘制，模拟最新样本贴边、旧样本左移的视觉。
    final startX = size.width - total;
    final mid = size.height / 2;
    for (var i = 0; i < amplitudes.length; i++) {
      final x = startX + i * stride + barWidth / 2;
      final half = (size.height / 2 - barWidth) * amplitudes[i];
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.amplitudes != amplitudes || old.color != color;
}
