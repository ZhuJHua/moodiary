import 'package:flutter/material.dart';

class PrimaryScrollWrapper extends StatefulWidget {
  final Widget child;

  const PrimaryScrollWrapper({super.key, required this.child});

  @override
  PrimaryScrollWrapperState createState() => PrimaryScrollWrapperState();
}

class PrimaryScrollWrapperState extends State<PrimaryScrollWrapper> {
  late ScrollControllerWrapper _scrollController;

  @override
  void initState() {
    _scrollController = ScrollControllerWrapper();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryScrollController(
      scrollController:
          _scrollController
            ..realController = PrimaryScrollController.of(context),
      child: widget.child,
    );
  }

  void onPageChange(bool show) => _scrollController.onAttachChange(show);
}

class CustomPrimaryScrollController extends InheritedWidget
    implements PrimaryScrollController {
  final ScrollController scrollController;

  const CustomPrimaryScrollController({
    super.key,
    required super.child,
    required this.scrollController,
  });

  @override
  get runtimeType => PrimaryScrollController;

  @override
  get controller => scrollController;

  @override
  bool updateShouldNotify(CustomPrimaryScrollController oldWidget) =>
      controller != oldWidget.controller;

  @override
  Set<TargetPlatform> get automaticallyInheritForPlatforms =>
      TargetPlatform.values.toSet();

  @override
  Axis get scrollDirection => Axis.vertical;
}

class ScrollControllerWrapper implements ScrollController {
  late ScrollController realController;

  ScrollPosition? interceptedAttachPosition;
  ScrollPosition? lastPosition;

  bool showing = true;

  @override
  void addListener(listener) => realController.addListener(listener);

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) => realController.animateTo(offset, duration: duration, curve: curve);

  @override
  void attach(ScrollPosition position) {
    if (realController.positions.contains(position)) return;
    if (showing) {
      realController.attach(position);
      lastPosition = position;
    } else {
      interceptedAttachPosition = position;
    }
  }

  @override
  void detach(ScrollPosition position, {bool fake = false}) {
    if (realController.positions.contains(position)) {
      realController.detach(position);
    }
    if (position == interceptedAttachPosition && !fake) {
      interceptedAttachPosition = null;
    }
    if (position == lastPosition && !fake) {
      lastPosition = null;
    }
    if (fake) {
      interceptedAttachPosition = position;
    }
  }

  void onAttachChange(value) {
    showing = value;
    if (showing) {
      if (interceptedAttachPosition != null) {
        attach(interceptedAttachPosition!);
      }
    } else {
      if (lastPosition != null) {
        detach(lastPosition!, fake: true);
      }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return realController.createScrollPosition(physics, context, oldPosition);
  }

  @override
  void debugFillDescription(List<String> description) =>
      realController.debugFillDescription(description);

  @override
  String? get debugLabel => realController.debugLabel;

  @override
  void dispose() => realController.dispose();

  @override
  bool get hasClients => realController.hasClients;

  @override
  bool get hasListeners => realController.hasListeners;

  @override
  double get initialScrollOffset => realController.initialScrollOffset;

  @override
  void jumpTo(double value) => realController.jumpTo(value);

  @override
  bool get keepScrollOffset => realController.keepScrollOffset;

  @override
  void notifyListeners() => realController.notifyListeners();

  @override
  double get offset => realController.offset;

  @override
  ScrollPosition get position => realController.position;

  @override
  Iterable<ScrollPosition> get positions => realController.positions;

  @override
  void removeListener(listener) => realController.removeListener(listener);

  @override
  int get hashCode => realController.hashCode;

  @override
  bool operator ==(other) => hashCode == (other.hashCode);

  @override
  ScrollControllerCallback? get onAttach => null;

  @override
  ScrollControllerCallback? get onDetach => null;
}
