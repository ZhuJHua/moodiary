import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/picker/mobile_file_picker.dart';
import 'package:mui/mui.dart';

final class _PickedFile extends fp.PlatformFile {
  @override
  XFile get xFile => XFile('backup.zip');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends fp.FilePickerPlatform {
  int calls = 0;

  @override
  Future<fp.PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Function(fp.FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    fp.AndroidOptions androidOptions = const fp.AndroidOptions(),
    fp.DarwinOptions darwinOptions = const fp.DarwinOptions(),
    fp.WindowsOptions windowsOptions = const fp.WindowsOptions(),
    fp.LinuxOptions linuxOptions = const fp.LinuxOptions(),
    fp.WebOptions webOptions = const fp.WebOptions(),
  }) async => switch (++calls) {
    1 => null,
    2 => throw PlatformException(code: 'load_failed'),
    _ => _PickedFile(),
  };
}

void main() {
  testWidgets('file cancellation is silent and a failed load can be retried', (
    tester,
  ) async {
    final original = fp.FilePickerPlatform.instance;
    fp.FilePickerPlatform.instance = _Picker();
    addTearDown(() => fp.FilePickerPlatform.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: .light),
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(),
      ),
    );
    final picker = MobileFilePicker();
    final error = find.text(l10n.picker.fileLoadFailed);
    expect(await picker.pickFile(allowedExtensions: ['md', 'zip']), isNull);
    await tester.pump();
    expect(error, findsNothing);
    expect(await picker.pickFile(allowedExtensions: ['zip']), isNull);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(
      (await picker.pickFile(allowedExtensions: ['zip']))?.path,
      'backup.zip',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
