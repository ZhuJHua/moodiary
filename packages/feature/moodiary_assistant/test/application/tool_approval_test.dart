import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/tool_approval.dart';

void main() {
  test('确认与跳过各自完成对应的调用', () async {
    final gate = ToolApprovalGate();
    final a = gate.request('a');
    final b = gate.request('b');
    gate.resolve('b', false);
    gate.resolve('a', true);
    expect(await a, isTrue);
    expect(await b, isFalse);
    expect(gate.hasPending, isFalse);
  });

  test('停止或退出时一律按跳过收掉', () async {
    final gate = ToolApprovalGate();
    final pending = gate.request('x');
    gate.declineAll();
    expect(await pending, isFalse);
    gate.resolve('x', true);
  });

  test('超时后按跳过完成，Rust 那边不会一直等', () async {
    final gate = ToolApprovalGate(timeout: const Duration(milliseconds: 20));
    expect(await gate.request('t'), isFalse);
  });
}
