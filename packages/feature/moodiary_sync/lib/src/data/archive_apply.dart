import 'dart:async';
import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:synchronized/synchronized.dart';

final _syncFamilyLock = Lock();

/// 同步家族（push / pull / 归档导入 / 重加密 / 墓碑 GC）的**进程内操作级互斥锁**：
/// 保证同一时刻本机只有一个在跑。
///
/// 它和远端租约锁是两回事：租约挡的是**别的设备**，这把挡的是**本机自己**。归档
/// 导入不需要租约（为一个解压出来的临时目录抢锁，防的是不存在的并发设备），但**必须**
/// 要这把：恢复与云端 push 并发时，push 拿到的墓碑快照里还留着恢复尚未插回的那批行，
/// 会把它们当作删除写进远端 manifest 并真删远端对象，下一轮 pull 再把本机刚恢复的
/// 日记连同磁盘媒体硬删 —— 用户点了「从备份恢复」，结果全网抹除。
///
/// 停止标志也在这一层按操作复位。它原先挂在引擎的租约 body 里，可租约抢占失败时
/// 那个 finally 根本走不到（[RemoteLease.protect] 在 body 之前抛），标志便一直留着
/// true —— 之后每次备份恢复 / 局域网接收（同样走这把锁，但不经引擎）都会在第一条
/// 条目上当场空转并报「已停止」，且重试无用。
Future<T> runSyncExclusive<T>(Future<T> Function() body) =>
    _syncFamilyLock.synchronized(() async {
      try {
        return await body();
      } finally {
        SyncCancellation.instance.reset();
      }
    });

/// 「把一份归档应用到本地仓储」这件事的**策略**——机制与策略之间的那条缝。
///
/// 同步与备份不是一套逻辑，但它们读的是同一种归档、走的是同一套落库机制。此前
/// 「从备份恢复」直接借用同步引擎，靠四套互不相干的机关表达「这其实不是同步」
/// （markSynced:false、backendId 为 null、pull 模式参数、keyfile 前奏空转），
/// 还会为一个本地目录去抢远端租约锁。现在机制归 [ArchiveApplier]，两者的差异
/// 收敛成这一个对象。
abstract class ArchiveApplyPolicy {
  const ArchiveApplyPolicy();

  /// 归档里的墓碑是否执行删除。
  bool get appliesTombstones;

  /// 本机墓碑是否参与 LWW（作为「不写入」的下限）。
  bool get localTombstonesBlockWrite;
}

/// 设备间搬运（云同步 / 局域网接收）：删除必须传播，否则已删日记永远复活。
class SyncPullPolicy extends ArchiveApplyPolicy {
  const SyncPullPolicy();

  @override
  bool get appliesTombstones => true;

  @override
  bool get localTombstonesBlockWrite => true;
}

/// 从备份恢复：**只增不删**。备份是「当时存在过什么」的快照，不是「我删过什么」
/// 的命令。判据是可逆性不对称——多留可逆（再删一次就行），少留不可逆（行硬删 +
/// 磁盘媒体真删、无回收站兜底）。本机更新的编辑仍然赢：回滚同样不可逆。
class RestorePolicy extends ArchiveApplyPolicy {
  const RestorePolicy();

  @override
  bool get appliesTombstones => false;

  @override
  bool get localTombstonesBlockWrite => false;
}

/// 归档 → 本地仓储的应用器：**只管机制**——读条目、并发、协作式取消、解码、落库、
/// 拉媒体、算报告。写不写、删不删由 [ArchiveApplyPolicy] 决定。
///
/// 不认识租约锁、keyfile 补传、「上次同步时间」这些**同步专属**的东西：那些留在
/// [IncrementalSyncEngine] 里，恢复路径不该为它们付账。
class ArchiveApplier {
  final RemoteObjectStore backend;
  final ArchiveApplyPolicy policy;
  final SyncLogger _logger;
  final SyncDiaryStore _diaryStore;
  final SyncCategoryStore _categoryStore;
  final SyncMediaInfoStore _mediaInfoStore;
  final SyncTombstoneStore _tombstoneStore;
  final SyncMediaFiles _mediaFiles;
  final Future<SyncCipher> Function() _cipherProvider;
  final int concurrency;
  final Pool _mediaGate;

