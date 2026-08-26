// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary/app/di/app_module.dart' as _i980;
import 'package:moodiary/app/media/mobile_heif_decoder.dart' as _i879;
import 'package:moodiary/app/picker/mobile_file_picker.dart' as _i231;
import 'package:moodiary_assistant/injectable.module.dart' as _i578;
import 'package:moodiary_files/moodiary_files.dart' as _i800;
import 'package:moodiary_http/injectable.module.dart' as _i545;
import 'package:moodiary_http/moodiary_http.dart' as _i765;
import 'package:moodiary_storage/injectable.module.dart' as _i295;
import 'package:moodiary_sync/injectable.module.dart' as _i412;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    await _i295.MoodiaryStoragePackageModule().init(gh);
    await _i545.MoodiaryHttpPackageModule().init(gh);
    await _i578.MoodiaryAssistantPackageModule().init(gh);
    await _i412.MoodiarySyncPackageModule().init(gh);
    final appModule = _$AppModule();
    gh.lazySingleton<_i765.IHttpClient>(() => appModule.httpClient());
    gh.lazySingleton<_i800.IHeifDecoder>(() => _i879.MobileHeifDecoder());
    gh.lazySingleton<_i800.IFilePicker>(() => _i231.MobileFilePicker());
    return this;
  }
}

class _$AppModule extends _i980.AppModule {}
