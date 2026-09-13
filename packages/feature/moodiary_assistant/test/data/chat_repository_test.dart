import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/chat_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late ChatRepository repo;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = ChatRepository(db);
  });

  tearDown(() => db.close());

  test('countSessionsByProvider 只数钉住该供应商的会话', () async {
    for (final p in ['a', 'a', 'b']) {
      await repo.upsertSession(ChatSession.create(providerId: p, model: 'm'));
    }
    expect(await repo.countSessionsByProvider('a'), 2);
    expect(await repo.countSessionsByProvider('b'), 1);
    expect(await repo.countSessionsByProvider('c'), 0);
  });
}
