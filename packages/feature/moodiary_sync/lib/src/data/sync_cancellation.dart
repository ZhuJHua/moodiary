import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@singleton
class SyncCancellation {
  final ValueNotifier<bool> _requested = ValueNotifier(false);

  ValueListenable<bool> get listenable => _requested;

  bool get isRequested => _requested.value;

  void requestStop() => _requested.value = true;

  void reset() => _requested.value = false;
}
