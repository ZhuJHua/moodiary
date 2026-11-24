import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary_media/src/attachment_details.dart';
import 'package:moodiary_router/moodiary_router.dart';

class _RouteState extends Fake implements GoRouterState {
  @override
  final Object? extra;

  _RouteState(this.extra);
}

void main() {
  test('media routes select only supported library types', () {
    for (final type in MediaType.values) {
      final state = _RouteState(MediaRoute(type: type.value).params);
      expect(MediaPage.fromRoute(state).initialType, type);
    }
    expect(const MediaRoute().params, isNull);
    for (final extra in [
      null,
      {},
      {'type': 3},
      {'type': 'unknown'},
      {'type': 'thumbnail'},
    ]) {
      expect(
        MediaPage.fromRoute(_RouteState(extra)).initialType,
        MediaType.image,
      );
    }
  });

  test('subtitle uses the display or stored extension and byte size', () {
    expect(attachmentExtension('Notes.pdf', 'file.bin'), 'pdf');
    expect(attachmentExtension('Notes', 'file.pdf'), 'pdf');
    expect(attachmentSubtitle('pdf', 1536, 'Waiting'), 'PDF · 1.50 KB');
    expect(attachmentSubtitle('pdf', 0, 'Waiting'), 'PDF · 0 B');
    expect(attachmentSubtitle('', 1, 'Waiting'), '1 B');
    expect(attachmentSubtitle('pdf', null, 'Waiting'), 'Waiting');
  });

  test('detail metadata keeps the date and available type or duration', () {
    String meta({String extension = '', String? duration, int? bytes}) =>
        attachmentDetailMeta(
          extension: extension,
          duration: duration,
          bytes: bytes,
          waitingSync: 'Waiting',
          date: 'Nov 20',
        );
    expect(meta(extension: 'pdf'), 'PDF · Waiting · Nov 20');
    expect(meta(bytes: 0), '0 B · Nov 20');
    expect(meta(duration: '3:42', bytes: 1536), '3:42 · 1.50 KB · Nov 20');
  });

  test('shared copies use a safe basename with the stored extension', () {
    expect(
      attachmentShareName('../folder\\Meeting: notes', 'file.pdf'),
      'Meeting_ notes.pdf',
    );
    expect(attachmentShareName('Notes.PDF', 'file.pdf'), 'Notes.PDF');
    expect(attachmentShareName('Notes.txt', 'file.pdf'), 'Notes.txt.pdf');
    expect(attachmentShareName('..', 'file.pdf'), 'file.pdf');
  });

  test('bin storage fallback respects an extension in the display name', () {
    expect(attachmentShareName('Notes.PDF', 'file.bin'), 'Notes.PDF');
    expect(attachmentShareName('Notes', 'file.bin'), 'Notes.bin');
  });

  test('opening a copy isolates edits and rotates only open copies', () async {
    final cache = Directory.systemTemp.createTempSync('attachment-copy-');
    addTearDown(() => cache.deleteSync(recursive: true));
    final source = File('${cache.path}/source.bin')
      ..writeAsStringSync('original');
    final shared = await stageAttachmentCopy(
      cache,
      source,
      'Notes.pdf',
      prefix: 'share-',
    );
    final opened = await stageAttachmentCopy(
      cache,
      source,
      'Notes.pdf',
      prefix: 'open-',
    );
    expect(opened.uri.pathSegments.last, 'Notes.pdf');
    await opened.writeAsString('external edit');
    final next = await stageAttachmentCopy(
      cache,
      source,
      'Other.pdf',
      prefix: 'open-',
    );
    expect(await opened.parent.exists(), isFalse);
    expect(await next.readAsString(), 'original');
    expect(await shared.readAsString(), 'original');
    expect(await source.readAsString(), 'original');
  });

  test('share names truncate long CJK labels at a code-point boundary', () {
    final label = '日' * 100;
    final name = attachmentShareName(label, 'file.pdf');
    expect(name, '${'日' * 83}.pdf');
    expect(utf8.encode(name).length, 253);

    final nameWithExtension = attachmentShareName('$label.PDF', 'file.pdf');
    expect(nameWithExtension, '${'日' * 83}.PDF');

    final exactLimit = attachmentShareName('ab$label', 'file.pdf');
    expect(exactLimit, 'ab${'日' * 83}.pdf');
    expect(utf8.encode(exactLimit).length, 255);
  });
}
