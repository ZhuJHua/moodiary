import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/media/mobile_heif_decoder.dart';
import 'package:moodiary_mobile/app/media/video_ambient_port_impl.dart';
import 'package:moodiary_mobile/app/media/video_player_port_impl.dart';
import 'package:moodiary_mobile/app/picker/mobile_file_picker.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

List<Override> buildMobilePortOverrides() => [
  httpClientProvider.overrideWith(
    (ref) =>
        RustHttpClient(onError: (message) => toast.error(message: message)),
  ),
  notificationPermissionProvider.overrideWith(
    (ref) => DeviceNotificationPermission(),
  ),
  filePickerProvider.overrideWith((ref) => MobileFilePicker()),
  heifDecoderProvider.overrideWith((ref) => MobileHeifDecoder()),
  videoPlayerPortFactoryProvider.overrideWithValue(createVideoPlaybackPort),
  videoSurfaceBuilderProvider.overrideWithValue(buildVideoSurface),
  videoAmbientPortFactoryProvider.overrideWithValue(defaultVideoAmbientPorts),
  backupArchiveProvider.overrideWith(
    (ref) => SyncBackupArchive(ref.watch(localArchiveProvider)),
  ),
  legacyDataExporterProvider.overrideWith(
    (ref) => SyncLegacyDataExporter(
      support: PlatformService.get().applicationSupportDirectory,
      cache: PlatformService.get().applicationCacheDirectory,
    ),
  ),
  diaryShareHandlerProvider.overrideWithValue(showDiaryShareSheet),
];
