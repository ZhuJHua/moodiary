import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'file_picker.dart';
import 'heif_decoder.dart';

part 'file_providers.g.dart';

@Riverpod(keepAlive: true)
IFilePicker filePicker(Ref ref) =>
    throw UnimplementedError('filePickerProvider must be overridden');

@Riverpod(keepAlive: true)
IHeifDecoder heifDecoder(Ref ref) =>
    throw UnimplementedError('heifDecoderProvider must be overridden');
