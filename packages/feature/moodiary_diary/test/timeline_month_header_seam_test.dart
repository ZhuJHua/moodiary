import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _TwoMonths extends Fake implements DiaryRepository {
  final rows = [
    // 11/1 与 10/31 相邻：时间轴是一根实线一直画到 11 月最后一条的底边
    for (final (month, lastDay) in [(11, 6), (10, 31)])
      for (var i = 0; i < 6; i++)
        Diary.empty(type: .markdown).copyWith(
          id: '$month-$i',
          title: 'Entry $month-$i',
          mood: .bad,
          time: DateTime(2026, month, lastDay - i, 8),
          lastModified: DateTime(2026, month, lastDay - i, 8),
        ),
  ];

  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();

  @override
  Future<List<DiarySummary>> getDiarySummariesByCategory({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    int? offset,
    int? limit,
    DiarySort sort = .timeDesc,
  }) async => offset! > 0 ? [] : rows.map(diarySummaryFromDiary).toList();

  @override
  Future<Map<DateTime, int>> diaryCountByMonth({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    DiarySort sort = .timeDesc,
  }) async => {DateTime(2026, 11): 6, DateTime(2026, 10): 6};
}

void main() {
  for (final dpr in [3.0, 4.0]) {
    testWidgets('adjacent pinned month headers leave no seam at ${dpr}x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(390 * dpr, 800 * dpr);
      addTearDown(tester.view.reset);
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        muiTestApp(
          RepaintBoundary(key: boundary, child: const DiaryTimelineView()),
          overrides: [diaryRepositoryProvider.overrideWithValue(_TwoMonths())],
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text(TimeFormat.monthTitle(DateTime(2026, 10)));
      final header = find
          .ancestor(
            of: label,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.header ?? false),
            ),
          )
          .first;
      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;
      final viewportTop = tester.getTopLeft(scrollable).dy;
      final headerTop = tester.getTopLeft(header).dy - viewportTop;
      final surface = Theme.of(tester.element(label)).colorScheme.surface;

      // 10 月头顶边落在物理像素中间时，正在把 11 月头往上顶
      for (var fraction = 0.05; fraction < 1; fraction += 0.1) {
        position.jumpTo(headerTop - (6 + fraction / dpr));
        await tester.pump();
        final seamRow = (tester.getTopLeft(header).dy * dpr).floor();
        // 交界上下各看几行：既查抗锯齿接缝，也查上一个月的时间轴画进这个头里
        final image = (await tester.runAsync(
          () =>
              (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: dpr),
        ))!;
        final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        // 时间轴中心在 x = 14 + 30 + 8 + 10 = 62
        for (var row = seamRow - 2; row <= seamRow + 4; row++) {
          for (var x = (60 * dpr).round(); x <= (64 * dpr).round(); x++) {
            final i = (row * image.width + x) * 4;
            expect(
              ui.Color.fromARGB(
                255,
                bytes.getUint8(i),
                bytes.getUint8(i + 1),
                bytes.getUint8(i + 2),
              ),
              surface,
              reason: 'fraction $fraction, row $row, x $x',
            );
          }
        }
        image.dispose();
      }
      await tester.pumpAndSettle();
    });
  }
}
