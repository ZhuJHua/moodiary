import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'theme_builder.dart';

part 'theme_providers.g.dart';

@Riverpod(keepAlive: true)
ThemeBuilder themeBuilder(Ref ref) => ThemeBuilder();
