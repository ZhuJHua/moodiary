import 'dart:async';

import 'package:moodiary_assistant/src/data/assistant_defs.dart';

class ToolApprovalRequest {
  final String callId;
  final AssistantTool tool;
  final Map<String, dynamic> args;
  final AssistantToolTier tier;

  const ToolApprovalRequest({
    required this.callId,
    required this.tool,
    required this.args,
    required this.tier,
  });
}

// 每个等待中的确认都要能被停止、退出页面或超时收掉，否则 Rust 那条 run 永远挂着
class ToolApprovalGate {
  ToolApprovalGate({this.timeout = const Duration(minutes: 5)});

  final Duration timeout;

  final Map<String, Completer<bool>> _pending = {};

  bool get hasPending => _pending.isNotEmpty;

  Future<bool> request(String callId) {
    final completer = Completer<bool>();
    _pending[callId] = completer;
    Timer(timeout, () => resolve(callId, false));
    return completer.future;
  }

  void resolve(String callId, bool approved) {
    final completer = _pending.remove(callId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
  }

  void declineAll() {
    for (final id in _pending.keys.toList()) {
      resolve(id, false);
    }
  }
}
