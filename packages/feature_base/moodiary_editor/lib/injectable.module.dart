// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_editor/src/data/geo_repository.dart' as _i951;
import 'package:moodiary_editor/src/data/weather_repository.dart' as _i431;
import 'package:moodiary_http/moodiary_http.dart' as _i765;

class MoodiaryEditorPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i951.GeoRepository>(
      () => _i951.GeoRepository(gh<_i765.IHttpClient>()),
    );
    gh.lazySingleton<_i431.WeatherRepository>(
      () => _i431.WeatherRepository(gh<_i765.IHttpClient>()),
    );
  }
}
