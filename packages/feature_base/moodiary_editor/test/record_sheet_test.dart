import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';
import 'package:record/record.dart';

class _Recorder extends Fake implements RecordPlatform {
  final states = StreamController<RecordState>.broadcast();
  int resumes = 0;
  String? path;

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Stream<RecordState> onStateChanged(String recorderId) => states.stream;

  @override
  Stream<RecordStop> onStopped(String recorderId) => const Stream.empty();

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    this.path = path;
    states.add(.record);
  }

  @override
  Future<void> resume(String recorderId) async {
    resumes++;
    states.add(.record);
  }

  @override
  Future<bool> isRecording(String recorderId) async => true;

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -12, max: 0);

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Future<String?> stop(String recorderId) async => null;

  @override
  Future<void> dispose(String recorderId) async {}
}

void main() {
  late Directory support;
  setUpAll(() {
    support = Directory.systemTemp.createTempSync('record-sheet');
    PlatformService.get().applicationSupportPath = support.path;
  });
  tearDownAll(() => support.deleteSync(recursive: true));

  testWidgets('a native pause makes the next press resume capture', (
    tester,
  ) async {
    final original = RecordPlatform.instance;
    final recorder = _Recorder();
    RecordPlatform.instance = recorder;
    addTearDown(() async {
      RecordPlatform.instance = original;
      await recorder.states.close();
    });
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: const Scaffold(body: RecordSheet()),
        ),
      ),
    );
    await tester.tap(find.byIcon(LucideIcons.circleDot));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(LucideIcons.pause), findsOneWidget);
    recorder.states.add(.pause);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.resumes, 1);
    expect(find.byIcon(LucideIcons.pause), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('saving after a native stop keeps the finished file', (
    tester,
  ) async {
    final original = RecordPlatform.instance;
    final recorder = _Recorder();
    RecordPlatform.instance = recorder;
    addTearDown(() async {
      RecordPlatform.instance = original;
      await recorder.states.close();
    });
    RecordSaveResult? result;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<RecordSaveResult>(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: RecordSheet()),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.circleDot));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final path = recorder.path!;
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    recorder.states.add(.stop);
    await tester.pump();
    await tester.tap(find.text(l10n.common.save));
    for (var i = 0; i < 10 && result == null; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(path, endsWith(result!.fileName));
    expect(File(path).existsSync(), isTrue);
  });
}
