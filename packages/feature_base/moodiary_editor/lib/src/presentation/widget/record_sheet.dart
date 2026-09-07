import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:record/record.dart';

typedef RecordSaveResult = ({String fileName, String? name, Duration duration});

class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key});

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  final _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _ampSub;

  final _nameController = TextEditingController();

  String? _fileName;

  bool _started = false;
  bool _recording = false;

  bool _finishing = false;

  Duration _elapsed = .zero;

  final Stopwatch _watch = Stopwatch();

  final List<double> _amplitudes = [];

  double _amplitudeBaseline = 0;

  double _maxWidth = 0;

  static const _sampleInterval = Duration(milliseconds: 40);

  @override
  void dispose() {
    _nameController.dispose();
    _ampSub?.cancel();
    // record 原生层 stop() 后仍持有输出路径，此时调用 cancel() 会删除已录制文件
    final name = _fileName;
    if (name != null) {
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
        androidConfig: AndroidRecordConfig(useLegacy: true),
      ),
      path: path,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(_sampleInterval)
        .listen(_onAmplitude);
    _watch
      ..reset()
      ..start();
    if (!mounted) return;
    setState(() {
      _fileName = name;
      _started = true;
      _recording = true;
      _elapsed = .zero;
      _amplitudes.clear();
      _amplitudeBaseline = 0;
    });
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted) return;
    // record 的振幅定时器在 pause 后仍会触发（isRecording 对 paused 也返回 true）
    if (!_recording) return;
    final value = amp.current;
    setState(() {
      _elapsed += _sampleInterval;
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

  void _pushSample(double value) {
    if (_amplitudes.length > _maxWidth ~/ _WaveformPainter.stride) {
      _amplitudes.removeAt(0);
    }
    _amplitudes.add(value);
  }

  Future<void> _pauseOrResume() async {
    if (_finishing) return;
    if (_recording) {
      await _recorder.pause();
      _watch.stop();
      if (!mounted) return;
      setState(() => _recording = false);
    } else {
      await _recorder.resume();
      _watch.start();
      if (!mounted) return;
      setState(() => _recording = true);
    }
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
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
    if (_finishing) return;
    _finishing = true;
    await _ampSub?.cancel();
    _ampSub = null;
    _watch.stop();
    final path = await _recorder.stop();
    if (path == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    final duration = await probeAudioDuration(path) ?? _watch.elapsed;
    final fileName = _fileName;
    _fileName = null;
    final name = _nameController.text.trim();
    if (!mounted || fileName == null) return;
    Navigator.of(context).pop<RecordSaveResult>((
      fileName: fileName,
      name: name.isEmpty ? null : name,
      duration: duration,
    ));
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
      padding: const .fromLTRB(16, 12, 16, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxWidth = constraints.maxWidth;
          return _buildBody(context, l10n);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Translations l10n) {
    return Column(
      mainAxisSize: .min,
      children: [
        if (_started) ...[
          MField(
            controller: _nameController,
            label: l10n.common.name,
            textInputAction: .done,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 120,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _started
                ? Align(
                    key: const ValueKey('wave'),
                    alignment: .centerLeft,
                    child: _Waveform(amplitudes: _amplitudes),
                  )
                : Center(
                    key: const ValueKey('start'),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: .circle,
                        border: .all(
                          color: context.theme.colors.outline,
                          width: 4,
                        ),
                      ),
                      child: IconButton(
                        padding: .zero,
                        icon: Icon(
                          LucideIcons.circleDot,
                          size: 48,
                          color: context.theme.colors.error,
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
            style: context.theme.typography.titleMedium.onSurface.copyWith(
              fontFeatures: const [.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              TextButton(onPressed: _cancel, child: Text(l10n.common.cancel)),
              FilledButton(
                onPressed: _pauseOrResume,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _recording ? LucideIcons.pause : LucideIcons.play,
                    key: ValueKey(_recording),
                  ),
                ),
              ),
              TextButton(
                onPressed: _stopAndSave,
                child: Text(l10n.common.save),
              ),
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
      painter: _WaveformPainter(
        .of(amplitudes),
        color: context.theme.colors.primary,
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
      ..strokeCap = .round
      ..strokeWidth = barWidth
      ..style = .fill;
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