  /// 缺省依赖与 [IncrementalSyncEngine] 同源（测试注入替身）。
  factory ArchiveApplier(
    RemoteObjectStore backend, {
    required ArchiveApplyPolicy policy,
    SyncLogger? logger,
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int concurrency = 4,
  }) => ArchiveApplier._(
    backend,
    policy,
    concurrency,
    logger ?? .get(),
    diaryStore ?? RepoSyncDiaryStore(),
    categoryStore ?? RepoSyncCategoryStore(),
    mediaInfoStore ?? RepoSyncMediaInfoStore(),
    tombstoneStore ?? RepoSyncTombstoneStore(),
    mediaFiles ?? DiskSyncMediaFiles(),
    cipherProvider ?? SyncCipher.current,
  );

  // 私有构造走位置参数：Dart 不允许下划线开头的具名参数（同 IncrementalSyncEngine._）。
  ArchiveApplier._(
    this.backend,
    this.policy,
    this.concurrency,
    this._logger,
    this._diaryStore,
    this._categoryStore,
    this._mediaInfoStore,
    this._tombstoneStore,
    this._mediaFiles,
    this._cipherProvider,
  ) : _mediaGate = Pool(concurrency);

  /// 本次应用里下载失败的媒体数。媒体下载跑在 `Future.wait(eagerError: false)`
  /// 里、失败只记日志不上抛，所以计数必须搭在实例上。
  int _mediaFailed = 0;

  /// 整场只解析一次：恢复中途若发生换密码（CloudReCipher 会清 DEK 缓存），
  /// 逐次重取会让后半程拿新 DEK 去解旧 DEK 加密的归档，剩下的条目全部解不开。
  SyncCipher? _cipherCache;

  Future<SyncCipher> _cipher() async =>
      _cipherCache ??= await _cipherProvider();

