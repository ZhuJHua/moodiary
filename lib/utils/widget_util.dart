import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:moodiary/utils/theme_util.dart';

Future<Uint8List?> captureWidgetOffScreen({
  required BuildContext context,
  required Widget widget,
  required Size size,
}) async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final devicePixelRatio = view.devicePixelRatio;
  final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
  final RenderView renderView = RenderView(
    child: RenderPositionedBox(
      alignment: Alignment.center,
      child: repaintBoundary,
    ),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: devicePixelRatio,
    ),
    view: view,
  );

  final PipelineOwner pipelineOwner = PipelineOwner();
  final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());
  final ThemeData theme;
  final platformBrightness = MediaQuery.platformBrightnessOf(context);
  if (platformBrightness == Brightness.dark) {
    theme = ThemeUtil().darkTheme;
  } else {
    theme = ThemeUtil().lightTheme;
  }
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();
  final RenderObjectToWidgetElement<RenderBox> rootElement =
      RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: InheritedTheme.captureAll(
          context,
          Theme(
            data: theme,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQuery.of(context),
                child: Material(
                  child: Builder(
                    builder: (context) {
                      return widget;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);
  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  final image = await repaintBoundary.toImage(pixelRatio: devicePixelRatio * 2);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

Future<Uint8List?> captureWidgetWithKey(
  BuildContext context,
  GlobalKey globalKey,
) async {
  final boundary =
      globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
