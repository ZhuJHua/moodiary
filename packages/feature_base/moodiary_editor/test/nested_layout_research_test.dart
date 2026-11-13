// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_lint/testing.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

const _output = String.fromEnvironment('LAYOUT_RESEARCH_OUTPUT');
const _exportImages = bool.fromEnvironment(
  'LAYOUT_RESEARCH_PNG',
  defaultValue: true,
);
const _checks = [
  'paintBounds',
  'overlap',
  'parents',
  'caretBounds',
  'roundTrip',
  'selection',
  'stable',
  'measurement',
  'framework',
  'markers',
];

Iterable<({ft.Node node, int position, List<ft.Node> ancestors})> _nodes(
  ft.Node node, [
  int position = -1,
  List<ft.Node> ancestors = const [],
]) sync* {
  yield (node: node, position: position, ancestors: ancestors);
  var offset = position + 1;
  for (final child in node.content) {
    yield* _nodes(child, offset, [...ancestors, node]);
    offset += child.nodeSize;
  }
}

List<double> _rect(Rect rect) => [rect.left, rect.top, rect.width, rect.height];

bool _contains(Rect outer, Rect inner) =>
    outer.inflate(1.1).contains(inner.topLeft) &&
    outer.inflate(1.1).contains(inner.bottomRight);

bool _withinWidth(Rect outer, Rect inner) =>
    inner.left >= outer.left - 1.1 && inner.right <= outer.right + 1.1;

Future<void> _settleMedia(WidgetTester tester) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    await tester.runAsync(() async {
      await Future.wait(
        images.map((image) async {
          final stream = image.image.resolve(ImageConfiguration.empty);
          final completed = Completer<void>();
          final listener = ImageStreamListener(
            (info, synchronous) {
              info.dispose();
              if (!completed.isCompleted) completed.complete();
            },
            onError: (Object error, StackTrace? stack) {
              if (!completed.isCompleted) completed.completeError(error, stack);
            },
          );
          stream.addListener(listener);
          try {
            await completed.future.timeout(const Duration(seconds: 10));
          } finally {
            stream.removeListener(listener);
          }
        }),
      );
    });
    await tester.pumpAndSettle();
    final decoded = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((image) => image.image != null)
        .length;
    if (decoded == tester.widgetList<Image>(find.byType(Image)).length) return;
  }
  fail('Mounted fixture images did not finish decoding');
}

