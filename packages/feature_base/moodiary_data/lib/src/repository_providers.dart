import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'category_repository.dart';
import 'diary_repository.dart';
import 'font_repository.dart';
import 'media_info_repository.dart';
import 'tombstone_repository.dart';

part 'repository_providers.g.dart';

/// 仓储的薄 provider 桥。仓储本体仍是进程级静态单例（刻意不进容器，见本包
/// CLAUDE.md），这一层是测试 override 的唯一抓手：
/// `diaryRepositoryProvider.overrideWithValue(DiaryRepository.forTesting(isar))`。
/// controller / provider 一律经这里取仓储，别再直接 `XxxRepository.get()`。
@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) => DiaryRepository.get();

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) => CategoryRepository.get();

@Riverpod(keepAlive: true)
MediaInfoRepository mediaInfoRepository(Ref ref) => MediaInfoRepository.get();

@Riverpod(keepAlive: true)
FontRepository fontRepository(Ref ref) => FontRepository.get();

@Riverpod(keepAlive: true)
TombstoneRepository tombstoneRepository(Ref ref) => TombstoneRepository.get();
