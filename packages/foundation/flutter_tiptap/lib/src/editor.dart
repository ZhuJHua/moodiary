import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'model.dart' as m;

part 'editor/controller.dart';
part 'editor/search.dart';
part 'view/table.dart';
part 'editor/callbacks.dart';
part 'view/node_views.dart';
part 'editor/widget.dart';
part 'view/caret.dart';
part 'view/style.dart';
part 'view/height_index.dart';
part 'view/paragraph.dart';
part 'view/viewport.dart';
part 'view/rows.dart';
part 'view/decorations.dart';
part 'input/text_input.dart';
part 'input/shortcuts.dart';

/// Maps document positions to geometry in the editor viewport.
abstract interface class TiptapGeometry {
  int positionForOffset(Offset offset);
  Rect caretRect(int position);
  List<Rect> selectionRects(int from, int to, {bool visibleOnly = true});
  TextRange wordBoundary(int position);
  TextRange lineBoundary(int position);
  Size get viewportSize;

  /// Raw offset of the painted frame, including bounce beyond either extent.
  double get scrollOffset;
  int get rowCount;
  Rect rowRect(int position);
  Rect? cellRect(int position);

  /// Horizontal content bounds and transient scroll feedback for a block.
  ({
    Rect viewport,
    double offset,
    double maxScrollExtent,
    double indicatorOpacity,
  })?
  horizontalScrollMetrics(int position);
  Rect? taskCheckboxRect(int position);
}