void main() {
  final fixtures =
      Directory(
            '$repoRoot/packages/foundation/flutter_tiptap/test/fixtures/nested_layout',
          )
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((first, second) => first.path.compareTo(second.path));
  final audits = <String, Map<String, List<String>>>{};
  setUpAll(() async {
    if (_output.isNotEmpty) {
      await ui.loadFontFromList(
        File('/Library/Fonts/Arial Unicode.ttf').readAsBytesSync(),
        fontFamily: 'sans-serif',
      );
      await ui.loadFontFromList(
        File('/Library/Fonts/Arial Unicode.ttf').readAsBytesSync(),
        fontFamily: 'Roboto',
      );
      await ui.loadFontFromList(
        File('/System/Library/Fonts/SFNSMono.ttf').readAsBytesSync(),
        fontFamily: 'monospace',
      );
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final family in manifest.cast<Map<String, dynamic>>()) {
        for (final font
            in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
          final data = await rootBundle.load(font['asset'] as String);
          await ui.loadFontFromList(
            data.buffer.asUint8List(),
            fontFamily: family['family'] as String,
          );
        }
      }
    }
  });
  setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
  tearDown(getIt.reset);

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    final raw = file.readAsStringSync();
    final doc = ft.Schema.standard().fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    for (final width in [390, 768]) {
      for (final readOnly in [false, true]) {
        final id = '$name-$width-${readOnly ? 'read' : 'edit'}';
        testWidgets('$id collect layout evidence', (tester) async {
          final violations = {for (final check in _checks) check: <String>[]};
          audits[id] = violations;
          await tester.binding.setSurfaceSize(Size(width.toDouble(), 10000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final boundary = GlobalKey();
          await tester.pumpWidget(
            TranslationProvider(
              child: MaterialApp(
                theme: buildMuiTheme(brightness: Brightness.light),
                localizationsDelegates: const [
                  ...GlobalMaterialLocalizations.delegates,
                  GlobalMuiLocalizations.delegate,
                ],
                builder: (context, child) =>
                    MaterialUiCompatibilityBridge(child: child!),
                home: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    body: MoodiaryEditor(
                      initialContent: raw,
                      readOnly: readOnly,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var attempt = 0; attempt < 100; attempt++) {
            if (tester
                    .widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor))
                    .controller
                    .state
                    .doc
                    .rowCount ==
                doc.rowCount) {
              break;
            }
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            });
            await tester.pumpAndSettle();
          }
          await _settleMedia(tester);
          final state = tester.state<ft.TiptapEditorState>(
            find.byType(ft.TiptapEditor),
          );
          final widget = tester.widget<ft.TiptapEditor>(
            find.byType(ft.TiptapEditor),
          );
          final geometry = state.geometry!;
          final style = widget.style;
          expect(style.paragraph.fontSize, 17);
          expect(geometry.rowCount, doc.rowCount);
          final content = Rect.fromLTRB(
            style.padding.left,
            0,
            width - style.padding.right,
            geometry.viewportSize.height,
          );
          final entries = _nodes(doc).toList();
          final contentRows = entries
              .where(
                (entry) =>
                    entry.node.isTextblock ||
                    entry.node.isLeaf &&
                        entry.node.schema.nodes[entry.node.type]?.inline !=
                            true,
              )
              .toList();
          final rows = [
            for (final row in doc.rows())
              (position: row.position, rect: geometry.rowRect(row.position)),
          ];
          final blocks = <Map<String, Object?>>[];
          final carets = <Map<String, Object?>>[];
          final selections = <Map<String, Object?>>[];
          final nodeViews = <Map<String, Object?>>[];
          final markers = <Map<String, Object?>>[];
          final retryPositions = <int>[];
          bool scrollable(int position) =>
              (geometry.horizontalScrollMetrics(position)?.maxScrollExtent ??
                      0) >
                  0 ||
              entries.any(
                (entry) =>
                    entry.node.type == 'table' &&
                    position >= entry.position &&
                    position < entry.position + entry.node.nodeSize &&
                    (geometry
                                .horizontalScrollMetrics(entry.position)
                                ?.maxScrollExtent ??
                            0) >
                        0,
              );

          for (var index = 0; index < rows.length; index++) {
            final row = rows[index];
            if (!scrollable(row.position) && !_withinWidth(content, row.rect)) {
              violations['paintBounds']!.add(
                'row ${row.position}: ${_rect(row.rect)}',
              );
            }
            if (index > 0 && rows[index - 1].rect.bottom > row.rect.top + 1) {
              violations['overlap']!.add(
                'rows ${rows[index - 1].position}/${row.position}',
              );
            }
          }
          for (final entry in entries) {
            final node = entry.node, position = entry.position;
            if (node.isText || position < 0) continue;
            final rect = geometry.rowRect(position);
            final cell = geometry.cellRect(position);
            final metrics = geometry.horizontalScrollMetrics(position);
            blocks.add({
              'type': node.type,
              'position': position,
              'size': node.nodeSize,
              'rect': _rect(rect),
              'cell': cell == null ? null : _rect(cell),
              'ancestors': entry.ancestors
                  .map((parent) => parent.type)
                  .toList(),
              if (metrics != null)
                'horizontal': {
                  'viewport': _rect(metrics.viewport),
                  'offset': metrics.offset,
                  'extent': metrics.maxScrollExtent,
                },
            });
            if (!node.isTextblock && !node.isLeaf) continue;
            final marker = state.debugListMarker(position);
            if (marker != null) {
              markers.add({'position': position, 'rect': _rect(marker.bounds)});
              if (marker.bounds.left < style.padding.left - 1 &&
                  !scrollable(position)) {
                violations['markers']!.add(
                  'marker $position: ${_rect(marker.bounds)} begins outside content',
                );
              }
              if (cell != null && marker.bounds.left < cell.left - 1) {
                violations['markers']!.add(
                  'marker $position escapes cell at ${cell.left}',
                );
              }
            }
            if (cell != null && !_contains(cell, rect)) {
              violations['parents']!.add('${node.type} $position escapes cell');
            }
            if (cell == null) {
              final indent = entry.ancestors.fold<double>(
                0,
                (sum, parent) =>
                    sum +
                    switch (parent.type) {
                      'blockquote' => style.quoteIndent,
                      'bulletList' || 'orderedList' => style.listIndent,
                      'taskList' => style.taskIndent ?? style.listIndent,
                      _ => 0,
                    },
              );
              if (rect.left < style.padding.left + indent - 1) {
                violations['parents']!.add(
                  '${node.type} $position begins before parent inset',
                );
              }
            }
            if (node.isTextblock) {
              for (final selection in geometry.selectionRects(
                position + 1,
                position + node.nodeSize - 1,
                visibleOnly: false,
              )) {
                selections.add({
                  'position': position,
                  'rect': _rect(selection),
                });
                if (!_contains(rect, selection) &&
                    !(node.type == 'codeBlock' && scrollable(position))) {
                  violations['selection']!.add(
                    '${node.type} $position: ${_rect(selection)} outside ${_rect(rect)}',
                  );
                }
              }
            }
          }
          for (var first = 0; first < contentRows.length; first++) {
            final before = contentRows[first];
            var beforeRect = geometry.rowRect(before.position);
            for (final parent in before.ancestors.where(
              (node) => node.type == 'table',
            )) {
              final ancestor = entries.firstWhere(
                (entry) => identical(entry.node, parent),
              );
              final clip = geometry
                  .horizontalScrollMetrics(ancestor.position)
                  ?.viewport;
              if (clip != null) {
                beforeRect = beforeRect.intersect(
                  Rect.fromLTRB(
                    clip.left,
                    content.top,
                    clip.right,
                    content.bottom,
                  ),
                );
              }
            }
            for (
              var second = first + 1;
              second < contentRows.length;
              second++
            ) {
              final after = contentRows[second];
              var afterRect = geometry.rowRect(after.position);
              for (final parent in after.ancestors.where(
                (node) => node.type == 'table',
              )) {
                final ancestor = entries.firstWhere(
                  (entry) => identical(entry.node, parent),
                );
                final clip = geometry
                    .horizontalScrollMetrics(ancestor.position)
                    ?.viewport;
                if (clip != null) {
                  afterRect = afterRect.intersect(
                    Rect.fromLTRB(
                      clip.left,
                      content.top,
                      clip.right,
                      content.bottom,
                    ),
                  );
                }
              }
              final overlap = beforeRect.intersect(afterRect);
              if (overlap.width > 1 && overlap.height > 1) {
                violations['overlap']!.add(
                  'content rows ${before.position}/${after.position}: ${_rect(overlap)}',
                );
              }
            }
          }
          for (var position = 0; position <= doc.content.size; position++) {
            final caret = geometry.caretRect(position);
            final hit = geometry.positionForOffset(caret.center);
            carets.add({
              'position': position,
              'rect': _rect(caret),
              'hit': hit,
            });
            final owner = entries
                .where(
                  (entry) =>
                      entry.node.isTextblock &&
                      position > entry.position &&
                      position < entry.position + entry.node.nodeSize,
                )
                .firstOrNull;
            if (owner == null) continue;
            final rect = geometry.rowRect(owner.position);
            if (!(owner.node.type == 'codeBlock' && scrollable(position)) &&
                !_contains(rect.inflate(caret.width / 2), caret)) {
              violations['caretBounds']!.add(
                '$position: ${_rect(caret)} outside ${_rect(rect)}',
              );
            }
            if (hit != position) {
              retryPositions.add(position);
            }
          }
          final editorBox = tester.renderObject<RenderBox>(
            find.byType(ft.TiptapEditor),
          );
          Map<int, Rect> auditPaintedCells(String label) {
            final painted = <int, Rect>{};
            for (final element in tester.allElements) {
              if (element.widget.runtimeType.toString() != '_MediaNode') {
                continue;
              }
              final dynamic child = element.widget;
              final ft.TiptapNodeView view = child.view;
              final render = element.findRenderObject();
              if (render is! RenderBox || !render.hasSize) continue;
              final point = editorBox.globalToLocal(
                render.localToGlobal(Offset.zero),
              );
              final rect = point & render.size;
              painted[view.position] = rect;
              if (geometry.cellRect(view.position) != null &&
                  !_contains(geometry.rowRect(view.position), rect)) {
                violations['parents']!.add(
                  '$label: painted ${view.node.type} ${view.position} disagrees with its row',
                );
              }
            }
            for (var first = 0; first < contentRows.length; first++) {
              final before = contentRows[first];
              final owner = before.ancestors
                  .where(
                    (node) =>
                        node.type == 'tableCell' || node.type == 'tableHeader',
                  )
                  .lastOrNull;
              if (owner == null) continue;
              for (final after in contentRows.skip(first + 1)) {
                if (!painted.containsKey(before.position) &&
                    !painted.containsKey(after.position)) {
                  continue;
                }
                final afterOwner = after.ancestors
                    .where(
                      (node) =>
                          node.type == 'tableCell' ||
                          node.type == 'tableHeader',
                    )
                    .lastOrNull;
                if (!identical(owner, afterOwner)) continue;
                final beforeRect =
                    painted[before.position] ??
                    geometry.rowRect(before.position);
                final afterRect =
                    painted[after.position] ?? geometry.rowRect(after.position);
                final overlap = beforeRect.intersect(afterRect);
                if (overlap.width > 1 && overlap.height > 1) {
                  violations['overlap']!.add(
                    '$label: painted rows ${before.position}/${after.position}: ${_rect(overlap)}',
                  );
                }
              }
            }
            return painted;
          }

          auditPaintedCells('initial');
          for (final element in tester.allElements) {
            final type = element.widget.runtimeType.toString();
            if (type != '_MediaNode' && type != '_CodeHeader') continue;
            final dynamic child = element.widget;
            final ft.TiptapNodeView view = type == '_MediaNode'
                ? child.view
                : child.node;
            final render = element.findRenderObject();
            if (render is! RenderBox || !render.hasSize) continue;
            final point = editorBox.globalToLocal(
              render.localToGlobal(Offset.zero),
            );
            final rect = point & render.size;
            nodeViews.add({
              'type': view.node.type,
              'position': view.position,
              'rect': _rect(rect),
            });
            if (!scrollable(view.position) && !_withinWidth(content, rect)) {
              violations['paintBounds']!.add(
                'node view ${view.node.type} ${view.position}: ${_rect(rect)}',
              );
            }
            final cell = geometry.cellRect(view.position);
            if (cell != null && !_contains(cell, rect)) {
              violations['parents']!.add(
                'node view ${view.node.type} ${view.position} escapes cell',
              );
            }
          }
          final stableContent = {
            for (final row in contentRows)
              row.position: geometry.rowRect(row.position),
          };
          tester.renderObject(find.byType(ft.TiptapEditor)).markNeedsLayout();
          await tester.pump();
          for (final row in rows) {
            if (geometry.rowRect(row.position) != row.rect) {
              violations['stable']!.add(
                'row ${row.position} changed without input',
              );
            }
          }
          for (final entry in stableContent.entries) {
            if (geometry.rowRect(entry.key) != entry.value) {
              violations['stable']!.add(
                'content row ${entry.key} changed without input',
              );
            }
          }
          Object? exception;
          while ((exception = tester.takeException()) != null) {
            violations['framework']!.add(exception.toString());
          }
          if (_output.isNotEmpty) {
            await tester.runAsync(() async {
              final directory = Directory('$_output/native')
                ..createSync(recursive: true);
              final data = {
                'fixture': name,
                'width': width,
                'readOnly': readOnly,
                'contentBounds': _rect(content),
                'bottom': rows
                    .map((row) => row.rect.bottom)
                    .fold<double>(0, math.max),
                'rows': rows
                    .map(
                      (row) => {
                        'position': row.position,
                        'rect': _rect(row.rect),
                      },
                    )
                    .toList(),
                'blocks': blocks,
                'nodeViews': nodeViews,
                'markers': markers,
                'carets': carets,
                'selections': selections,
                'violations': violations,
              };
              File('${directory.path}/$id.json').writeAsStringSync(
                const JsonEncoder.withIndent('  ').convert(data),
              );
              if (_exportImages) {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await render.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                File('${directory.path}/$id.png')
                    .writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              }
            });
          }
          final revealed = <Map<String, Object?>>[];
          for (final position in retryPositions) {
            if (geometry.positionForOffset(
                  geometry.caretRect(position).center,
                ) !=
                position) {
              widget.controller.setSelection(ft.TextSelection(position));
              await tester.pumpAndSettle();
            }
            final caret = geometry.caretRect(position);
            final hit = geometry.positionForOffset(caret.center);
            revealed.add({
              'position': position,
              'rect': _rect(caret),
              'hit': hit,
            });
            if (hit != position) {
              violations['roundTrip']!.add('$position -> $hit after reveal');
            }
          }
          if (_output.isNotEmpty) {
            final evidence = File('$_output/native/$id.json');
            final data =
                jsonDecode(evidence.readAsStringSync()) as Map<String, dynamic>;
            data['revealedCarets'] = revealed;
            data['violations'] = violations;
            evidence.writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(data),
            );
          }
          final scrollStates = <Map<String, Object?>>[];
          if (name.startsWith('rich_')) {
            final directory = _output.isEmpty
                ? null
                : Directory('$_output/scroll/native');
            directory?.createSync(recursive: true);
            final tables = entries
                .where((entry) => entry.node.type == 'table')
                .toList();
            for (var column = 0; column < 4; column++) {
              for (final table in tables) {
                final header = entries
                    .where(
                      (entry) =>
                          entry.node.isTextblock &&
                          entry.ancestors.contains(table.node) &&
                          entry.ancestors.last.type == 'tableHeader',
                    )
                    .take(table.node.content.first.childCount)
                    .toList();
                final nestedDepth = table.ancestors
                    .where((ancestor) => ancestor.type == 'table')
                    .length;
                final targetColumn =
                    name == 'rich_depth_three' && nestedDepth < 2
                    ? nestedDepth
                    : math.min(column, header.length - 1);
                final target = header[targetColumn];
                final metrics = geometry.horizontalScrollMetrics(
                  table.position,
                )!;
                final desired =
                    (metrics.offset +
                            geometry.rowRect(target.position).left -
                            metrics.viewport.left -
                            style.tableCellPadding.left)
                        .clamp(0.0, metrics.maxScrollExtent);
                final visible = metrics.viewport.intersect(content);
                await tester.sendEventToBinding(
                  PointerScrollEvent(
                    position: editorBox.localToGlobal(
                      Offset(
                        visible.left + math.min(12, visible.width / 2),
                        metrics.viewport.top + 12,
                      ),
                    ),
                    scrollDelta: Offset(desired - metrics.offset, 0),
                  ),
                );
                await tester.pumpAndSettle();
                await _settleMedia(tester);
              }
              final paintedRects = auditPaintedCells('column ${column + 1}');
              final currentRects = {
                for (final row in contentRows)
                  row.position: geometry.rowRect(row.position),
              };
              for (var first = 0; first < contentRows.length; first++) {
                final before = contentRows[first];
                final beforeRect = currentRects[before.position]!;
                final cell = geometry.cellRect(before.position);
                if (cell != null && !_contains(cell, beforeRect)) {
                  violations['parents']!.add(
                    'column ${column + 1}: ${before.node.type} ${before.position} escapes cell',
                  );
                }
                final owner = before.ancestors
                    .where(
                      (node) =>
                          node.type == 'tableCell' ||
                          node.type == 'tableHeader',
                    )
                    .lastOrNull;
                if (owner == null) continue;
                for (final after in contentRows.skip(first + 1)) {
                  final afterOwner = after.ancestors
                      .where(
                        (node) =>
                            node.type == 'tableCell' ||
                            node.type == 'tableHeader',
                      )
                      .lastOrNull;
                  if (!identical(owner, afterOwner)) continue;
                  final overlap = beforeRect.intersect(
                    currentRects[after.position]!,
                  );
                  if (overlap.width > 1 && overlap.height > 1) {
                    violations['overlap']!.add(
                      'column ${column + 1}: cell rows ${before.position}/${after.position}: ${_rect(overlap)}',
                    );
                  }
                }
              }
              scrollStates.add({
                'column': column + 1,
                'nodeViews': [
                  for (final entry in paintedRects.entries)
                    {'position': entry.key, 'rect': _rect(entry.value)},
                ],
                'blocks': [
                  for (final row in contentRows)
                    {
                      'position': row.position,
                      'type': row.node.type,
                      'rect': _rect(currentRects[row.position]!),
                      'cell': geometry.cellRect(row.position) == null
                          ? null
                          : _rect(geometry.cellRect(row.position)!),
                    },
                ],
              });
              if (directory == null) continue;
              if (_exportImages) {
                await tester.runAsync(() async {
                  final render =
                      boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await render.toImage(pixelRatio: 2);
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  File('${directory.path}/$id-col${column + 1}.png')
                      .writeAsBytesSync(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
              File(
                '${directory.path}/$id-col${column + 1}.json',
              ).writeAsStringSync(
                jsonEncode({
                  'fixture': name,
                  'width': width,
                  'readOnly': readOnly,
                  'column': column + 1,
                  'bottom': rows
                      .map((row) => row.rect.bottom)
                      .fold<double>(0, math.max),
                  'rows': rows.map((row) => {'rect': _rect(row.rect)}).toList(),
                  'tables': [
                    for (final table in tables)
                      {
                        'position': table.position,
                        'viewport': _rect(
                          geometry
                              .horizontalScrollMetrics(table.position)!
                              .viewport,
                        ),
                        'offset': geometry
                            .horizontalScrollMetrics(table.position)!
                            .offset,
                        'extent': geometry
                            .horizontalScrollMetrics(table.position)!
                            .maxScrollExtent,
                      },
                  ],
                }),
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          final target = entries.firstWhere(
            (entry) => entry.node.type == 'image',
          );
          final controller = ft.TiptapController(doc: doc);
          final measuredHeight = ValueNotifier<double>(61);
          final measurementKey = GlobalKey<ft.TiptapEditorState>();
          await tester.pumpWidget(
            MaterialApp(
              home: ft.TiptapEditor(
                key: measurementKey,
                controller: controller,
                readOnly: readOnly,
                style: style,
                nodeViews: {
                  for (final type in ['image', 'video', 'audio', 'attachment'])
                    type: (context, view) => ValueListenableBuilder<double>(
                      valueListenable: measuredHeight,
                      builder: (context, height, _) => SizedBox(
                        width: view.width,
                        height: view.position == target.position ? height : 61,
                      ),
                    ),
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final measured = measurementKey.currentState!.geometry!;
          final before = {
            for (final row in contentRows)
              row.position: measured.rowRect(row.position),
          };
          final targetBefore = measured.rowRect(target.position);
          measuredHeight.value = 102;
          await tester.pumpAndSettle();
          final targetAfter = measured.rowRect(target.position);
          if ((targetAfter.height - targetBefore.height - 41).abs() > 1) {
            violations['measurement']!.add(
              'target ${target.position} did not adopt measured height',
            );
          }
          for (final row in contentRows) {
            if (target.position >= row.position &&
                target.position < row.position + row.node.nodeSize) {
              continue;
            }
            final previous = before[row.position]!;
            final next = measured.rowRect(row.position);
            if ((previous.height - next.height).abs() > 1 ||
                row.position < target.position &&
                    (previous.top - next.top).abs() > 1) {
              violations['measurement']!.add(
                'unrelated row ${row.position} moved or resized',
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          measuredHeight.dispose();
          controller.dispose();
          if (_output.isNotEmpty) {
            final evidence = File('$_output/native/$id.json');
            final data =
                jsonDecode(evidence.readAsStringSync()) as Map<String, dynamic>;
            data['measurement'] = {
              'target': target.position,
              'before': _rect(targetBefore),
              'after': _rect(targetAfter),
            };
            data['scrollStates'] = scrollStates;
            data['violations'] = violations;
            evidence.writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(data),
            );
          }
        });
        for (final check in _checks) {
          test('$id $check', () {
            final findings = audits[id]![check]!;
            expect(findings, isEmpty, reason: findings.take(8).join('\n'));
          });
        }
      }
    }
  }
}
