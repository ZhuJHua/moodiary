// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_assistant/src/data/assistant.dart' as _i808;
import 'package:moodiary_assistant/src/data/impl/rig_assistant.dart' as _i192;

class MoodiaryAssistantPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i808.AssistantService>(() => _i192.RigAssistantService());
  }
}
