import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

class MoodiaryRefresh extends StatelessWidget {
  final FutureOr<void> Function()? onLoading;
  final FutureOr<void> Function()? onRefresh;
  final Widget? child;
  final double? paddingStart;
  final double? paddingEnd;

  const MoodiaryRefresh({
    super.key,
    this.onLoading,
    this.onRefresh,
    this.child,
    this.paddingStart,
    this.paddingEnd,
  });

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      onLoad: onLoading,
      onRefresh: onRefresh,
      header: const MaterialHeader(),
      footer: const MaterialFooter(),
      child: child,
    );
  }
}
