import 'dart:io';

import 'package:isar_plus/isar_plus.dart';
import 'package:path/path.dart' as p;

/// 旧引擎的库文件名。
const String legacyDbFileName = 'default.isar';

/// 2.7.3 线上就是按这个上限开库的：默认的 128MiB 是 mdbx 硬上限（写满直接抛错），
/// 重度用户的旧库越过它就再也打不开。只是虚拟映射上限，不预分配磁盘，放大无代价。
const int legacyMaxSizeMiB = 4096;

bool legacyDbExistsIn(String dir) =>
    File(p.join(dir, legacyDbFileName)).existsSync();

/// 打开旧库；库不在则返回 null，由调用方整步跳过。
///
/// [Isar.open] 是 open-or-create——库不在时它会静默造出一个**空库**，于是依赖它的
/// 步骤全都在空库上「迁移」：2.6.3 的孤儿清理据此把磁盘上每一个媒体文件判成孤儿并
/// 物理删除。旧库在 2.8.0 搬迁完成后会被改名成 `.pre-sqlite.bak`，而版本迁移链可能
/// 在那之后才补跑（首启 `legacyMigrationPending` 时 appVersion 一个字都不写），
/// 「库已不在但迁移链仍要跑」是真实可达的状态，不是理论情况。
Isar? openLegacyIsar({
  required List<IsarGeneratedSchema> schemas,
  required String dir,
  bool inspector = true,
}) {
  if (!legacyDbExistsIn(dir)) return null;
  return Isar.open(
    schemas: schemas,
    directory: dir,
    maxSizeMiB: legacyMaxSizeMiB,
    inspector: inspector,
  );
}
