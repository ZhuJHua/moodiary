import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'embed_chunker.dart';

typedef SemanticHit = ({
  String diaryId,
  double distance,
  int startOff,
  int len,
});

@lazySingleton
class EmbedIndexService {
  EmbedIndexService(this._db, this._engine);

  final MoodiaryDatabase _db;
  final SemanticEmbedder _engine;

  static const int _embedBatch = 16;

  bool _draining = false;

  bool get enabled => _engine.ready;

  Future<int> drain({int? maxDiaries}) async {
    if (!enabled || _draining) return 0;
    _draining = true;
    try {
      if (MoodiaryKVs.embeddingIndexStale.get() ?? false) {
        await _resetForRebuild();
      }
      await _ensureVecTable();
      var processed = 0;
      while (maxDiaries == null || processed < maxDiaries) {
        final batch =
            await (_db.select(_db.embedQueue)
                  ..orderBy([(q) => OrderingTerm.asc(q.enqueuedAt)])
                  ..limit(
                    maxDiaries == null
                        ? _embedBatch
                        : min(_embedBatch, maxDiaries - processed),
                  ))
                .get();
        if (batch.isEmpty) break;
        for (final item in batch) {
          await _reindexOne(item.diaryId);
          processed++;
        }
      }
      return processed;
    } catch (e, s) {
      logger.e('embed drain failed', error: e, stackTrace: s);
      return 0;
    } finally {
      _draining = false;
    }
  }

  Future<int> rebuildAll() {
    MoodiaryKVs.embeddingIndexStale.set(true);
    return drain();
  }

  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.diaryChunks).go();
      await _db.delete(_db.embedQueue).go();
      if (await _vecTableExists()) {
        await _db.customStatement('DROP TABLE vec_diary_chunks');
      }
    });
  }

  Future<List<SemanticHit>> search(
    String query, {
    int limit = 5,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    if (!enabled || !await _vecTableExists()) return const [];
    if (!_draining) await drain(maxDiaries: 8);

    final qvec = await _engine.embedQuery(query);
    final k = max(limit * 4, 32);
    final filters = StringBuffer();
    final vars = <Variable<Object>>[Variable(_f32Blob(qvec)), Variable(k)];
    if (categoryId != null) {
      filters.write(' AND d.category_id = ?');
      vars.add(Variable(categoryId));
    }
    if (start != null) {
      filters.write(' AND d.time >= ?');
      vars.add(Variable(dbTime(start)));
    }
    if (endExclusive != null) {
      filters.write(' AND d.time < ?');
      vars.add(Variable(dbTime(endExclusive)));
    }
    final rows = await _db
        .customSelect(
          'SELECT v.distance AS distance, c.diary_id AS diary_id, '
          '       c.start_off AS start_off, c.len AS len '
          'FROM vec_diary_chunks v '
          'JOIN diary_chunks c ON c.rid = v.rowid '
          'JOIN diaries d ON d.id = c.diary_id '
          'WHERE v.embedding MATCH ? AND k = ? AND d.show = 1$filters '
          'ORDER BY v.distance',
          variables: vars,
        )
        .get();

    final best = <String, SemanticHit>{};
    for (final row in rows) {
      final id = row.read<String>('diary_id');
      if (best.containsKey(id)) continue;
      best[id] = (
        diaryId: id,
        distance: row.read<double>('distance'),
        startOff: row.read<int>('start_off'),
        len: row.read<int>('len'),
      );
      if (best.length >= limit) break;
    }
    return best.values.toList();
  }

  Future<void> _reindexOne(String diaryId) async {
    final row =
        await (_db.select(_db.diaries)
              ..where((d) => d.id.equals(diaryId))
              ..limit(1))
            .getSingleOrNull();
    final oldChunks =
        await (_db.select(_db.diaryChunks)
              ..where((c) => c.diaryId.equals(diaryId))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();

    if (row == null) {
      await _db.transaction(() async {
        await _deleteChunks(diaryId, oldChunks);
        await _dequeue(diaryId);
      });
      return;
    }

    final texts = <String>[];
    final spans = <ChunkSpan>[];
    if (row.title.trim().isNotEmpty) {
      texts.add(row.title);
      spans.add((start: -1, len: 0)); // start=-1 是标题块的 sentinel
    }
    for (final span in chunkOffsets(row.contentText)) {
      texts.add(row.contentText.substring(span.start, span.start + span.len));
      spans.add(span);
    }
    final hashes = [for (final t in texts) _hash(t)];

    final unchanged =
        oldChunks.length == hashes.length &&
        [
          for (var i = 0; i < hashes.length; i++)
            oldChunks[i].textHash == hashes[i],
        ].every((same) => same);
    if (unchanged) {
      await _dequeue(diaryId);
      return;
    }

    final vectors = <Float32List>[];
    for (var i = 0; i < texts.length; i += _embedBatch) {
      vectors.addAll(
        await _engine.embedPassages(
          texts.sublist(i, min(i + _embedBatch, texts.length)),
        ),
      );
    }

    await _db.transaction(() async {
      await _deleteChunks(diaryId, oldChunks);
      for (var i = 0; i < spans.length; i++) {
        final chunk = await _db
            .into(_db.diaryChunks)
            .insertReturning(
              DiaryChunksCompanion.insert(
                diaryId: diaryId,
                seq: i,
                startOff: spans[i].start,
                len: spans[i].len,
                textHash: hashes[i],
              ),
            );
        await _db.customStatement(
          'INSERT INTO vec_diary_chunks(rowid, embedding) VALUES (?, ?)',
          [chunk.rid, _f32Blob(vectors[i])],
        );
      }
      await _dequeue(diaryId);
    });
  }

  Future<void> _deleteChunks(String diaryId, List<DiaryChunkRow> old) async {
    if (old.isEmpty) return;
    if (await _vecTableExists()) {
      await _db.customStatement(
        'DELETE FROM vec_diary_chunks WHERE rowid IN '
        '(SELECT rid FROM diary_chunks WHERE diary_id = ?)',
        [diaryId],
      );
    }
    await (_db.delete(
      _db.diaryChunks,
    )..where((c) => c.diaryId.equals(diaryId))).go();
  }

  Future<void> _dequeue(String diaryId) => (_db.delete(
    _db.embedQueue,
  )..where((q) => q.diaryId.equals(diaryId))).go();

  Future<void> _resetForRebuild() async {
    await _db.transaction(() async {
      if (await _vecTableExists()) {
        await _db.customStatement('DROP TABLE vec_diary_chunks');
      }
      await _db.delete(_db.diaryChunks).go();
      await _db.delete(_db.embedQueue).go();
      await _db.customStatement(
        'INSERT INTO embed_queue(diary_id, enqueued_at) '
        'SELECT id, ? FROM diaries',
        [dbTime(DateTime.timestamp())],
      );
    });
    MoodiaryKVs.embeddingIndexStale.set(false);
  }

  Future<void> _ensureVecTable() async {
    final dim = _engine.dim;
    if (dim <= 0) throw StateError('embeddingDim not set');
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS vec_diary_chunks '
      'USING vec0(embedding float[$dim] distance_metric=cosine)',
    );
  }

  Future<bool> _vecTableExists() async {
    final rows = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'vec_diary_chunks'",
        )
        .get();
    return rows.isNotEmpty;
  }

  static String _hash(String text) => md5.convert(utf8.encode(text)).toString();

  static Uint8List _f32Blob(Float32List v) =>
      v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);
}
