import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

mixin SoftKeyboardObserver<T extends StatefulWidget> on State<T> {
  late final StreamSubscription<bool> _softKeyboard;

  @override
  void initState() {
    super.initState();
    _softKeyboard = KeyboardVisibilityController().onChange.listen(
      didChangeSoftKeyboardVisibility,
    );
  }

  @override
  void dispose() {
    unawaited(_softKeyboard.cancel());
    super.dispose();
  }

  void didChangeSoftKeyboardVisibility(bool visible);
}