  bool get _restoring => !policy.localTombstonesBlockWrite;

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
  };

  /// 把 [manifest] 描述的条目应用到本地。调用方负责先读出 manifest —— 「远端为空」
  /// 该怎么报，同步与恢复的措辞不同。
  Future<SyncReport> apply(SyncManifest manifest) async {
    final restoring = _restoring;
    final sw = Stopwatch()..start();
    _mediaFailed = 0;
    // 与结尾的 syncEnd 成对。AutoSyncWatcher 靠这一对开关 _syncing 闸门：不发的话
    // 恢复期间本机每条写入都会触发 5 秒去抖的自动 push，恢复只要超过 5 秒就必然
    // 撞上一次并发同步；而结尾那记裸 syncEnd 还会把真正在飞的同步的闸门提前放开。
    _logger.info(
      .syncStart,
      payload: {
        ..._backendPayload(),
        'direction': restoring ? 'restore' : 'pull',
      },
    );
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
    final tombstones = TombstoneBatch(await _tombstoneStore.getAll());

    /// 恢复模式下「复活」必须表达成一次**此刻**的本地写入，否则会被下一次云同步再
    /// 删一遍：备份里的 lastModified 是备份那一刻的（t1），比「后来把它删掉」（t2）
    /// 更早，而远端 manifest 的 tombstone 条目永不清除 —— push 因 `t1 <= t2` 跳过，
    /// 紧接着的 pull 读到远端 tombstone 把刚复活的行连同磁盘媒体真删。用户点「从备份
    /// 恢复」的头号场景（误删后找回）在开了云同步时反而是净负收益。
    ///
    /// 判据是**本地此刻没有这一行**。不能改用「本机墓碑还在」——墓碑行在推送到全部
    /// 已配置后端后就被清掉了（见 IncrementalSyncEngine 的 coveredTombstoneKeys），
    /// 而那恰好就是用户来恢复时的状态，那样判会永远为假（真机实测确认）。
    /// 反过来「本地这一行还在」时不提：远端若有更晚的 tombstone，pull 早就把它删了，
    /// 能活到这里说明远端墓碑不比它新，照搬备份时间戳即可。
    ///
    /// 代价：多设备下拿一份旧备份恢复一条本机没有、而别的设备上更新的日记，会用旧
    /// 内容压过新版本。这是修掉「恢复即销毁」必须付的账——后者是恢复功能的头号场景，
    /// 且不可恢复。
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

    int skipped = 0;
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
            // 恢复模式只增不删：备份是「当时存在过什么」的快照，不是删除命令。
            if (restoring) return;
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
                reason: .localNewer,
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
                reason: .openDiary,
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
              // 恢复模式下本机墓碑不作为下限，否则「误删后从备份找回」永远拿不回。
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .diarySkip,
              reason: .upToDate,
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
              .diaryDownload,
              payload: {'key': key, 'objectId': diary.id},
            );
            return;
          }
          // 快照可能过期，写入前重读做最终 LWW（活跃行与墓碑都要看），防止远端
          // 旧版覆盖刚保存的内容 / 复活刚被永久删除的日记。
          final oldDiary = await diaryRepo.getDiaryByBusinessId(id);
          final freshMs =
              oldDiary?.lastModified.millisecondsSinceEpoch ??
              // 同上：恢复模式下墓碑不参与。这道重读原本刻意「防止复活刚被永久
              // 删除的日记」，而恢复要的正是复活。
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeDiary(id);
            _logger.info(
              .diarySkip,
              reason: .upToDate,
              payload: {'diaryId': id},
            );
            return;
          }
          // insertADiary 在仓储事务内连带清除同 id 墓碑行（复活闸门）——历史推送
          // 记录随行消失，将来再次删除不会被误判为「已覆盖所有后端」。
          await diaryRepo.insertADiary(
            restoring && oldDiary == null
                ? diary.copyWith(lastModified: DateTime.timestamp())
                : diary,
            fromSync: fromSync,
          );
          pending.completeDiary(id);
          tombstones.remove(key);
          await _pullDiaryMedia(diary);
          if (oldDiary != null) {
            await _mediaFiles.cleanUpReplaced(oldDiary, diary);
          }
          diaryChanged++;
          _logger.info(
            .diaryDownload,
            payload: {
              'diaryId': id,
              if (diary.title.isNotEmpty) 'title': diary.title,
              'lastModified': diary.lastModified.toIso8601String(),
            },
          );
        } else if (key.startsWith(SyncKeys.categoryPrefix)) {
          final id = key.substring(SyncKeys.categoryPrefix.length);
          if (isTombstone) {
            // 恢复模式只增不删：备份是「当时存在过什么」的快照，不是删除命令。
            if (restoring) return;
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
                reason: .localNewer,
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
                payload: {'categoryId': id},
              );
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localCategories[id]?.lastModified.millisecondsSinceEpoch ??
              // 恢复模式下本机墓碑不作为下限，否则「误删后从备份找回」永远拿不回。
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .categorySkip,
              reason: .upToDate,
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
              // 同上：恢复模式下墓碑不参与。这道重读原本刻意「防止复活刚被永久
              // 删除的日记」，而恢复要的正是复活。
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeCategory(id);
            _logger.info(
              .categorySkip,
              reason: .upToDate,
              payload: {'categoryId': id},
            );
            return;
          }
          final category = Category.fromJson(decoded);
          if (category.id != id) {
            failed++;
            _logger.error(
              .categoryDownload,
              payload: {'key': key, 'objectId': category.id},
            );
            return;
          }
          // insertACategory 在仓储事务内连带清除同 id 墓碑行（复活闸门）。
          await categoryRepo.insertACategory(
            restoring && freshLocal == null
                ? category.copyWith(lastModified: DateTime.timestamp())
                : category,
            fromSync: fromSync,
          );
          // 写失败直接抛（仓储 2026-08 起统一抛异常），由条目级 catch 计 failed
          // ——否则本次同步谎报成功、推进 lastSyncTime。与日记下载失败对称。
          tombstones.remove(key);
          pending.completeCategory(id);
          categoryChanged++;
          _logger.info(.categoryDownload, payload: {'categoryId': id});
        } else if (key.startsWith(SyncKeys.mediaInfoPrefix)) {
          final id = key.substring(SyncKeys.mediaInfoPrefix.length);
          if (isTombstone) {
            // 恢复模式只增不删：备份是「当时存在过什么」的快照，不是删除命令。
            if (restoring) return;
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
                reason: .localNewer,
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
                payload: {'mediaFileName': id},
              );
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localMediaInfos[id]?.lastModified.millisecondsSinceEpoch ??
              // 恢复模式下本机墓碑不作为下限，否则「误删后从备份找回」永远拿不回。
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .mediaInfoSkip,
              reason: .upToDate,
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
              // 同上：恢复模式下墓碑不参与。这道重读原本刻意「防止复活刚被永久
              // 删除的日记」，而恢复要的正是复活。
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            _logger.info(
              .mediaInfoSkip,
              reason: .upToDate,
              payload: {'mediaFileName': id},
            );
            return;
          }
          final mediaInfo = MediaInfo.fromJson(decoded);
          if (mediaInfo.fileName != id) {
            failed++;
            _logger.error(
              .mediaInfoDownload,
              payload: {'key': key, 'objectId': mediaInfo.fileName},
            );
            return;
          }
          // insertAMediaInfo 在仓储事务内连带清除同 key 墓碑行（复活闸门）。
          await mediaInfoRepo.insertAMediaInfo(
            restoring && freshLocal == null
                ? mediaInfo.copyWith(lastModified: DateTime.timestamp())
                : mediaInfo,
            fromSync: fromSync,
          );
          // 同上：写失败直接抛，由条目级 catch 计 failed。
          tombstones.remove(key);
          mediaInfoChanged++;
          _logger.info(
            .mediaInfoDownload,
            payload: {'mediaFileName': id},
          );
        }
      } catch (e) {
        failed++;
        // 条目级兜底失败：按 key 前缀归到对应实体的下载 kind，日志页能直接看出
        // 「哪一类东西的下载」红了；前缀无法识别时退回通用 error。
        _logger.error(
          switch (key) {
            final k when k.startsWith(SyncKeys.diaryPrefix) => .diaryDownload,
            final k when k.startsWith(SyncKeys.categoryPrefix) =>
              .categoryDownload,
            final k when k.startsWith(SyncKeys.mediaInfoPrefix) =>
              .mediaInfoDownload,
            _ => .error,
          },
          payload: {'key': key, 'detail': e.toString()},
        );
      }
    }

    // 条目级并发：网络往返是 pull 耗时大头，串行会让「恢复到新设备」慢 N 倍。
    try {
      await runPooled(
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
      reason: stopped ? .stopped : null,
      payload: {
        ..._backendPayload(),
        'direction': 'pull',
        'diaryCount': diaryChanged,
        'categoryCount': categoryChanged,
        'mediaInfoCount': mediaInfoChanged,
        'failed': failed,
        'mediaFailed': _mediaFailed,
        'cancelled': stopped,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    // 媒体失败并入 failed：条目本身可能成功落库，但它引用的图片/录音没下来，
    // 那不是「完全成功」。
    final totalFailed = failed + _mediaFailed;
    final warnings = [
      if (failed > 0) l10n.sync.warnFailedSkipped(count: failed),
      if (_mediaFailed > 0) l10n.sync.warnMediaFailed(count: _mediaFailed),
      if (stopped) l10n.sync.warnStopped,
    ].join('\n');
    return SyncReport(
      diaryCount: diaryChanged,
      categoryCount: categoryChanged,
      mediaInfoCount: mediaInfoChanged,
      elapsed: sw.elapsed,
      warning: warnings.isEmpty ? null : warnings,
      failed: totalFailed,
      cancelled: stopped,
      skipped: skipped,
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
          reason: .localExists,
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
            reason: .remoteMissing,
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
            reason: .remoteMissing,
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
        payload: {'type': type, 'filename': filename, 'bytes': bytes},
      );
    } catch (e) {
      _mediaFailed++;
      _logger.error(
        .mediaDownload,
        payload: {'type': type, 'filename': filename, 'detail': e.toString()},
      );
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

  Future<void> _deleteLocalMedia(Diary diary) async {
    final entries = collectDiaryMediaEntries(diary);
    await Future.wait(
      entries.map((e) async {
        try {
          await _mediaFiles.delete(e.$1, e.$2);
          _logger.info(
            .mediaDelete,
            payload: {'type': e.$1, 'filename': e.$2},
          );
        } catch (_) {}
      }),
      eagerError: false,
    );
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
}

class TombstoneBatch {
  final Map<String, SyncTombstone> _rows;
  final Set<String> _dirty = {};
  final Set<String> _removed = {};

  TombstoneBatch(List<SyncTombstone> all)
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

Future<void> runPooled<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T) task,
) async {
  if (items.isEmpty) return;
  final pool = Pool(concurrency);
  try {
    await Future.wait(items.map((item) => pool.withResource(() => task(item))));
  } finally {
    await pool.close();
  }
}
