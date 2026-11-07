// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_data/moodiary_data.dart' as _i691;
import 'package:moodiary_mcp/src/service/mcp_service.dart' as _i952;

class MoodiaryMcpPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i952.McpService>(
      () => _i952.McpService(
        gh<_i691.DiaryRepository>(),
        gh<_i691.CategoryRepository>(),
        gh<_i691.MoodInsightsRepository>(),
      ),
    );
  }
}
