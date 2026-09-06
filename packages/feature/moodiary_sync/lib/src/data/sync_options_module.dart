import 'package:injectable/injectable.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/secure_options.dart';

@module
abstract class SyncOptionsModule {
  @Named(SyncProviderIds.webdav)
  @lazySingleton
  SecureOptions webDavOptions() => SecureOptions(.webDavOption);

  @Named(SyncProviderIds.s3)
  @lazySingleton
  SecureOptions s3Options() => SecureOptions(.s3Option);
}
