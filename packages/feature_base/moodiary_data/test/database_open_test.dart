import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';

class _ProbeFailure extends QueryInterceptor {
  final error = StateError('probe failed');
  bool closed = false;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement == 'SELECT 1') throw error;
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    await super.close(inner);
    closed = true;
  }
}

void main() {
  test(
    'failed readiness probe closes the connection before reporting the error',
    () async {
      final failure = _ProbeFailure();
      final db = MoodiaryDatabase.forTesting(
        NativeDatabase.memory().interceptWith(failure),
      );
      await expectLater(
        MoodiaryDatabase.probeConnection(db),
        throwsA(same(failure.error)),
      );
      expect(failure.closed, isTrue);
    },
  );
}
