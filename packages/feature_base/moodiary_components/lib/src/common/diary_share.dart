import 'package:flutter/widgets.dart';

typedef DiaryShareEntry = Future<void> Function(
  BuildContext context,
  String diaryId,
);

abstract final class DiaryShare {
  static DiaryShareEntry? _handler;

  static void register(DiaryShareEntry handler) => _handler = handler;

  static bool get isRegistered => _handler != null;

  static Future<void> open(BuildContext context, String diaryId) async {
    assert(_handler != null, 'DiaryShare.register() 没被调用：组合根漏挂了分享入口');
    await _handler?.call(context, diaryId);
  }
}
