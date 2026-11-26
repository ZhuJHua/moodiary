import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_share.g.dart';

typedef DiaryShareHandler = Future<void> Function(
  BuildContext context,
  String diaryId,
);

@Riverpod(keepAlive: true)
DiaryShareHandler diaryShareHandler(Ref ref) =>
    throw UnimplementedError('diaryShareHandlerProvider must be overridden');
