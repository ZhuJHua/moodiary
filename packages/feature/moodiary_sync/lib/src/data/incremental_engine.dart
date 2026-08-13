import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:synchronized/synchronized.dart';

/// 增量同步引擎 —— 在 [IRemoteSyncBackend] 之上做日记 / 分类 / 媒体元数据的差异同步。
///
/// 关键约定：
/// - 远端布局：`manifest.json` + `diary/<id>.json` + `category/<id>.json` +
///   `mediainfo/<type>/<fileName>.json` + `media/<type>/<filename>`，编解码统一走 [SyncCipher]。
/// - 差异判定：以 lastModified 毫秒戳为版本（存于 [ManifestEntry]）；本地删除的
///   行已硬删，事实以 [SyncTombstone] 行承载，写成 tombstone 条目（`d: true`，
///   时间戳即删除时刻，不上传 body）。pull 按时间戳做 LWW，本地更新晚于
///   tombstone 则保留本地。
/// - 媒体清单随 manifest 条目存储（[ManifestEntry.media]）：push 用全体条目并集
///   判断「远端已有哪些媒体」，集合外的仍 stat 兜底（中断残留）。
/// - 上传顺序：媒体优先，全成后才写 diary JSON 和 manifest，防止「远端 JSON
///   引用到尚未上传的媒体」。
/// - 多后端 tombstone 跟踪（[SyncTombstone.pushedBackends]）：tombstone 被所有
///   已配置云后端接收后，才清除墓碑行；日记复活时行连带清除（复活闸门在仓储
///   事务内），历史推送记录不会误判下一次删除。
/// - 密钥正确性交给 AES-GCM auth tag：解 manifest 失败即密钥错。
class IncrementalSyncEngine {
  /// 已被 [_GatedBackend] 套上并发限流的后端，「在飞的网络请求」全局 <= [concurrency]。
  final IRemoteSyncBackend backend;

  /// 条目级并发度，与网络并发上限同值，来自 KV [MoodiaryKVs.syncConcurrency]。
  final int concurrency;

  final SyncLogger _logger;

  /// 媒体「读文件+加解密+传输」整条流水线的并发上限。仅靠 [_GatedBackend] 的
  /// 网络限流不够：文件读取/加解密在网络闸门之外，等待网络许可的文件会把明文+
  /// 密文两份缓冲同时压在内存里，多视频日记并发时内存峰值无上限（移动端可能 OOM）。
  final Pool _mediaGate;

  /// 本地存储端口（生产实现转发到 repository / AppFiles；测试注入内存假实现）。
  final SyncDiaryStore _diaryStore;
  final SyncCategoryStore _categoryStore;
  final SyncMediaInfoStore _mediaInfoStore;
  final SyncTombstoneStore _tombstoneStore;
  final SyncMediaFiles _mediaFiles;

  /// cipher 来源，默认读 secure storage（[SyncCipher.current]）；测试可注入明文。
  final Future<SyncCipher> Function() _cipherProvider;

  /// 引擎实例内复用的 cipher 快照（生命周期 = 一次同步操作）。
  /// 不缓存则每个对象编解码都要读一次 secure storage，大库会放大成数千次系统调用。
  SyncCipher? _cipherCache;

  Future<SyncCipher> _cipher() async =>
      _cipherCache ??= await _cipherProvider();

  /// push/pull/re-cipher 共享的操作级互斥锁，保证全局同一时刻只有一个同步在跑，
  /// 避免 manifest 冲突。
  static final _lock = Lock();

  static const int defaultConcurrency = 8;
  static const int _minConcurrency = 1;
  static const int _maxConcurrency = 32;

  factory IncrementalSyncEngine(
    IRemoteSyncBackend backend, {
    SyncLogger? logger,
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int? concurrency,
  }) {
    final n = concurrency ?? _resolveConcurrency();
    return IncrementalSyncEngine._(
      _GatedBackend(backend, n),
      n,
      logger ?? .get(),
      diaryStore ?? RepoSyncDiaryStore(),
      categoryStore ?? RepoSyncCategoryStore(),
      mediaInfoStore ?? RepoSyncMediaInfoStore(),
      tombstoneStore ?? RepoSyncTombstoneStore(),
      mediaFiles ?? DiskSyncMediaFiles(),
      cipherProvider ?? SyncCipher.current,
    );
  }

  IncrementalSyncEngine._(
    this.backend,
    this.concurrency,
    this._logger,
    this._diaryStore,
    this._categoryStore,
    this._mediaInfoStore,
    this._tombstoneStore,
    this._mediaFiles,
    this._cipherProvider,
  ) : _mediaGate = Pool(concurrency);

  static int _resolveConcurrency() {
    final raw = MoodiaryKVs.syncConcurrency.get() ?? defaultConcurrency;
    return raw.clamp(_minConcurrency, _maxConcurrency).toInt();
  }

  /// 同步家族扩展操作（如 [CloudReCipher]）通过此入口复用同一把操作级锁。
  static Future<T> runExclusive<T>(Future<T> Function() body) {
    return _lock.synchronized(body);
  }

