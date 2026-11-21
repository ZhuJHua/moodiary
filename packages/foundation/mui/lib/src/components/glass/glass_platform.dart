import 'package:flutter/foundation.dart';

bool get usesLiquidGlass =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
