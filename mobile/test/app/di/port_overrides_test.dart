import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/di/overrides.dart';
import 'package:moodiary_mobile/app/media/mobile_heif_decoder.dart';
import 'package:moodiary_mobile/app/media/video_ambient_port_impl.dart';
import 'package:moodiary_mobile/app/media/video_player_port_impl.dart';
import 'package:moodiary_mobile/app/picker/mobile_file_picker.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

class _LocalArchive extends Fake implements LocalArchive {}

void main() {
  test('mobile composition root binds all ten required ports', () {
    final root = Directory.systemTemp.createTempSync('mobile-ports-');
    addTearDown(() => root.delete(recursive: true));
    PlatformService.get()
      ..applicationSupportDirectory = Directory('${root.path}/support')
      ..applicationCacheDirectory = Directory('${root.path}/cache');
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        ...buildMobilePortOverrides(),
        localArchiveProvider.overrideWithValue(_LocalArchive()),
      ],
    );

    expect(container.read(httpClientProvider), isA<RustHttpClient>());
    expect(
      container.read(notificationPermissionProvider),
      isA<DeviceNotificationPermission>(),
    );
    expect(container.read(filePickerProvider), isA<MobileFilePicker>());
    expect(container.read(heifDecoderProvider), isA<MobileHeifDecoder>());
    expect(
      container.read(videoPlayerPortFactoryProvider),
      createVideoPlaybackPort,
    );
    expect(container.read(videoSurfaceBuilderProvider), buildVideoSurface);
    expect(
      container.read(videoAmbientPortFactoryProvider),
      defaultVideoAmbientPorts,
    );
    expect(container.read(backupArchiveProvider), isA<SyncBackupArchive>());
    expect(
      container.read(legacyDataExporterProvider),
      isA<SyncLegacyDataExporter>(),
    );
    expect(container.read(diaryShareHandlerProvider), showDiaryShareSheet);
  });
}