  /// 以最多 [concurrency] 个并发遍历 [items] 执行 [task]。单 isolate 下 task 只在
  /// await 点交错，故 task 内对外层共享状态（计数器/entries/tracker/清理列表）的
  /// **同步**修改天然安全、无需加锁。
  static Future<void> _runPooled<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T) task,
  ) async {
    if (items.isEmpty) return;
    final pool = Pool(concurrency);
    try {
      await Future.wait(
        items.map((item) => pool.withResource(() => task(item))),
      );
    } finally {
      await pool.close();
    }
  }

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
  };

  /// 「进程内互斥锁 + 远端租约锁」双重保护下执行 [body]（后者挡其它设备，见
  /// [RemoteLease]）。结束（含异常）时复位停止标志，不残留到下一次同步。
  Future<T> _exclusive<T>(Future<T> Function() body) {
    return _lock.synchronized(
      () => RemoteLease.protect(backend, () async {
        try {
          return await body();
        } catch (e) {
          // 保证「syncStart 之后必有 syncEnd」：body（_pull/_push）发了 syncStart 后
          // 若中途抛错（网络错误 / manifest 损坏 / 回读校验失败），其内部的 syncEnd 不会
          // 发出，会让 AutoSyncWatcher 的 _syncing 闸门永久卡死、自动同步静默失效。
          // 这里补发一个 syncEnd 兜底。lease 抢占失败发生在 body 之前（无 syncStart）不受影响。
          _logger.info(
            .syncEnd,
            '同步异常中止',
            payload: {..._backendPayload(), 'error': e.toString()},
          );
          rethrow;
        } finally {
          SyncCancellation.instance.reset();
        }
      }, logger: _logger),
    );
  }

  /// [markSynced] 为 false 时不推进「上次同步时间」（本地备份导入等非云端场景）。
  Future<SyncReport> pull({bool markSynced = true}) async {
    final report = await _exclusive(_pull);
    if (markSynced && report.failed == 0 && !report.cancelled) {
      _markSynced();
    }
    return report;
  }

  Future<SyncReport> _pull() async => (await _pullCore()).$1;

  /// 除报告外返回本次读到的远端 manifest 快照，供 [sync] 在空转热路径上复用。
  Future<(SyncReport, SyncManifest?)> _pullCore() async {
    await _uploadPendingKeyfile();
    final sw = Stopwatch()..start();
    _logger.info(
      .syncStart,
      '开始 pull',
      payload: {..._backendPayload(), 'direction': 'pull'},
    );
    final manifest = await _readManifest();
    if (manifest == null) {
      sw.stop();
      _logger.warn(.manifestRead, '远端 manifest 不存在，结束 pull');
      _logger.info(
        .syncEnd,
        'pull 完成（远端为空）',
        payload: {
          ..._backendPayload(),
          'direction': 'pull',
          'diaryCount': 0,
          'categoryCount': 0,
          'failed': 0,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      return (
        SyncReport(
          diaryCount: 0,
          categoryCount: 0,
          elapsed: sw.elapsed,
          warning: l10n.sync.warnRemoteEmpty,
        ),
        null,
      );
    }
    _logger.info(
      .manifestRead,
      '读到远端 manifest（${manifest.entries.length} 条）',
      payload: {'entries': manifest.entries.length},
    );
    // 到这一步 manifest 已成功解码 = 本地 cipher 与远端一致（auth tag 已验密钥）。

    final diaryRepo = _diaryStore;
    final categoryRepo = _categoryStore;
    final mediaInfoRepo = _mediaInfoStore;
    final localDiaries = {
      for (final d in await diaryRepo.getAllDiaries()) d.id: d,
    };
    final localCategories = {
      for (final c in await categoryRepo.getAllCategoriesForSync()) c.id: c,
    };
    final localMediaInfos = {
      for (final a in await mediaInfoRepo.getAllMediaInfosForSync())
        a.fileName: a,
    };
    // 本地墓碑快照：远端活跃条目 vs 本地删除做 LWW 时要用（删除更晚则不下载）。
    final tombstones = _TombstoneBatch(await _tombstoneStore.getAll());

    // 预扫描：用快照 LWW 先算出「将要新增/更新」的条目并公布，首页立即占位/打标，
    // 不必等每条真正落库（见 [SyncPendingTracker]）。
    final pending = SyncPendingTracker.instance;
    {
      final newDiaries = <String>{};
      final updDiaries = <String>{};
      final newCategories = <String>{};
      final updCategories = <String>{};
      for (final entry in manifest.entries.entries) {
        if (entry.value.deleted) continue;
        final remoteMs = entry.value.timeMs;
        if (entry.key.startsWith(SyncKeys.diaryPrefix)) {
          final id = entry.key.substring(SyncKeys.diaryPrefix.length);
          final local = localDiaries[id];
          final tombMs = tombstones[entry.key]?.timeMs;
          if (local == null) {
            // 本地墓碑更晚 = 删除会胜出，不占位。
            if (tombMs == null || remoteMs > tombMs) newDiaries.add(id);
          } else if (remoteMs > local.lastModified.millisecondsSinceEpoch) {
            updDiaries.add(id);
          }
        } else if (entry.key.startsWith(SyncKeys.categoryPrefix)) {
          final id = entry.key.substring(SyncKeys.categoryPrefix.length);
          final local = localCategories[id];
          final tombMs = tombstones[entry.key]?.timeMs;
          if (local == null) {
            if (tombMs == null || remoteMs > tombMs) newCategories.add(id);
          } else if (remoteMs > local.lastModified.millisecondsSinceEpoch) {
            updCategories.add(id);
          }
        }
      }
      pending.begin(
        newDiaryIds: newDiaries,
        updateDiaryIds: updDiaries,
        newCategoryIds: newCategories,
        updateCategoryIds: updCategories,
      );
    }

    // 拉到 tombstone = 当前 backend 已知此删除，记入墓碑行避免下次 push 重复推送。
    final trackingId = backend.persistentBackendId;
    // 云后端 pull 落库的变更远端已持有 → 事件带 fromSync，AutoSyncWatcher 免除
    // 回声推送；归档导入 / 局域网接收（trackingId==null）仍按本地变更处理。
    final fromSync = trackingId != null;

    int diaryChanged = 0;
    int categoryChanged = 0;
    int mediaInfoChanged = 0;
    int failed = 0;

    Future<void> pullOneEntry(MapEntry<String, ManifestEntry> entry) async {
      // 协作式停止：不再发起新条目，在飞的正常跑完（见 [SyncCancellation]）。
      if (SyncCancellation.instance.isRequested) return;
      final key = entry.key;
      final isTombstone = entry.value.deleted;
      try {
        if (key.startsWith(SyncKeys.diaryPrefix)) {
          final id = key.substring(SyncKeys.diaryPrefix.length);
          if (isTombstone) {
            final tombstoneMs = entry.value.timeMs;
            // 快照可能过期（长 pull 期间用户可能编辑/删除过），写入前重读做 LWW。
            Diary? local = localDiaries[id];
            if (local != null) {
              local = await diaryRepo.getDiaryByBusinessId(id);
            }
            // LWW：本地编辑晚于 tombstone → 本地胜出，跳过（下次 push 覆盖远端）。
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .diarySkip,
                '本地比远端 tombstone 更新，保留本地：$id',
                payload: {
                  'diaryId': id,
                  'localLastModified': local.lastModified.toIso8601String(),
                  'tombstoneMs': tombstoneMs,
                },
              );
              return;
            }
            // 打开中的日记不应用远端删除：行硬删会让编辑器脚下抽行（watchDiary
            // 发 null → 报错丢稿）。跳过本条，关闭后下一轮 pull 再收敛；与 push
            // 的 open-diary 跳过对称。
            if (local != null && OpenDiaryRegistry.instance.contains(id)) {
              _logger.info(
                .diarySkip,
                '日记打开中，跳过应用远端 tombstone：$id',
                payload: {'diaryId': id},
              );
              return;
            }
            if (local != null) {
              // 先落墓碑（行硬删 + 墓碑行同事务）再删媒体：tombstoneDiary 紧接在
              // 上面的 LWW 重读之后、中间无 await，故并发编辑无法在「读到旧版本」
              // 与「写 tombstone」之间插入。走 repo 以发出 DiaryDeleted 事件、
              // 列表原地同步。
              tombstones.add(
                await diaryRepo.tombstoneDiary(local, fromSync: fromSync),
              );
              await _deleteLocalMedia(local);
              diaryChanged++;
              _logger.info(
                .diaryTombstonePull,
                '本地删除日记（远端 tombstone）：$id',
                payload: {'diaryId': id},
              );
            }
            // 远端已知该删除 → 记录当前 backend 已覆盖（本地无墓碑行则无需记录）。
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          // 本地删除（墓碑）也参与 LWW：删除晚于远端活跃条目 → 保留删除。
          final localMs =
              localDiaries[id]?.lastModified.millisecondsSinceEpoch ??
              tombstones[key]?.timeMs;
          if (localMs != null && remoteMs <= localMs) {
            _logger.info(
              .diarySkip,
              '本地不旧于远端，跳过下载：$id',
              payload: {'diaryId': id},
            );
            // 顺带补拉本地缺失的媒体：上次 pull 可能媒体下载失败而 JSON 已落库，
            // 之后每次都走到此 skip 分支不再补。[_downloadMediaIfNeeded] 对已存在
            // 的文件只做一次本地 stat，不产生网络请求。
            final local = localDiaries[id];
            if (local != null) await _pullDiaryMedia(local);
            return;
          }
          final bytes = await backend.readObject(SyncKeys.diaryObjectPath(id));
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          final diary = Diary.fromJson(decoded);
          // 对象身份校验：远端 JSON 的 id 必须与 manifest 键一致，否则损坏 / 被
          // 篡改的对象会错位覆盖本地。
          if (diary.id != id) {
            failed++;
            _logger.error(
              .error,
              '远端日记对象身份不符，已跳过：$key',
              payload: {'key': key, 'objectId': diary.id},
            );
            return;
          }
          // 快照可能过期，写入前重读做最终 LWW（活跃行与墓碑都要看），防止远端
          // 旧版覆盖刚保存的内容 / 复活刚被永久删除的日记。
          final oldDiary = await diaryRepo.getDiaryByBusinessId(id);
          final freshMs =
              oldDiary?.lastModified.millisecondsSinceEpoch ??
              (await _tombstoneStore.getByKey(key))?.timeMs;
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeDiary(id);
            _logger.info(
              .diarySkip,
              '本地在 pull 期间已更新，跳过下载：$id',
              payload: {'diaryId': id},
            );
            return;
          }
          // insertADiary 在仓储事务内连带清除同 id 墓碑行（复活闸门）——历史推送
          // 记录随行消失，将来再次删除不会被误判为「已覆盖所有后端」。
          await diaryRepo.insertADiary(diary, fromSync: fromSync);
          pending.completeDiary(id);
          tombstones.remove(key);
          await _pullDiaryMedia(diary);
          if (oldDiary != null) {
            await _mediaFiles.cleanUpReplaced(oldDiary, diary);
          }
          diaryChanged++;
          _logger.info(
            .diaryDownload,
            '下载日记：${diary.title.isEmpty ? id : diary.title}',
            payload: {
              'diaryId': id,
              'lastModified': diary.lastModified.toIso8601String(),
            },
          );
        } else if (key.startsWith(SyncKeys.categoryPrefix)) {
          final id = key.substring(SyncKeys.categoryPrefix.length);
          if (isTombstone) {
            final tombstoneMs = entry.value.timeMs;
            // 与日记同理：写入前重读做 LWW（快照可能过期）。
            Category? local = localCategories[id];
            if (local != null) {
              local = await categoryRepo.getCategoryById(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .categorySkip,
                '本地分类比远端 tombstone 更新：$id',
                payload: {'categoryId': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await categoryRepo.tombstoneCategory(id, fromSync: fromSync),
              );
              categoryChanged++;
              _logger.info(
                .categoryTombstonePull,
                '本地删除分类（远端 tombstone）：$id',
                payload: {'categoryId': id},
              );
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localCategories[id]?.lastModified.millisecondsSinceEpoch ??
              tombstones[key]?.timeMs;
          if (localMs != null && remoteMs <= localMs) {
            _logger.info(
              .categorySkip,
              '本地分类不旧于远端，跳过：$id',
              payload: {'categoryId': id},
            );
            return;
          }
          final bytes = await backend.readObject(
            SyncKeys.categoryObjectPath(id),
          );
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          // 写入前重读做最终 LWW（快照可能过期，活跃行与墓碑都要看）。
          final freshLocal = await categoryRepo.getCategoryById(id);
          final freshMs =
              freshLocal?.lastModified.millisecondsSinceEpoch ??
              (await _tombstoneStore.getByKey(key))?.timeMs;
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeCategory(id);
            _logger.info(
              .categorySkip,
              '本地分类在 pull 期间已更新，跳过：$id',
              payload: {'categoryId': id},
            );
            return;
          }
          final category = Category.fromJson(decoded);
          if (category.id != id) {
            failed++;
            _logger.error(
              .error,
              '远端分类对象身份不符，已跳过：$key',
              payload: {'key': key, 'objectId': category.id},
            );
            return;
          }
          // insertACategory 在仓储事务内连带清除同 id 墓碑行（复活闸门）。
          final result = await categoryRepo.insertACategory(
            category,
            fromSync: fromSync,
          );
          if (result) {
            tombstones.remove(key);
            pending.completeCategory(id);
            categoryChanged++;
            _logger.info(
              .categoryDownload,
              '下载分类：$id',
              payload: {'categoryId': id},
            );
          } else {
            // 本地写入失败（仓库把异常映射成 false，不抛）→ 必须计入 failed，
            // 否则本次同步谎报成功、推进 lastSyncTime。与日记下载失败对称。
            failed++;
            _logger.error(.error, '写入分类失败：$id', payload: {'categoryId': id});
          }
        } else if (key.startsWith(SyncKeys.mediaInfoPrefix)) {
          final id = key.substring(SyncKeys.mediaInfoPrefix.length);
          if (isTombstone) {
            final tombstoneMs = entry.value.timeMs;
            // 与分类同理：写入前重读做 LWW（快照可能过期）。
            MediaInfo? local = localMediaInfos[id];
            if (local != null) {
              local = await mediaInfoRepo.getMediaInfoByFileName(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .mediaInfoSkip,
                '本地媒体元数据比远端 tombstone 更新：$id',
                payload: {'mediaFileName': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await mediaInfoRepo.tombstoneMediaInfo(id, fromSync: fromSync),
              );
              mediaInfoChanged++;
              _logger.info(
                .mediaInfoTombstonePull,
                '本地删除媒体元数据（远端 tombstone）：$id',
                payload: {'mediaFileName': id},
              );
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localMediaInfos[id]?.lastModified.millisecondsSinceEpoch ??
              tombstones[key]?.timeMs;
          if (localMs != null && remoteMs <= localMs) {
            _logger.info(
              .mediaInfoSkip,
              '本地媒体元数据不旧于远端，跳过：$id',
              payload: {'mediaFileName': id},
            );
            return;
          }
          final bytes = await backend.readObject(
            SyncKeys.mediaInfoObjectPath(id),
          );
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          // 写入前重读做最终 LWW（快照可能过期，活跃行与墓碑都要看）。
          final freshLocal = await mediaInfoRepo.getMediaInfoByFileName(id);
          final freshMs =
              freshLocal?.lastModified.millisecondsSinceEpoch ??
              (await _tombstoneStore.getByKey(key))?.timeMs;
          if (freshMs != null && remoteMs <= freshMs) {
            _logger.info(
              .mediaInfoSkip,
              '本地媒体元数据在 pull 期间已更新，跳过：$id',
              payload: {'mediaFileName': id},
            );
            return;
          }
          final mediaInfo = MediaInfo.fromJson(decoded);
          if (mediaInfo.fileName != id) {
            failed++;
            _logger.error(
              .error,
              '远端媒体元数据对象身份不符，已跳过：$key',
              payload: {'key': key, 'objectId': mediaInfo.fileName},
            );
            return;
          }
          // insertAMediaInfo 在仓储事务内连带清除同 key 墓碑行（复活闸门）。
          final result = await mediaInfoRepo.insertAMediaInfo(
            mediaInfo,
            fromSync: fromSync,
          );
          if (result) {
            tombstones.remove(key);
            mediaInfoChanged++;
            _logger.info(
              .mediaInfoDownload,
              '下载媒体元数据：$id',
              payload: {'mediaFileName': id},
            );
          } else {
            failed++;
            _logger.error(
              .error,
              '写入媒体元数据失败：$id',
              payload: {'mediaFileName': id},
            );
          }
        }
      } catch (e) {
        failed++;
        _logger.error(
          .error,
          'pull 条目失败：$key',
          payload: {'key': key, 'detail': e.toString()},
        );
      }
    }

    // 条目级并发：网络往返是 pull 耗时大头，串行会让「恢复到新设备」慢 N 倍。
    try {
      await _runPooled(
        manifest.entries.entries.toList(),
        concurrency,
        pullOneEntry,
      );
    } finally {
      // pull 结束（含异常）清空占位，失败条目的占位不留到下一轮。
      pending.clear();
    }

    await tombstones.flush(_tombstoneStore);

    sw.stop();
    final stopped = SyncCancellation.instance.isRequested;
    _logger.info(
      .syncEnd,
      stopped ? 'pull 已手动停止' : 'pull 结束',
      payload: {
        ..._backendPayload(),
        'direction': 'pull',
        'diaryCount': diaryChanged,
        'categoryCount': categoryChanged,
        'mediaInfoCount': mediaInfoChanged,
        'failed': failed,
        'cancelled': stopped,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    final warnings = [
      if (failed > 0) l10n.sync.warnFailedSkipped(count: failed),
      if (stopped) l10n.sync.warnStopped,
    ].join('\n');
    return (
      SyncReport(
        diaryCount: diaryChanged,
        categoryCount: categoryChanged,
        mediaInfoCount: mediaInfoChanged,
        elapsed: sw.elapsed,
        warning: warnings.isEmpty ? null : warnings,
        failed: failed,
        cancelled: stopped,
      ),
      manifest,
    );
  }

  /// 本地 → 远端。先比 manifest 算 diff，逐条上传 / 改 tombstone，最后写回 manifest。
  Future<SyncReport> push() async {
    final report = await _exclusive(_push);
    if (report.failed == 0 && !report.cancelled) _markSynced();
    return report;
  }

  /// 双向同步：**同一把锁内**先 [_pull] 再 [_push]，原子完成、不与其它操作交叠。
  /// 调私有 [_pullCore]/[_push]（不再各自抢锁），避免重入。
  Future<SyncReport> sync() async {
    final report = await _exclusive(() async {
      final sw = Stopwatch()..start();
      final (pulled, manifest) = await _pullCore();
      // pull 阶段已被停止 → 不再进入 push。
      if (pulled.cancelled) {
        sw.stop();
        return SyncReport(
          diaryCount: pulled.diaryCount,
          categoryCount: pulled.categoryCount,
          mediaInfoCount: pulled.mediaInfoCount,
          elapsed: sw.elapsed,
          warning: pulled.warning,
          failed: pulled.failed,
          cancelled: true,
        );
      }
      // 空转热路径：pull 零落库零失败时 manifest 快照仍新鲜（同一把租约内、pull
      // 不写 manifest），复用给 push 省一次 GET+解密。有实际变更的 pull 可能耗时
      // 较长，保守起见仍让 push 重读，缩小「读取→写回」的基线窗口。
      final reuse =
          manifest != null &&
          pulled.diaryCount == 0 &&
          pulled.categoryCount == 0 &&
          pulled.mediaInfoCount == 0 &&
          pulled.failed == 0;
      final pushed = await _push(preloaded: reuse ? manifest : null);
      sw.stop();
      final warnings = [
        pulled.warning,
        pushed.warning,
      ].whereType<String>().join('\n');
      return SyncReport(
        diaryCount: pulled.diaryCount + pushed.diaryCount,
        categoryCount: pulled.categoryCount + pushed.categoryCount,
        mediaInfoCount: pulled.mediaInfoCount + pushed.mediaInfoCount,
        elapsed: sw.elapsed,
        warning: warnings.isEmpty ? null : warnings,
        failed: pulled.failed + pushed.failed,
        cancelled: pushed.cancelled,
      );
    });
    if (report.failed == 0 && !report.cancelled) _markSynced();
    return report;
  }

  /// 记录一次同步成功完成的时间。仅当无异常**且无失败条目**才调用 ——
  /// 部分失败的同步不算成功，不该推进 UI 的「上次同步」。
  static void _markSynced() =>
      MoodiaryKVs.lastSyncTime.set(DateTime.now().millisecondsSinceEpoch);

  static int _writeSeq = 0;

  /// 生成本次 manifest 写入的唯一 token（设备 id + 微秒 + 进程内序号），
  /// 足够唯一以支撑写后回读校验。
  String _newWriteToken() {
    final id = MoodiaryKVs.syncDeviceId.get() ?? '';
    return '$id:${DateTime.now().microsecondsSinceEpoch}:${_writeSeq++}';
  }

  Future<SyncReport> _push({SyncManifest? preloaded}) async {
    await _uploadPendingKeyfile();
    final sw = Stopwatch()..start();
    _logger.info(
      .syncStart,
      '开始 push',
      payload: {..._backendPayload(), 'direction': 'push'},
    );
    SyncManifest? read = preloaded;
    var virginRemote = false;
    if (read == null) {
      read = await _readManifest();
      virginRemote = read == null;
    }
    final manifest = read ?? .empty();
    // 兜底不变量：向「空远端」推加密数据前 keys.json 必须先落地 —— 否则该后端上
    // 只有密文没有信封，换设备后永远解不开。待上传清单是主路径，这里兜漏网。
    if (virginRemote && (await _cipher()).encrypted) {
      await _ensureKeyfileOnVirginRemote();
    }
    _logger.info(
      .manifestRead,
      '读到远端 manifest（${manifest.entries.length} 条）',
      payload: {'entries': manifest.entries.length},
    );
    final updated = manifest.copyForUpdate();

    // 「远端已有媒体」集合（非 tombstone 条目并集）：命中即零往返跳过上传。
    // 集合外的仍 stat 兜底（中断残留），确认/上传后加入、并发其它条目立即可见。
    final remoteMedia = manifest.referencedMedia();

    // 删远端媒体前的防御：仍被任何非 tombstone 条目引用的不删。
    bool stillReferenced(String ref) =>
        updated.entries.values.any((e) => !e.deleted && e.media.contains(ref));

    // 权威跳过「打开中的日记」：push 前冻结一份 open-set 快照，把这些条目排除出本次
    // 上传。仅滤 push（pull 仍按 LWW 回写）；manifest 不会因本地缺席而删条目，故被
    // 跳过的日记远端副本原样保留，关闭后下一轮同步再收敛。
    final openSnapshot = OpenDiaryRegistry.instance.snapshot();
    final diaries = (await _diaryStore.getAllDiaries())
        .where((d) => !openSnapshot.contains(d.id))
        .toList();
    final categories = await _categoryStore.getAllCategoriesForSync();
    final mediaInfoRows = await _mediaInfoStore.getAllMediaInfosForSync();

    int diaryChanged = 0;
    int categoryChanged = 0;
    int mediaInfoChanged = 0;
    int failed = 0;

    // 多后端 tombstone 跟踪：仅当墓碑的「已 push 集合」覆盖所有已配置云后端后才
    // 清除墓碑行；trackingId 为 null 则旧行为 push 完即清。
    final trackingId = backend.persistentBackendId;
    final configuredBackends = configuredCloudBackendIds();
    final tombstones = _TombstoneBatch(await _tombstoneStore.getAll());
    final coveredTombstoneKeys = <String>[];

    // 已确认同步的日记 id（上传成功 / LWW 判定本地不旧于远端）→ 提交校验通过后清除
    // 其「待同步」角标。提交前抛错则不清，留待下次 push 自愈。
    final pushedDiaryIds = <String>[];

    // 破坏性远端操作一律推迟到 manifest「写入 + 回读校验」成功之后再执行 —— 这样
    // 一旦校验发现被并发设备覆盖（租约被绕过），本次 push 抛错中止时远端对象/媒体
    // 都还原封不动，本地墓碑也不清，绝不丢数据（对抗式审计要求）。
    final deferredObjectDeletes = <String>[];
    final deferredMediaDeletes = <String>{};

    void scheduleCleanup(String key) {
      if (trackingId == null) {
        coveredTombstoneKeys.add(key);
        return;
      }
      final pushed = tombstones[key]?.pushedBackends ?? const <String>[];
      if (pushed.toSet().containsAll(configuredBackends)) {
        coveredTombstoneKeys.add(key);
      }
    }

    Future<void> pushOneDiary(Diary diary) async {
      // 协作式停止：不发起新条目，已完成条目的 manifest 照常写回（进度不丢）。
      if (SyncCancellation.instance.isRequested) return;
      final key = SyncKeys.diary(diary.id);
      final remoteEntry = manifest.entries[key];

      // 普通更新：用远端条目时间戳（含 tombstone 删除时间）做 LWW。
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          diary.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .diarySkip,
          '本地不旧于远端，跳过上传：${diary.id}',
          payload: {'diaryId': diary.id},
        );
        pushedDiaryIds.add(diary.id);
        return;
      }

      try {
        // 媒体优先、全成才写 JSON：真正失败（非本地缺失）抛 SyncException 被外层
        // 计入 failed、manifest 不更新，下次 LWW 仍判定本地更新会重试。返回值 =
        // 确认存在于远端的引用（本地缺失的不在其中，不能写进 manifest 谎报存在）。
        final confirmedRefs = await _pushDiaryMedia(diary, remoteMedia);
        final bytes = await (await _cipher()).encode(diary.toJson());
        await backend.writeObject(SyncKeys.diaryObjectPath(diary.id), bytes);
        updated.entries[key] = ManifestEntry(
          timeMs: diary.lastModified.millisecondsSinceEpoch,
          media: confirmedRefs,
        );
        remoteMedia.addAll(confirmedRefs);
        // 清理远端不再被引用的旧媒体：旧清单直接取自 manifest 条目，无需回读旧 JSON。
        // 实际删除推迟到 manifest 提交校验后（abort 时旧媒体不被误删）。
        final newRefs = _mediaRefs(diary).toSet();
        final staleRefs =
            (remoteEntry?.deleted ?? true
                    ? const <String>[]
                    : remoteEntry!.media)
                .where((r) => !newRefs.contains(r) && !stillReferenced(r))
                .toList();
        deferredMediaDeletes.addAll(staleRefs);
        remoteMedia.removeAll(staleRefs);
        pushedDiaryIds.add(diary.id);
        diaryChanged++;
        _logger.info(
          .diaryUpload,
          '上传日记：${diary.title.isEmpty ? diary.id : diary.title}',
          payload: {
            'diaryId': diary.id,
            'bytes': bytes.length,
            'lastModified': diary.lastModified.toIso8601String(),
          },
        );
      } catch (e) {
        failed++;
        _logger.error(
          .error,
          '上传日记失败：${diary.id}',
          payload: {'diaryId': diary.id, 'detail': e.toString()},
        );
      }
    }

    await _runPooled(diaries, concurrency, pushOneDiary);

    Future<void> pushOneCategory(Category category) async {
      if (SyncCancellation.instance.isRequested) return;
      final key = SyncKeys.category(category.id);
      final remoteEntry = manifest.entries[key];
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          category.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .categorySkip,
          '本地分类不旧于远端：${category.id}',
          payload: {'categoryId': category.id},
        );
        return;
      }
      try {
        final bytes = await (await _cipher()).encode(category.toJson());
        await backend.writeObject(
          SyncKeys.categoryObjectPath(category.id),
          bytes,
        );
        updated.entries[key] = ManifestEntry(
          timeMs: category.lastModified.millisecondsSinceEpoch,
        );
        categoryChanged++;
        _logger.info(
          .categoryUpload,
          '上传分类：${category.id}',
          payload: {'categoryId': category.id, 'bytes': bytes.length},
        );
      } catch (e) {
        failed++;
        _logger.error(
          .error,
          '上传分类失败：${category.id}',
          payload: {'categoryId': category.id, 'detail': e.toString()},
        );
      }
    }

    await _runPooled(categories, concurrency, pushOneCategory);

    Future<void> pushOneMediaInfo(MediaInfo mediaInfo) async {
      if (SyncCancellation.instance.isRequested) return;
      final key = SyncKeys.mediaInfo(mediaInfo.fileName);
      final remoteEntry = manifest.entries[key];
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          mediaInfo.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .mediaInfoSkip,
          '本地媒体元数据不旧于远端：${mediaInfo.fileName}',
          payload: {'mediaFileName': mediaInfo.fileName},
        );
        return;
      }
      try {
        final bytes = await (await _cipher()).encode(mediaInfo.toJson());
        await backend.writeObject(
          SyncKeys.mediaInfoObjectPath(mediaInfo.fileName),
          bytes,
        );
        updated.entries[key] = ManifestEntry(
          timeMs: mediaInfo.lastModified.millisecondsSinceEpoch,
        );
        mediaInfoChanged++;
        _logger.info(
          .mediaInfoUpload,
          '上传媒体元数据：${mediaInfo.fileName}',
          payload: {'mediaFileName': mediaInfo.fileName, 'bytes': bytes.length},
        );
      } catch (e) {
        failed++;
        _logger.error(
          .error,
          '上传媒体元数据失败：${mediaInfo.fileName}',
          payload: {
            'mediaFileName': mediaInfo.fileName,
            'detail': e.toString(),
          },
        );
      }
    }

    await _runPooled(mediaInfoRows, concurrency, pushOneMediaInfo);

    // 推送墓碑（日记 + 分类 + 媒体元数据）。只改 manifest 快照 / 延迟删除清单 /
    // 内存簿记，无逐条网络 I/O，同步执行即可。
    void pushOneTombstone(SyncTombstone t) {
      final key = t.key;
      final remoteEntry = manifest.entries[key];
      final kind = t.kind;
      // 未知前缀（损坏行 / 未来版本写入）：跳过本条而不是抛错打断整次 push——
      // 一行脏墓碑不该让同步永久失败。行保留原样，等版本升级后自然认领。
      if (kind == null) {
        _logger.warn(.error, '未知墓碑前缀，跳过推送：$key', payload: {'key': key});
        return;
      }
      final (skipKind, pushKind, idKey) = switch (kind) {
        .diary => (
          SyncEventKind.diarySkip,
          SyncEventKind.diaryTombstonePush,
          'diaryId',
        ),
        .category => (
          SyncEventKind.categorySkip,
          SyncEventKind.categoryTombstonePush,
          'categoryId',
        ),
        .mediaInfo => (
          SyncEventKind.mediaInfoSkip,
          SyncEventKind.mediaInfoTombstonePush,
          'mediaFileName',
        ),
      };
      // 已是 tombstone 或远端从未同步过 → 当前 backend 视为已覆盖此删除；
      // remoteEntry==null 不写 tombstone（无数据可指代），已是 tombstone 不重复写。
      if (remoteEntry == null || remoteEntry.deleted) {
        if (trackingId != null) tombstones.markPushed(key, trackingId);
        scheduleCleanup(key);
        return;
      }
      // LWW：远端是普通条目且不旧于本地删除时间 → 远端有更新的编辑（多半来自别的
      // 设备），本地这条过期删除不得覆盖它，否则会用旧 tombstone 抹掉远端更新内容、
      // 造成丢数据。与普通更新路径的 LWW 对称。跳过后不标记 pushed / 不安排清墓碑；
      // 下次 pull 会按 LWW 把更新的远端版本拉回、本地复活（复活时墓碑行连带清除）。
      if (remoteEntry.timeMs >= t.timeMs) {
        _logger.info(
          skipKind,
          '远端比本地删除更新，跳过推送 tombstone：${t.entityId}',
          payload: {
            idKey: t.entityId,
            'remoteMs': remoteEntry.timeMs,
            'localDeleteMs': t.timeMs,
          },
        );
        return;
      }
      // 远端是普通条目 → 该 backend 真同步过该条目，推 tombstone。
      // 先写 tombstone 条目（让 stillReferenced 判定不含本条旧引用），删 JSON / 媒体
      // 都推迟到 manifest 提交校验后执行（manifest 即删除事实的权威记录）。
      updated.entries[key] = ManifestEntry(timeMs: t.timeMs, deleted: true);
      switch (kind) {
        case .diary:
          deferredObjectDeletes.add(SyncKeys.diaryObjectPath(t.entityId));
          final staleRefs = remoteEntry.media
              .where((r) => !stillReferenced(r))
              .toList();
          deferredMediaDeletes.addAll(staleRefs);
          remoteMedia.removeAll(staleRefs);
          diaryChanged++;
        case .category:
          deferredObjectDeletes.add(SyncKeys.categoryObjectPath(t.entityId));
          categoryChanged++;
        case .mediaInfo:
          deferredObjectDeletes.add(SyncKeys.mediaInfoObjectPath(t.entityId));
          mediaInfoChanged++;
      }
      if (trackingId != null) tombstones.markPushed(key, trackingId);
      _logger.info(
        pushKind,
        '推送 tombstone：${t.entityId}',
        payload: {idKey: t.entityId, 'tombstoneMs': t.timeMs},
      );
      scheduleCleanup(key);
    }

    for (final t in tombstones.snapshot()) {
      if (SyncCancellation.instance.isRequested) break;
      pushOneTombstone(t);
    }

    if (diaryChanged > 0 || categoryChanged > 0 || mediaInfoChanged > 0) {
      // 写入带唯一 token 的 manifest，再回读校验 token 仍是自己写的。token 不一致 =
      // 另一台设备在我们之后又写了 manifest（租约被绕过/网络分区），本次 push 视为
      // 失败：抛错中止，**此前未做任何破坏性远端操作、也不会硬删本地**，下次同步会
      // 读到对方 manifest 按 LWW 收敛。不依赖服务器 HTTP 条件写，任意后端可用。
      final token = _newWriteToken();
      final manifestBytes = await (await _cipher()).encode(
        updated.withWriteToken(token).toJson(),
      );
      await backend.writeObject(SyncKeys.manifestPath, manifestBytes);
      final readback = await _readManifest();
      if (readback?.writeToken != token) {
        throw const SyncException(
          'manifest 写入被其它设备并发覆盖，已中止本次 push（本地与远端数据均未被破坏，请重试）',
        );
      }
      _logger.info(
        .manifestWrite,
        '写回远端 manifest（${updated.entries.length} 条）',
        payload: {
          'entries': updated.entries.length,
          'bytes': manifestBytes.length,
        },
      );
    }

    // 提交（写入 + 回读校验）确认后，才执行不可逆 / 破坏性操作：
    // ① 删除远端不再需要的对象与媒体（best-effort，失败仅留存储残留）。
    //    媒体删除按**最终** manifest 再确认一次无人引用：并发期间另一条目可能在本条
    //    把某媒体判为 stale 之后又引用/重传了它（共享媒体），终态 stillReferenced 兜底。
    await _deleteRemoteObjects(deferredObjectDeletes);
    final mediaToDelete = deferredMediaDeletes
        .where((r) => !stillReferenced(r))
        .toList();
    await _deleteRemoteMediaRefs(mediaToDelete);
    // ② 清除「全部已配置云后端均已覆盖」的墓碑行（行本体在删除时已硬删）。
    for (final key in coveredTombstoneKeys) {
      tombstones.remove(key);
    }
    await tombstones.flush(_tombstoneStore);
    // 提交确认后清除已同步日记的「待同步」角标。
    for (final id in pushedDiaryIds) {
      SyncDirtyTracker.instance.clearDirty(id);
    }

    sw.stop();
    final stopped = SyncCancellation.instance.isRequested;
    _logger.info(
      .syncEnd,
      stopped ? 'push 已手动停止' : 'push 结束',
      payload: {
        ..._backendPayload(),
        'direction': 'push',
        'diaryCount': diaryChanged,
        'categoryCount': categoryChanged,
        'mediaInfoCount': mediaInfoChanged,
        'failed': failed,
        'cancelled': stopped,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    final warnings = [
      if (failed > 0) '$failed 个条目上传失败已跳过',
      if (stopped) l10n.sync.warnStopped,
    ].join('\n');
    return SyncReport(
      diaryCount: diaryChanged,
      categoryCount: categoryChanged,
      mediaInfoCount: mediaInfoChanged,
      elapsed: sw.elapsed,
      warning: warnings.isEmpty ? null : warnings,
      failed: failed,
      cancelled: stopped,
    );
  }

  /// 空远端 + 加密模式的 keyfile 兜底：有本机缓存直接补写；没有（如 DEK 经二维码
  /// 传入、从未见过 keyfile）则中止本次 push —— 宁可不同步，不产出解不开的远端。
  Future<void> _ensureKeyfileOnVirginRemote() async {
    final keyfile = SyncKeyManager.cachedKeyfile();
    if (keyfile == null) {
      throw const SyncException(
        '本机没有密钥文件（keys.json）缓存，无法初始化加密远端。请在密钥管理里重设密码后重试。',
      );
    }
    await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
    final backendId = backend.persistentBackendId;
    if (backendId != null) {
      await SyncKeyManager.clearPendingUpload(backendId);
    }
    _logger.info(
      .manifestWrite,
      '空远端初始化：已写入密钥文件 keys.json',
      payload: _backendPayload(),
    );
  }

  /// keyfile 补传前奏：开启加密 / 改密码时未送达本后端的 keys.json（离线 / 后配 /
  /// 写失败）在此补传。非 pending 时零成本；失败只记日志不阻塞同步，下次再试。
  Future<void> _uploadPendingKeyfile() async {
    try {
      await SyncKeyManager.uploadPendingKeyfile(backend);
    } catch (e) {
      _logger.warn(
        .error,
        'keyfile 补传失败（不阻塞本次同步）',
        payload: {..._backendPayload(), 'detail': e.toString()},
      );
    }
  }

  Future<SyncManifest?> _readManifest() async {
    final bytes = await backend.readObject(SyncKeys.manifestPath);
    if (bytes == null) return null;
    final decoded = await (await _cipher()).decode(bytes);
    // bytes 存在但解码不是对象（被外部覆盖成 array/null/字符串、或半截写入）=
    // 远端 manifest 损坏。绝不能当作「远端为空」返回 null —— 那会让 push 用本地
    // 重建 manifest、丢掉仅存在于远端的条目（契约一）。宁可抛错中止本次同步。
    if (decoded is! Map<String, dynamic>) {
      throw SyncException(l10n.sync.errManifestCorrupt);
    }
    return .fromJson(decoded);
  }

  List<String> _mediaRefs(Diary diary) => [
    for (final e in collectDiaryMediaEntries(diary))
      SyncKeys.mediaRef(e.$1, e.$2),
  ];

  /// push：并发上传远端尚不存在的媒体。返回**确认存在于远端**的引用列表（集合/
  /// stat 命中或上传成功），供调用方写进 manifest —— 本地缺失而跳过的不在其中，
  /// 写进去会谎报存在、让该文件永远失去补传机会。
  /// **任一文件真正失败（非本地缺失）抛 [SyncException]**，外层据此跳过本条 JSON
  /// 写入，避免远端 JSON 引用到尚未上传的媒体（pull 端破图）。
  Future<List<String>> _pushDiaryMedia(
    Diary diary,
    Set<String> remoteMedia,
  ) async {
    final entries = collectDiaryMediaEntries(diary);
    final results = await Future.wait(
      entries.map((e) => _uploadMediaIfNeeded(e.$1, e.$2, remoteMedia)),
      eagerError: false,
    );
    if (results.any((r) => r == false)) {
      throw SyncException(l10n.sync.errMediaUpload);
    }
    return [
      for (var i = 0; i < entries.length; i++)
        if (results[i] == true) SyncKeys.mediaRef(entries[i].$1, entries[i].$2),
    ];
  }

  /// 远端不存在则上传。三态返回：`true` 确认存在远端；`null` 本地缺失跳过（不算
  /// 失败，但也不能声称远端存在）；`false` 上传失败，由 [_pushDiaryMedia] 汇总。
  /// 快速路径 [remoteMedia] 命中 → 零往返跳过；集合外用 stat 兜底（覆盖上次 push
  /// 中断、媒体已传但 manifest 未写的残留）。文件名是 UUID 不会原地改，存在性判断即可。
  Future<bool?> _uploadMediaIfNeeded(
    String type,
    String filename,
    Set<String> remoteMedia,
  ) {
    if (remoteMedia.contains(SyncKeys.mediaRef(type, filename))) {
      return .value(true);
    }
    // 整条「stat→读文件→加密→上传」在 [_mediaGate] 许可内执行，限制内存缓冲份数。
    return _mediaGate.withResource(
      () => _uploadMediaNow(type, filename, remoteMedia),
    );
  }

  Future<bool?> _uploadMediaNow(
    String type,
    String filename,
    Set<String> remoteMedia,
  ) async {
    try {
      if (!await _mediaFiles.exists(type, filename)) {
        _logger.warn(
          .mediaSkip,
          '本地媒体不存在，跳过：$filename',
          payload: {'type': type, 'filename': filename},
        );
        return null;
      }

      final remotePath = SyncKeys.mediaObjectPath(type, filename);
      final remoteModified = await backend.statObject(remotePath);
      if (remoteModified.isNotEmpty) {
        _logger.info(
          .mediaSkip,
          '远端已存在，跳过：$filename',
          payload: {'type': type, 'filename': filename},
        );
        remoteMedia.add(SyncKeys.mediaRef(type, filename));
        return true;
      }

      final localPath = _mediaFiles.realPath(type, filename);
      final int bytes;
      if (localPath != null && backend.supportsFileObjects) {
        bytes = await _uploadMediaByFile(localPath, remotePath);
      } else {
        final plain = await _mediaFiles.read(type, filename);
        final encrypted = await (await _cipher()).encryptBytes(plain);
        await backend.writeObject(remotePath, encrypted);
        bytes = encrypted.length;
      }
      _logger.info(
        .mediaUpload,
        '上传媒体：$filename',
        payload: {'type': type, 'filename': filename, 'bytes': bytes},
      );
      remoteMedia.add(SyncKeys.mediaRef(type, filename));
      return true;
    } catch (e) {
      _logger.error(
        .error,
        '上传媒体失败：$filename',
        payload: {'type': type, 'filename': filename, 'detail': e.toString()},
      );
      return false;
    }
  }

  /// 并发删除一组远端对象路径（diary/category JSON，best-effort，吞错 —— manifest
  /// 才是删除事实的权威记录，残留的孤儿 JSON 在 pull 端按 manifest 忽略）。
  Future<void> _deleteRemoteObjects(Iterable<String> paths) async {
    await Future.wait(
      paths.map((path) async {
        try {
          await backend.deleteObject(path);
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  /// 并发删除一组远端媒体引用（best-effort，失败仅造成存储残留，吞错）。
  Future<void> _deleteRemoteMediaRefs(Iterable<String> refs) async {
    await Future.wait(
      refs.map((ref) async {
        try {
          await backend.deleteObject(SyncKeys.mediaObjectPathFromRef(ref));
          _logger.info(.mediaDelete, '删除远端媒体：$ref', payload: {'ref': ref});
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  Future<void> _pullDiaryMedia(Diary diary) async {
    final entries = collectDiaryMediaEntries(diary);
    await Future.wait(
      entries.map((e) => _downloadMediaIfNeeded(e.$1, e.$2)),
      eagerError: false,
    );
  }

  /// 本地不存在则下载。「下载→解密→写文件」全程占一个 [_mediaGate] 许可限制
  /// 内存峰值；本地已存在的快速路径不进闸门（pull skip 分支的补拉探测高频走这）。
  Future<void> _downloadMediaIfNeeded(String type, String filename) async {
    if (await _mediaFiles.exists(type, filename)) return;
    await _mediaGate.withResource(() => _downloadMediaNow(type, filename));
  }

  Future<void> _downloadMediaNow(String type, String filename) async {
    try {
      if (await _mediaFiles.exists(type, filename)) {
        _logger.info(
          .mediaSkip,
          '本地已有，跳过下载：$filename',
          payload: {'type': type, 'filename': filename},
        );
        return;
      }

      final remotePath = SyncKeys.mediaObjectPath(type, filename);
      final localPath = _mediaFiles.realPath(type, filename);
      final int bytes;
      if (localPath != null && backend.supportsFileObjects) {
        final size = await _downloadMediaByFile(remotePath, localPath);
        if (size == null) {
          _logger.warn(
            .mediaSkip,
            '远端无此媒体，跳过：$filename',
            payload: {'type': type, 'filename': filename},
          );
          return;
        }
        bytes = size;
      } else {
        final encrypted = await backend.readObject(remotePath);
        if (encrypted == null || encrypted.isEmpty) {
          _logger.warn(
            .mediaSkip,
            '远端无此媒体，跳过：$filename',
            payload: {'type': type, 'filename': filename},
          );
          return;
        }
        final plain = await (await _cipher()).decryptBytes(encrypted);
        await _mediaFiles.write(type, filename, plain);
        bytes = plain.length;
      }
      _logger.info(
        .mediaDownload,
        '下载媒体：$filename',
        payload: {'type': type, 'filename': filename, 'bytes': bytes},
      );
    } catch (e) {
      _logger.error(
        .error,
        '下载媒体失败：$filename',
        payload: {'type': type, 'filename': filename, 'detail': e.toString()},
      );
    }
  }

  /// 返回上传字节数。
  Future<int> _uploadMediaByFile(String localPath, String remotePath) async {
    final temp = await _mediaTempFile('enc');
    try {
      await (await _cipher()).encryptFileTo(localPath, temp.path);
      await backend.writeObjectFile(remotePath, temp.path);
      return await temp.length();
    } finally {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  /// 远端不存在（或对象为空）返回 null。
  ///
  /// 空对象要和「不存在」同等对待：流式 PUT 中途断网会在服务端留下 0 字节对象，
  /// 而 push 侧只看 statObject 是否存在就跳过重传。若这里当成有效内容落盘，本地媒体
  /// 会永久是个 0 字节文件 —— [_downloadMediaIfNeeded] 的 exists() 之后再也不会重下。
  /// 与字节路径的 `encrypted.isEmpty` 同语义。
  Future<int?> _downloadMediaByFile(String remotePath, String localPath) async {
    final temp = await _mediaTempFile('dec');
    try {
      if (!await backend.readObjectToFile(remotePath, temp.path)) return null;
      if (await temp.length() == 0) return null;
      await File(localPath).parent.create(recursive: true);
      // 先落 .part 再 rename：解密期磁盘上同时压着密文与明文两份，ENOSPC / 进程被杀
      // 都可能写一半，而截断文件同样会被 exists() 当成「已下载」永不重试。
      // rename 在同一文件系统上是原子的（同 MediaManager.compressInPlace 的做法）。
      final part = File('$localPath.part');
      try {
        await (await _cipher()).decryptFileTo(temp.path, part.path);
        await part.rename(localPath);
      } catch (_) {
        try {
          await part.delete();
        } catch (_) {}
        rethrow;
      }
      return await File(localPath).length();
    } finally {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  /// 文件名必须进程内唯一：调用方是 [_mediaGate] 放行的并发任务，取时间戳前只有本地
  /// IO，多个任务的 `DateTime.now()` 落在同一微秒是常态（实测 8 并发下过半轮次会撞），
  /// 撞名会让两份密文写进同一个文件、解密报「密钥不匹配」，把人引向完全错误的方向。
  Future<File> _mediaTempFile(String tag) async {
    final dir = Directory(
      p.join(PlatformService.get().applicationCachePath, 'sync-media'),
    );
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$tag-${uuidV7()}.tmp'));
  }

  Future<void> _deleteLocalMedia(Diary diary) async {
    final entries = collectDiaryMediaEntries(diary);
    await Future.wait(
      entries.map((e) async {
        try {
          await _mediaFiles.delete(e.$1, e.$2);
          _logger.info(
            .mediaDelete,
            '删除本地媒体：${e.$2}',
            payload: {'type': e.$1, 'filename': e.$2},
          );
        } catch (_) {}
      }),
      eagerError: false,
    );
  }
}

/// 一次同步操作内的墓碑行内存簿记：加载全量快照，push 记录 / 新增 / 移除都先改
/// 内存，结尾 [flush] 一次性落库（与旧 KV 版 TombstoneTracker 同一批处理形态）。
/// 单 isolate 下修改只在 await 点交错，同步方法天然无竞态。
class _TombstoneBatch {
  final Map<String, SyncTombstone> _rows;
  final Set<String> _dirty = {};
  final Set<String> _removed = {};

  _TombstoneBatch(List<SyncTombstone> all)
    : _rows = {for (final t in all) t.key: t};

  SyncTombstone? operator [](String key) => _rows[key];

  /// 迭代用快照（迭代中会调 [markPushed]/[remove] 改底层 map）。
  List<SyncTombstone> snapshot() => _rows.values.toList();

  /// pull 期间新落的墓碑行（仓储已写库，这里只登记以便 markPushed 找得到）。
  void add(SyncTombstone row) {
    _rows[row.key] = row;
    _removed.remove(row.key);
  }

  void markPushed(String key, String backendId) {
    final row = _rows[key];
    if (row == null || row.pushedBackends.contains(backendId)) return;
    _rows[key] = SyncTombstone(
      key: row.key,
      timeMs: row.timeMs,
      pushedBackends: [...row.pushedBackends, backendId],
    );
    _dirty.add(key);
  }

  /// 墓碑行已不再需要（已覆盖所有后端 / 该条目已复活且仓储事务已删行）。
  void remove(String key) {
    if (_rows.remove(key) != null) {
      _dirty.remove(key);
      _removed.add(key);
    }
  }

  Future<void> flush(SyncTombstoneStore store) async {
    await store.putAll([for (final key in _dirty) _rows[key]!]);
    await store.deleteByKeys(_removed.toList());
    _dirty.clear();
    _removed.clear();
  }
}

/// 给任意 [IRemoteSyncBackend] 套上「最多 N 个并发网络请求」全局上限的装饰器。
/// 限流只包真正的网络调用（read/write/delete/stat），本地 CPU 工作不占许可，
/// 使「并发数」严格对应「在飞的 HTTP 请求数」。与 [_lock] 的操作级互斥不同：
/// 本装饰器是**操作内限流**。
class _GatedBackend implements IRemoteSyncBackend {
  final IRemoteSyncBackend _inner;
  final Pool _gate;

  _GatedBackend(this._inner, int concurrency) : _gate = Pool(concurrency);

  @override
  Future<Uint8List?> readObject(String key) =>
      _gate.withResource(() => _inner.readObject(key));

  @override
  Future<void> writeObject(String key, Uint8List bytes) =>
      _gate.withResource(() => _inner.writeObject(key, bytes));

  @override
  bool get supportsFileObjects => _inner.supportsFileObjects;

  @override
  Future<bool> readObjectToFile(String key, String filePath) =>
      _gate.withResource(() => _inner.readObjectToFile(key, filePath));

  @override
  Future<void> writeObjectFile(String key, String filePath) =>
      _gate.withResource(() => _inner.writeObjectFile(key, filePath));

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) =>
      _gate.withResource(() => _inner.tryCreateExclusive(key, bytes));

  @override
  Future<void> deleteObject(String key) =>
      _gate.withResource(() => _inner.deleteObject(key));

  @override
  Future<String> statObject(String key) =>
      _gate.withResource(() => _inner.statObject(key));

  // 入口 / 元信息方法直接透传。
  @override
  String get displayName => _inner.displayName;

  @override
  bool get isReady => _inner.isReady;

  @override
  SyncProviderType get type => _inner.type;

  @override
  String? get persistentBackendId => _inner.persistentBackendId;

  @override
  Future<String?> testConnection() => _inner.testConnection();

  @override
  Future<SyncReport> pushAll() => _inner.pushAll();

  @override
  Future<SyncReport> pullAll() => _inner.pullAll();

  @override
  Future<SyncReport> syncAll() => _inner.syncAll();
}

/// 清掉上次进程被杀时残留的同步临时密文（全尺寸，且不会有人来收）。启动时调用一次。
Future<void> purgeSyncMediaTemp() async {
  final dir = Directory(
    p.join(PlatformService.get().applicationCachePath, 'sync-media'),
  );
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}
