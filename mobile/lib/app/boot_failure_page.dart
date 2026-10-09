import 'package:flutter/services.dart';
import 'package:moodiary_data/moodiary_data.dart'
    show DatabaseKeyLost, DatabaseKeyMismatch, DatabaseKeyUnavailable;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:mui/mui.dart';

class BootFailurePage extends StatefulWidget {
  final Object error;

  final StackTrace stackTrace;

  const BootFailurePage({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  State<BootFailurePage> createState() => _BootFailurePageState();
}

class _BootFailurePageState extends State<BootFailurePage> {
  bool _copied = false;

  bool _resetArmed = false;

  bool _resetDone = false;

  Object? _resetError;

  String? get _logPath {
    try {
      return AppFiles.getErrorLogPath();
    } catch (_) {
      return null;
    }
  }

  String get _details => 'Error: ${widget.error}\n\n${widget.stackTrace}';

  String get _hint => switch (widget.error) {
    DatabaseKeyLost() =>
      '数据库已加密，但安全存储里没有它的密钥，通常是应用数据从备份或别的设备恢复而来。'
          '密钥无法找回；请清空数据后，从备份文件或云同步恢复。\n'
          'The database is encrypted but its key is missing from secure '
          'storage, usually because the app data was restored from a backup '
          'or another device. The key cannot be recovered; erase the data, '
          'then restore from a backup file or cloud sync.',
    DatabaseKeyMismatch() =>
      '数据库无法用当前密钥打开：密钥与文件不匹配，或文件已损坏。'
          '可先重启重试；仍失败的话请清空数据后，从备份文件或云同步恢复。\n'
          'The database cannot be opened with the stored key: the key does '
          'not match the file, or the file is damaged. Restart to retry; if it '
          'keeps failing, erase the data and restore from a backup file or '
          'cloud sync.',
    DatabaseKeyUnavailable() =>
      '系统安全存储暂时读不出数据库密钥（Keystore / 钥匙串）。'
          '请先重启设备重试；仍失败的话请清空数据后，从备份文件或云同步恢复。\n'
          'The database key cannot be read from the system secure storage '
          '(Keystore / Keychain) right now. Restart the device and try again; '
          'if it keeps failing, erase the data and restore from a backup file '
          'or cloud sync.',
    _ =>
      '应用在初始化时遇到错误。你的数据仍在设备上，可先重启应用重试。\n'
          'The app hit an error during startup. Your data is still on this '
          'device; restarting the app may help.',
  };

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _details));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _reset() async {
    if (!_resetArmed) {
      setState(() => _resetArmed = true);
      return;
    }
    try {
      await resetAllData();
      if (mounted) setState(() => _resetDone = true);
    } catch (e) {
      if (mounted) setState(() => _resetError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logPath = _logPath;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _resetDone
                ? const Center(
                    child: Text(
                      '数据已清空。\n请关闭并重新打开应用。\n\n'
                      'Data cleared.\nPlease close and reopen the app.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '启动失败 / Failed to start',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_hint),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0x33888888)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _details,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (logPath != null) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          '日志 / Log: $logPath',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _copy,
                        child: Text(
                          _copied ? '已复制 / Copied' : '复制错误信息 / Copy error',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _reset,
                        child: Text(
                          _resetError != null
                              ? '清空失败 / Reset failed: $_resetError'
                              : _resetArmed
                              ? '再点一次确认清空所有数据 / Tap again to confirm'
                              : '清空所有数据（不可恢复） / Erase all data',
                          style: const TextStyle(color: Color(0xFFB3261E)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
