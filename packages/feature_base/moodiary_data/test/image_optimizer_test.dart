import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

class _Decoder implements IHeifDecoder {
  final converted = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> convert(String srcPath, {required String outputPath}) async {
    await File(srcPath).copy(outputPath);
    converted.complete();
    await release.future;
    return outputPath;
  }
}

class _Repository implements DiaryRepository {
  Diary diary = withDerivedMedia(
    Diary.empty(type: .markdown).copyWith(content: '![photo](image-test.heic)'),
  );

  @override
  Future<List<Diary>> getDiariesReferencingMedia({
    required MediaType kind,
    required List<String> suffixes,
  }) async => [diary];

  @override
  Future<ReferencedMedia> collectReferencedMedia() async => (
    images: diary.imageName.toSet(),
    audios: <String>{},
    videos: <String>{},
    files: <String>{},
  );

  @override
  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = .inline,
    bool fromSync = false,
  }) async {
    diary = newDiary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'optimization excludes cleanup until the converted image reference commits',
    () async {
      final root = Directory.systemTemp.createTempSync('image-optimize-');
      addTearDown(() async {
        await getIt.reset();
        root.deleteSync(recursive: true);
      });
      PlatformService.get().applicationSupportPath = root.path;
      await AppFiles.initCreateDir();
      FastImageRuntime.configure(
        imageDir: '${root.path}/image',
        thumbDir: '${root.path}/image/thumb',
      );
      final original = File(AppFiles.getRealPath('image', 'image-test.heic'));
      await original.writeAsBytes([1, 2, 3]);
      final decoder = _Decoder();
      final repository = _Repository();
      getIt.registerSingleton<IHeifDecoder>(decoder);
      getIt.registerSingleton<DiaryRepository>(repository);
      final optimizing = ImageOptimizer.run();
      await decoder.converted.future;
      var cleaned = false;
      final cleanup = runMediaExclusive(() async {
        cleaned = true;
        expect(repository.diary.imageName, ['image-test.jpg']);
        expect(original.existsSync(), isFalse);
        expect(
          File(AppFiles.getRealPath('image', 'image-test.jpg')).existsSync(),
          isTrue,
        );
      });
      await pumpEventQueue();
      expect(cleaned, isFalse);
      decoder.release.complete();
      final result = await optimizing;
      expect(result.heicConverted, 1);
      expect(result.heicFailed, 0);
      await cleanup;
    },
  );
}
